// lib/controllers/personale_controller.dart
import 'dart:async';

import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:una_social/helpers/logger_helper.dart';
import 'package:una_social/models/personale.dart';

class PersonaleController extends GetxController {
  final supabase = Supabase.instance.client;
  var personale = Rxn<Personale>();
  var isLoading = false.obs;
  var message = ''.obs;

  StreamSubscription<AuthState>? _authSubscription;

  @override
  void onInit() {
    super.onInit();
    logInfo('PersonaleController: onInit()');

    // Listen to auth state changes to trigger data loading/clearing.
    _authSubscription = supabase.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      logInfo("PersonaleController.onAuthStateChange: Evento $event");
      _handleAuthStateChange(event);
    });

    // Handle the case where a user is already logged in when the app starts.
    if (supabase.auth.currentUser != null) {
      logInfo("PersonaleController.onInit: Existing session detected. Starting data load.");
      _handleAuthStateChange(AuthChangeEvent.initialSession);
    }
  }

  @override
  void onClose() {
    logInfo('PersonaleController: onClose()');
    _authSubscription?.cancel(); // Prevent memory leaks
    super.onClose();
  }

  /// Handles loading or clearing user data based on the authentication event.
  Future<void> _handleAuthStateChange(AuthChangeEvent event) async {
    // Guard to prevent multiple concurrent loads.
    if (isLoading.value) {
      logInfo("PersonaleController: Load already in progress, ignoring new event '$event'.");
      return;
    }

    isLoading.value = true;

    if (event == AuthChangeEvent.signedIn || event == AuthChangeEvent.initialSession || event == AuthChangeEvent.userUpdated) {
      logInfo("PersonaleController: User logged in or session initialized. Loading data...");
      await _loadUserData();
    } else if (event == AuthChangeEvent.signedOut) {
      logInfo("PersonaleController: User signed out. Clearing state...");
      personale.value = null;
      message.value = 'User signed out.';
    }

    isLoading.value = false;
  }

  /// Fetches the 'personale' profile from the database.
  Future<void> _loadUserData() async {
    message.value = 'Loading user profile...';
    final user = supabase.auth.currentUser;

    if (user == null) {
      logInfo('PersonaleController: Attempted to load data without an authenticated user. Aborting.');
      personale.value = null;
      return;
    }

    try {
      final response = await supabase.from('personale').select().eq('email_principale', user.email!).limit(1).maybeSingle();

      if (response != null) {
        personale.value = Personale.fromJson(response);
        logInfo("PersonaleController: Profile loaded for ${personale.value?.fullName}");
        message.value = 'User profile loaded.';
      } else {
        logInfo("PersonaleController: No 'personale' profile found for: ${user.email}");
        personale.value = null; // Explicitly set to null if not found
        message.value = 'Personale profile not found.';
      }
    } catch (err) {
      message.value = 'Error loading user data.';
      logError('PersonaleController: _loadUserData failed with error: $err');
      personale.value = null;
    }
  }

  /// Public method to manually trigger a data reload.
  Future<void> reload() async {
    logInfo('PersonaleController: reload() requested.');
    // Simulate a user update event to force a refresh.
    await _handleAuthStateChange(AuthChangeEvent.userUpdated);
  }
}
