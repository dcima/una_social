// lib/controllers/auth_controller.dart
import 'dart:async';

import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:una_social/helpers/logger_helper.dart';

class AuthController extends GetxController {
  final SupabaseClient _supabase = Supabase.instance.client;

  // --- STATI OSSERVABILI ---
  // Permission States
  final RxList<String> userGroups = <String>[].obs;
  final Rxn<bool> isSuperAdmin = Rxn<bool>(); // null = sconosciuto/in caricamento
  final RxBool isLoadingPermissions = false.obs;

  // Realtime Presence States
  final RxInt connectedUsers = 0.obs;
  RealtimeChannel? _onlineUsersChannel;
  final Set<String> _activeUserIds = {};

  // A Completer to manage the first permission load and prevent race conditions.
  Completer<void>? _permissionsCompleter;

  @override
  void onInit() {
    super.onInit();
    // Listen to authentication state changes to reload permissions and manage presence.
    _supabase.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      logInfo('[AuthController] Auth Event: $event');
      _handleAuthStateChange(event);
    });

    // On startup, if a user is already logged in, load their data.
    if (_supabase.auth.currentUser != null) {
      _handleAuthStateChange(AuthChangeEvent.initialSession);
    }
  }

  @override
  void onClose() {
    _unsubscribeFromOnlineUsers(); // Clean up the channel on close
    super.onClose();
  }

  /// Central handler for all authentication events.
  Future<void> _handleAuthStateChange(AuthChangeEvent event) async {
    if (event == AuthChangeEvent.signedIn || event == AuthChangeEvent.tokenRefreshed || event == AuthChangeEvent.userUpdated || event == AuthChangeEvent.initialSession) {
      logInfo('[AuthController] User authenticated or session updated. Loading permissions and subscribing to presence...');
      loadPermissions();
      _subscribeToOnlineUsers();
    } else if (event == AuthChangeEvent.signedOut) {
      logInfo('[AuthController] User signed out.');
      clearUserPermissions();
      _unsubscribeFromOnlineUsers();
    }
  }

  /// Main method to load all user permissions (Super Admin + Groups).
  /// Manages concurrency to avoid multiple calls.
  Future<void> loadPermissions() async {
    if (isLoadingPermissions.value) {
      logInfo('[AuthController] Permission load already in progress, awaiting...');
      return _permissionsCompleter?.future;
    }

    if (_supabase.auth.currentUser == null) {
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

      final bool adminStatus = results[0] as bool;
      final List<String> groups = results[1] as List<String>;

      isSuperAdmin.value = adminStatus;
      userGroups.assignAll(groups);

      logInfo('[AuthController] Permissions loaded. IsSuperAdmin: $adminStatus, Groups: $groups');
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

  /// Clears all user permissions, usually called on logout.
  void clearUserPermissions() {
    userGroups.clear();
    isSuperAdmin.value = null;
    isLoadingPermissions.value = false;
    _permissionsCompleter = null;
    logInfo('[AuthController] User permissions cleared.');
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

    // The presenceState() method returns a List<SinglePresenceState>.
    final List<SinglePresenceState> presenceStateList = _onlineUsersChannel!.presenceState();
    final Set<String> remoteUserIds = {};

    // Iterate over each SinglePresenceState in the list.
    for (final singleState in presenceStateList) {
      // Each state contains a list of presences for a client. Iterate over them.
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
