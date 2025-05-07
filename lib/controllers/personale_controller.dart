// Controller GetX
// ignore_for_file: avoid_print

import 'dart:convert';

import 'package:get/get_rx/src/rx_types/rx_types.dart';
import 'package:get/get_state_manager/src/simple/get_controllers.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:una_social_app/models/personale.dart'; // Ensure path is correct

class PersonaleController extends GetxController {
  final supabase = Supabase.instance.client;
  var personale = Rxn<Personale>(); // Rxn handles null values reactively
  var connectedUsers = 0.obs;
  var appVersion = ''.obs;
  var message = ''.obs; // For showing errors or status messages

  @override
  void onInit() {
    super.onInit();
    _loadUserData();
    _loadAppVersion();
    // TODO: subscribe a real-time count di utenti collegati
  }

  Future<void> _loadUserData() async {
    message.value = ''; // Clear previous message
    personale.value = null; // Clear previous data while loading
    final user = supabase.auth.currentUser;

    if (user == null) {
      message.value = 'Utente non autenticato.';
      print('Errore: Utente non autenticato.');
      return;
    }

    final email = user.email!;
    final jsonEmailArray = '[${jsonEncode(email)}]';

    if (jsonEmailArray.isEmpty) {
      message.value = 'Email utente non disponibile.';
      print('Errore: Email utente non disponibile.');
      return;
    }

    print('Attempting to load data for email: $jsonEmailArray');

    try {
      // Use .contains() with the primitive string value for JSONB array search
      final record = await supabase.from('personale').select('*').filter('emails', 'cs', jsonEmailArray).maybeSingle(); // Fetches one record or null
      // final record = await supabase.from('personale').select('*').contains('emails', [email]).maybeSingle(); // Fetches one record or null

      if (record == null) {
        message.value = 'Nessun profilo trovato per l\'email: $email';
        print('Nessun record trovato per l\'email: $email');
        personale.value = null; // Explicitly set to null
      } else {
        print('Record trovato: $record');
        // Safely parse the record using the updated model
        personale.value = Personale.fromJson(record);
        print('Personale model caricato: ${personale.value}');
        message.value = ''; // Clear any previous error message on success
      }
    } on PostgrestException catch (err) {
      message.value = 'Errore database: ${err.message} (Code: ${err.code})';
      print('PostgrestException: Code: ${err.code}, Details: ${err.details}, Hint: ${err.hint}, Message: ${err.message}');
      personale.value = null;
    } catch (err, stackTrace) {
      // Catch generic errors too
      message.value = 'Errore imprevisto: $err';
      print('Errore imprevisto in _loadUserData: $err');
      print('Stack trace: $stackTrace');
      personale.value = null;
    }

    print('Fine _loadUserData, personale.value: ${personale.value}');
  }

  Future<void> _loadAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      appVersion.value = info.version;
    } catch (e) {
      print("Errore caricamento versione app: $e");
      appVersion.value = "N/A"; // Indicate error
    }
  }

  Future<void> reload() async {
    print("Reloading user data...");
    await _loadUserData();
  }
}
