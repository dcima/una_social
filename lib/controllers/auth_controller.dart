// lib/controllers/auth_controller.dart
import 'dart:async';

import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:una_social/helpers/logger_helper.dart';

class AuthController extends GetxController {
  final SupabaseClient _supabase = Supabase.instance.client;

  // --- STATI OSSERVABILI ---
  final RxList<String> userGroups = <String>[].obs;
  final Rxn<bool> isSuperAdmin = Rxn<bool>();
  final RxBool isLoadingPermissions = false.obs;
  final RxInt connectedUsers = 0.obs;

  // --- PROPRIETÀ PRIVATE ---
  RealtimeChannel? _onlineUsersChannel;
  final Set<String> _activeUserIds = {};
  Completer<void>? _permissionsCompleter;

  @override
  void onInit() {
    super.onInit();
    // The onAuthStateChange stream is the single source of truth.
    // It fires initialSession automatically on startup, so no extra checks are needed.
    _supabase.auth.onAuthStateChange.listen((data) {
      logInfo('[AuthController] Auth Event: ${data.event}, Has Session: ${data.session != null}');
      _handleAuthStateChange(data);
    });
  }

  @override
  void onClose() {
    _unsubscribeFromOnlineUsers();
    super.onClose();
  }

  /// Central handler for all authentication events, based on the presence of a session.
  void _handleAuthStateChange(AuthState data) {
    final session = data.session;
    final event = data.event;

    // A session exists (user is signed in, session restored, or token refreshed)
    if (session != null) {
      // We only need to react when the user state actually changes.
      if (event == AuthChangeEvent.signedIn || event == AuthChangeEvent.initialSession || event == AuthChangeEvent.tokenRefreshed) {
        logInfo('[AuthController] Session available. Loading permissions and subscribing to presence.');
        loadPermissions();
        _subscribeToOnlineUsers();
      }
      // No session exists (user signed out, or initial check found no session)
    } else if (event == AuthChangeEvent.signedOut || event == AuthChangeEvent.initialSession) {
      logInfo('[AuthController] No session. Clearing permissions and unsubscribing.');
      clearUserPermissions();
      _unsubscribeFromOnlineUsers();
    }
  }

  /// Main method to load all user permissions (Super Admin + Groups).
  Future<void> loadPermissions() async {
    if (isLoadingPermissions.value) {
      logInfo('[AuthController] Permission load already in progress, awaiting...');
      return _permissionsCompleter?.future;
    }
    if (_supabase.auth.currentUser == null) {
      logError('[AuthController] loadPermissions called with no user.');
      clearUserPermissions();
      return;
    }

    isLoadingPermissions.value = true;
    _permissionsCompleter = Completer<void>();
    logInfo('[AuthController] Starting user permission load...');

    try {
      final results = await Future.wait([
        _fetchSuperAdminStatus(),
        _fetchUserGroups(),
      ]);

      isSuperAdmin.value = results[0] as bool;
      userGroups.assignAll(results[1] as List<String>);

      logInfo('[AuthController] Permissions loaded. IsSuperAdmin: ${isSuperAdmin.value}, Groups: ${userGroups.join(', ')}');
    } catch (e) {
      logError('[AuthController] Error loading permissions: $e');
      isSuperAdmin.value = false;
      userGroups.clear();
    } finally {
      isLoadingPermissions.value = false;
      if (!(_permissionsCompleter?.isCompleted ?? true)) {
        _permissionsCompleter!.complete();
      }
    }
  }

  /// Clears all user permissions, usually called on logout.
  void clearUserPermissions() {
    userGroups.clear();
    isSuperAdmin.value = null;
    isLoadingPermissions.value = false;
    if (!(_permissionsCompleter?.isCompleted ?? true)) {
      _permissionsCompleter?.completeError("Permissions cleared during load.");
    }
    _permissionsCompleter = null;
    logInfo('[AuthController] User permissions cleared.');
  }

  // ... (the rest of the file remains the same as the previously corrected version) ...

  /// Internal function to call the RPC for Super Admin status.
  Future<bool> _fetchSuperAdminStatus() async {
    try {
      final response = await _supabase.rpc('get_current_user_is_super_admin');
      return response is bool ? response : false;
    } catch (e) {
      logError("[AuthController] Error in _fetchSuperAdminStatus: $e");
      return false;
    }
  }

  /// Internal function to call the RPC for user groups.
  Future<List<String>> _fetchUserGroups() async {
    try {
      final response = await _supabase.rpc('get_my_groups');
      return response is List ? response.map((item) => item.toString()).toList() : [];
    } catch (e) {
      logWarning("[AuthController] Error in _fetchUserGroups (this may be normal if you don't use groups): $e");
      return [];
    }
  }

  /// Asynchronous and robust function for the router to check admin status.
  Future<bool> checkIsSuperAdmin() async {
    if (isLoadingPermissions.value) {
      await _permissionsCompleter?.future;
    } else if (isSuperAdmin.value == null) {
      await loadPermissions();
    }
    return isSuperAdmin.value ?? false;
  }

  // --- Realtime Presence Management ---

  void _subscribeToOnlineUsers() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      logInfo("PRESENCE: User not authenticated, cannot subscribe.");
      return;
    }

    if (_onlineUsersChannel != null) {
      logInfo("PRESENCE: Existing channel found. Removing it to ensure a clean new subscription.");
      _unsubscribeFromOnlineUsers();
    }

    _activeUserIds.clear();

    logInfo("PRESENCE: Creating and subscribing to 'online-users' channel.");
    _onlineUsersChannel = _supabase.channel('online-users');

    _onlineUsersChannel!.onPresenceSync((_) {
      logInfo('PRESENCE EVENT: SYNC');
      _reconcileActiveUsers();
    }).onPresenceJoin((payload) {
      logInfo('PRESENCE EVENT: JOIN');
      for (final presence in payload.newPresences) {
        final userId = presence.payload['user_id'] as String?;
        if (userId != null) _activeUserIds.add(userId);
      }
      _updateConnectedUsersCount();
    }).onPresenceLeave((payload) {
      logInfo('PRESENCE EVENT: LEAVE');
      for (final presence in payload.leftPresences) {
        final userId = presence.payload['user_id'] as String?;
        if (userId != null) _activeUserIds.remove(userId);
      }
      _updateConnectedUsersCount();
    }).subscribe((status, [error]) async {
      logInfo("PRESENCE STATUS: $status");
      if (status == RealtimeSubscribeStatus.subscribed) {
        await _onlineUsersChannel!.track({
          'user_id': userId,
          'online_at': DateTime.now().toIso8601String(),
        });
        logInfo('PRESENCE: Presence tracked for user $userId.');
      } else if (error != null) {
        logError('PRESENCE ERROR: $error');
        _activeUserIds.clear();
        _updateConnectedUsersCount();
      }
    });
  }

  Future<void> _unsubscribeFromOnlineUsers() async {
    if (_onlineUsersChannel != null) {
      logInfo("PRESENCE: Unsubscribing from 'online-users' channel.");
      await _supabase.removeChannel(_onlineUsersChannel!);
      _onlineUsersChannel = null;
      _activeUserIds.clear();
      _updateConnectedUsersCount();
    }
  }

  void _updateConnectedUsersCount() {
    final newCount = _activeUserIds.length;
    if (connectedUsers.value != newCount) {
      connectedUsers.value = newCount;
    }
    logInfo('PRESENCE COUNT: Connected users: $newCount');
  }

  void _reconcileActiveUsers() {
    if (_onlineUsersChannel == null) return;
    logInfo("PRESENCE: Reconciling user state...");

    final List<SinglePresenceState> presenceStateList = _onlineUsersChannel!.presenceState();
    final Set<String> remoteUserIds = {};

    for (final singleState in presenceStateList) {
      for (final presence in singleState.presences) {
        final userId = presence.payload['user_id'] as String?;
        if (userId != null && userId.isNotEmpty) {
          remoteUserIds.add(userId);
        }
      }
    }

    if (!_areSetsEqual(_activeUserIds, remoteUserIds)) {
      logInfo("PRESENCE: Discrepancy detected. Syncing state. Local: $_activeUserIds, Remote: $remoteUserIds");
      _activeUserIds.clear();
      _activeUserIds.addAll(remoteUserIds);
    }

    _updateConnectedUsersCount();
    logInfo("PRESENCE: Reconciliation complete. Final state: $_activeUserIds");
  }

  bool _areSetsEqual<T>(Set<T> set1, Set<T> set2) {
    if (set1.length != set2.length) return false;
    for (final item in set1) {
      if (!set2.contains(item)) return false;
    }
    return true;
  }
}
