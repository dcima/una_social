// Controller GetX
// ignore_for_file: avoid_print

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

  Future<Personale?> findPersonaleByEmailValueRpc(String targetEmailValue) async {
    print('Searching for email value via RPC: $targetEmailValue');

    try {
      // NO .select() here
      final response = await supabase.rpc(
        'search_personale_by_email_value',
        params: {'target_email': targetEmailValue},
      ).maybeSingle();

      // If PostgrestException (PGRST116) was not thrown, it means exactly one row was returned.
      // 'response' will be the Map<String, dynamic> for that row.
      print('Record trovato (RPC): $response');
      return Personale.fromJson(response as Map<String, dynamic>);
    } on PostgrestException catch (error) {
      if (error.code == 'PGRST116') {
        if (error.message.contains("0 rows")) {
          print('Nessun record trovato con il valore email specificato (RPC - PGRST116 for 0 rows).');
          return null; // Correctly interpret as "not found"
        } else if (error.message.contains("multiple")) {
          // Check if "multiple" is in the message
          print('ERRORE (RPC - PGRST116 for multiple rows): Più record trovati per l\'email: $targetEmailValue. Controllare i dati e la logica della funzione PG.');
          print('Details: ${error.details}, Hint: ${error.hint}, Message: ${error.message}');
          return null; // Or throw a more specific application error
        } else {
          print('Errore Postgrest (PGRST116, messaggio non standard) durante la ricerca (RPC): $error');
          print('Details: ${error.details}, Hint: ${error.hint}, Message: ${error.message}');
          return null;
        }
      } else {
        print('Errore Postgrest (diverso da PGRST116) durante la ricerca (RPC): $error');
        print('Details: ${error.details}, Hint: ${error.hint}, Code: ${error.code}, Message: ${error.message}');
        return null;
      }
    } catch (err, stackTrace) {
      print('Errore generico imprevisto durante la ricerca (RPC): $err');
      print('Stack trace: $stackTrace');
      return null;
    }
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
    final stopwatch = Stopwatch()..start();

    try {
      final record = await findPersonaleByEmailValueRpc(email); // Fetches one record or null
      stopwatch.stop(); // Ferma lo stopwatch
      print('Tempo di esecuzione della query: ${stopwatch.elapsed}');

      if (record == null) {
        message.value = 'Nessun profilo trovato per l\'email: $email';
        print('Nessun record trovato per l\'email: $email');
        personale.value = null; // Explicitly set to null
      } else {
        print('Record trovato: $record');
        // Safely parse the record using the updated model
        personale.value = Personale.fromJson(record as Map<String, dynamic>);
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
