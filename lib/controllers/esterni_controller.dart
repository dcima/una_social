// lib/controllers/esterni_controller.dart
import 'dart:async';

import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:una_social/helpers/logger_helper.dart';
import 'package:una_social/models/esterni.dart';

class EsterniController extends GetxController {
  final supabase = Supabase.instance.client;
  var esterni = Rxn<Esterni>();
  var isLoading = false.obs;
  var message = ''.obs;

  StreamSubscription<AuthState>? _authSubscription;

  @override
  void onInit() {
    super.onInit();
    logInfo('EsterniController: onInit()');

    // Listen to auth state changes to trigger data loading/clearing.
    _authSubscription = supabase.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      logInfo("EsterniController.onAuthStateChange: Evento $event");
      _handleAuthStateChange(event);
    });

    // Handle the case where a user is already logged in when the app starts.
    if (supabase.auth.currentUser != null) {
      logInfo("EsterniController.onInit: Existing session detected. Starting data load.");
      _handleAuthStateChange(AuthChangeEvent.initialSession);
    }
  }

  @override
  void onClose() {
    logInfo('EsterniController: onClose()');
    _authSubscription?.cancel(); // Prevent memory leaks
    super.onClose();
  }

  /// Handles loading or clearing user data based on the authentication event.
  Future<void> _handleAuthStateChange(AuthChangeEvent event) async {
    // Guard to prevent multiple concurrent loads.
    if (isLoading.value) {
      logInfo("EsterniController: Load already in progress, ignoring new event '$event'.");
      return;
    }

    isLoading.value = true;

    if (event == AuthChangeEvent.signedIn || event == AuthChangeEvent.initialSession || event == AuthChangeEvent.userUpdated) {
      logInfo("EsterniController: User logged in or session initialized. Loading data...");
      await _loadUserData();
    } else if (event == AuthChangeEvent.signedOut) {
      logInfo("EsterniController: User signed out. Clearing state...");
      esterni.value = null;
      message.value = 'User signed out.';
    }

    isLoading.value = false;
  }

  /// Fetches the 'esterni' profile from the database.
  Future<void> _loadUserData() async {
    message.value = 'Loading user profile...';
    final user = supabase.auth.currentUser;

    if (user == null) {
      logInfo('EsterniController: Attempted to load data without an authenticated user. Aborting.');
      esterni.value = null;
      return;
    }

    try {
      final response = await supabase.from('esterni').select().eq('email_principale', user.email!).limit(1).maybeSingle();

      if (response != null) {
        esterni.value = Esterni.fromJson(response);
        logInfo("EsterniController: Profile loaded for ${esterni.value?.nome} ${esterni.value?.cognome}");
        message.value = 'User profile loaded.';
      } else {
        logInfo("EsterniController: No 'esterni' profile found for: ${user.email}");
        esterni.value = null; // Explicitly set to null if not found
        message.value = 'Esterni profile not found.';
      }
    } catch (err) {
      message.value = 'Error loading user data.';
      logError('EsterniController: _loadUserData failed with error: $err');
      esterni.value = null;
    }
  }

  /// Public method to manually trigger a data reload.
  Future<void> reload() async {
    logInfo('EsterniController: reload() requested.');
    // Simulate a user update event to force a refresh.
    await _handleAuthStateChange(AuthChangeEvent.userUpdated);
  }
}
