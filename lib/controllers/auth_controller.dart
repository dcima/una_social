// lib/controllers/auth_controller.dart
import 'dart:async'; // Import for Timer and StreamSubscription

import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:una_social/helpers/logger_helper.dart';
import 'package:una_social/controllers/personale_controller.dart'; // Import PersonaleController
import 'package:una_social/controllers/esterni_controller.dart'; // Import EsterniController
import 'package:una_social/models/personale.dart'; // Import Personale model
import 'package:una_social/models/esterni.dart'; // Import Esterni model

// Define the UserType enum
enum UserType { personale, esterno }

class AuthController extends GetxController {
  final SupabaseClient _supabase = Supabase.instance.client;

  String? lastUserEmail;

  // --- STATI OSSERVABILI ---
  final RxList<String> userGroups = <String>[].obs;
  final Rxn<bool> isSuperAdmin = Rxn<bool>();
  final RxBool isLoadingPermissions = false.obs;
  final RxInt connectedUsers = 0.obs;

  // AGGIUNTO: Stato reattivo per indicare se l'utente è loggato
  final _isLoggedIn = false.obs;
  bool get isLoggedIn => _isLoggedIn.value;

  // AGGIUNTO: Stato reattivo per il tipo di utente
  final Rxn<UserType> _currentUserType = Rxn<UserType>();
  UserType? get currentUserType => _currentUserType.value;
  bool get isPersonale => _currentUserType.value == UserType.personale;
  bool get isEsterno => _currentUserType.value == UserType.esterno;

  // AGGIUNTO: Metodo per impostare lo stato di login, chiamato da main.dart
  void setIsLoggedIn(bool value) {
    if (_isLoggedIn.value != value) {
      _isLoggedIn.value = value;
      logInfo('[AuthController] Stato isLoggedIn aggiornato a: $value');
    }
  }

  // --- PROPRIETÀ PRIVATE ---
  RealtimeChannel? _onlineUsersChannel;
  final Set<String> _activeUserIds = {};
  Completer<void>? _permissionsCompleter;
  Completer<void>? _userTypeCompleter; // New completer for user type determination

  // GetX controllers for profiles
  // Using `late final` and `Get.find()` in onInit ensures they are available
  // after the GetX binding is set up. This assumes PersonaleController
  // and EsterniController are registered with GetX (e.g., in main.dart or a binding).
  late final PersonaleController _personaleController;
  late final EsterniController _esterniController;

  @override
  void onInit() {
    super.onInit();
    // Initialize other controllers here, assuming they are registered
    _personaleController = Get.find<PersonaleController>();
    _esterniController = Get.find<EsterniController>();

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
      setIsLoggedIn(true);

      if (event == AuthChangeEvent.signedIn || event == AuthChangeEvent.initialSession || event == AuthChangeEvent.tokenRefreshed) {
        lastUserEmail = _supabase.auth.currentUser?.email;
        logInfo('[AuthController] Session available. Loading permissions and subscribing to presence.');
        loadPermissions();
        _determineAndSetUserType(); // Call new method to determine user type
        _subscribeToOnlineUsers();
      }
    } else {
      // session == null
      setIsLoggedIn(false);

      if (event == AuthChangeEvent.signedOut || event == AuthChangeEvent.initialSession) {
        logInfo('[AuthController] No session. Clearing permissions and unsubscribing.');
        clearUserPermissions();
        _clearUserType(); // Call new method to clear user type
        _unsubscribeFromOnlineUsers();
      }
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
      _permissionsCompleter = null; // Reset after completion
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
    _permissionsCompleter = null; // Reset
    logInfo('[AuthController] User permissions cleared.');
  }

  /// New method to determine and set the user type (personale/esterno).
  Future<void> _determineAndSetUserType() async {
    if (_userTypeCompleter != null && !_userTypeCompleter!.isCompleted) {
      logInfo('[AuthController] User type determination already in progress, awaiting...');
      return _userTypeCompleter?.future;
    }
    if (_supabase.auth.currentUser == null) {
      logError('[AuthController] _determineAndSetUserType called with no user.');
      _clearUserType();
      return;
    }

    _userTypeCompleter = Completer<void>();
    logInfo('[AuthController] Starting user type determination...');

    StreamSubscription? personaleSub;
    StreamSubscription? esternoSub;
    Timer? timeoutTimer;

    try {
      // Function to check profiles and complete the completer
      void checkProfiles() {
        final Personale? personaleProfile = _personaleController.personale.value;
        final Esterni? esternoProfile = _esterniController.esterni.value;

        if (personaleProfile != null) {
          _currentUserType.value = UserType.personale;
          logInfo('[AuthController] User type determined as Personale.');
          if (!(_userTypeCompleter?.isCompleted ?? true)) _userTypeCompleter!.complete();
        } else if (esternoProfile != null) {
          _currentUserType.value = UserType.esterno;
          logInfo('[AuthController] User type determined as Esterno.');
          if (!(_userTypeCompleter?.isCompleted ?? true)) _userTypeCompleter!.complete();
        } else {
          // If both are null, it might mean they are still loading or no profile exists.
          // We don't complete here, we wait for a profile or timeout.
          logInfo('[AuthController] Profiles still null, waiting for Personale/Esterni controllers to update...');
        }
      }

      // Initial check in case profiles are already loaded
      checkProfiles();

      // If not completed, set up listeners
      if (!(_userTypeCompleter?.isCompleted ?? true)) {
        personaleSub = _personaleController.personale.listen((_) => checkProfiles());
        esternoSub = _esterniController.esterni.listen((_) => checkProfiles());

        // Set a timeout to prevent infinite waiting
        timeoutTimer = Timer(const Duration(seconds: 5), () {
          if (!(_userTypeCompleter?.isCompleted ?? true)) {
            _currentUserType.value = null; // Could not determine in time
            logWarning('[AuthController] User type determination timed out. No profile found within 5 seconds.');
            _userTypeCompleter!.complete(); // Complete to unblock
          }
        });

        await _userTypeCompleter!.future; // Wait for a profile or timeout
      }
    } catch (e) {
      logError('[AuthController] Error determining user type: $e');
      _currentUserType.value = null;
    } finally {
      // Clean up subscriptions and timer regardless of success or failure
      personaleSub?.cancel();
      esternoSub?.cancel();
      timeoutTimer?.cancel();

      if (!(_userTypeCompleter?.isCompleted ?? true)) {
        _userTypeCompleter!.complete(); // Ensure it's always completed
      }
      _userTypeCompleter = null; // Reset after completion
    }
  }

  /// Clears the user type, usually called on logout.
  void _clearUserType() {
    _currentUserType.value = null;
    if (!(_userTypeCompleter?.isCompleted ?? true)) {
      _userTypeCompleter?.completeError("User type cleared during determination.");
    }
    _userTypeCompleter = null; // Reset
    logInfo('[AuthController] User type cleared.');
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

    final Set<String> remoteUserIds = presenceStateList.expand((state) => state.presences).map((p) => p.payload['user_id'] as String?).whereType<String>().toSet();

    if (!_areSetsEqual(_activeUserIds, remoteUserIds)) {
      logInfo("PRESENCE: Discrepancy detected. Syncing state. Local: $_activeUserIds, Remote: $remoteUserIds");
      _activeUserIds
        ..clear()
        ..addAll(remoteUserIds);
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
