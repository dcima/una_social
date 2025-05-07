// lib/main.dart
// ignore_for_file: avoid_print, deprecated_member_use

import 'package:flutter/material.dart';
// Rimuovi: import 'package:get/get.dart'; // Non più necessario per GetMaterialApp
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
//import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:una_social_app/app_router.dart'; // Importa il tuo router GoRouter

// --- ValueNotifier Globale ---
// Usato da GoRouter per i redirect
final ValueNotifier<bool> initialAuthCompleted = ValueNotifier(false);
// --- FINE ValueNotifier ---

// Definisci le costanti per le chiavi, per evitare typo e per coerenza con --dart-define
const String supabaseUrlEnvKey = 'SUPABASE_URL';
const String supabaseAnonKeyEnvKey = 'SUPABASE_ANON_KEY';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  setUrlStrategy(PathUrlStrategy());
  print("URL Strategy impostata su Path.");

/*****
  try {
    await dotenv.load(fileName: ".env");
    print(".env caricato.");
  } catch (e) {
    print("ATTENZIONE: Errore durante caricamento .env: $e.");
  }

  final String supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
  final String supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    print("ERRORE CRITICO: SUPABASE_URL o SUPABASE_ANON_KEY non trovate o vuote!");
    runApp(const SupabaseErrorApp(error: "Variabili d'ambiente Supabase mancanti o vuote in .env."));
    return;
  }
******/
// Leggi le variabili d'ambiente definite al momento della compilazione/lancio con --dart-define
  const String supabaseUrl = String.fromEnvironment(supabaseUrlEnvKey, defaultValue: '');
  const String supabaseAnonKey = String.fromEnvironment(supabaseAnonKeyEnvKey, defaultValue: '');

  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    String errorMessage = "ERRORE CRITICO: ";
    if (supabaseUrl.isEmpty) {
      errorMessage += "$supabaseUrlEnvKey non trovata o vuota. ";
    }
    if (supabaseAnonKey.isEmpty) {
      errorMessage += "$supabaseAnonKeyEnvKey non trovata o vuota. ";
    }
    errorMessage += "Assicurati che siano definite con --dart-define nel comando di build/run (es. nel launch.json di VS Code).";

    print(errorMessage);
    runApp(SupabaseErrorApp(error: errorMessage));
    return;
  }

  print("Supabase URL (da --dart-define): $supabaseUrl");
  // print("Supabase Anon Key (da --dart-define): $supabaseAnonKey"); // Non stampare la chiave in produzione per sicurezza!

  // --- Inizializzazione Supabase ---
  try {
    print("Inizializzazione Supabase...");
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
      debug: true,
    );
    print("Supabase inizializzato.");

    // --- Listener per cambiamenti stato autenticazione ---
    print("Impostazione listener onAuthStateChange POST-init...");
    Supabase.instance.client.auth.onAuthStateChange.listen(
      (data) {
        final AuthChangeEvent event = data.event;
        final Session? session = data.session;
        print('[MAIN AUTH LISTENER POST-INIT] Evento Ricevuto: $event, Sessione: ${session != null ? "Presente (${session.user.id})" : "Assente"}');

        // Aggiorna il ValueNotifier per riflettere lo stato di login/logout.
        switch (event) {
          case AuthChangeEvent.signedIn:
          case AuthChangeEvent.tokenRefreshed:
          case AuthChangeEvent.mfaChallengeVerified:
          case AuthChangeEvent.userUpdated:
            if (!initialAuthCompleted.value) {
              print('[MAIN AUTH LISTENER POST-INIT] Rilevato stato Loggato ($event), imposto initialAuthCompleted a true.');
              initialAuthCompleted.value = true;
            }
            break; // Non dimenticare i break!

          case AuthChangeEvent.signedOut:
          case AuthChangeEvent.userDeleted:
            if (initialAuthCompleted.value) {
              print('[MAIN AUTH LISTENER POST-INIT] Rilevato stato Sloggato ($event), imposto initialAuthCompleted a false.');
              initialAuthCompleted.value = false;
            }
            break; // Non dimenticare i break!

          // --- CASO MANCANTE AGGIUNTO ---
          case AuthChangeEvent.initialSession:
            // Questo evento segnala lo stato iniziale letto.
            // Lo stato è già stato impostato dal controllo immediato dopo l'init,
            // quindi qui non facciamo nulla che modifichi initialAuthCompleted.value.
            print('[MAIN AUTH LISTENER POST-INIT] Gestito evento initialSession (nessuna modifica allo stato necessaria qui).');
            break; // Aggiunto break

          case AuthChangeEvent.passwordRecovery:
            // Non cambia lo stato di login/logout.
            print('[MAIN AUTH LISTENER POST-INIT] Gestito evento passwordRecovery.');
            break;
        }
      },
      onError: (error) {
        // Gestisce eventuali errori nello stream di eventi auth.
        print('[MAIN AUTH LISTENER POST-INIT] Errore nello stream onAuthStateChange: $error');
        if (initialAuthCompleted.value) {
          initialAuthCompleted.value = false; // Resetta a false in caso di errore grave
        }
      },
    );
    print("Listener onAuthStateChange POST-init impostato.");

    // --- Controllo Sessione Iniziale ---
    print("Controllo sessione iniziale...");
    final initialSession = Supabase.instance.client.auth.currentSession;
    if (initialSession != null && !initialSession.isExpired) {
      print("[MAIN CHECK] Sessione iniziale valida.");
      initialAuthCompleted.value = true;
    } else {
      print("[MAIN CHECK] Nessuna sessione iniziale valida.");
    }
  } catch (e, stackTrace) {
    print("ERRORE CRITICO init Supabase: $e");
    print("Stack trace: $stackTrace");
    initialAuthCompleted.value = false;
    runApp(SupabaseErrorApp(error: "Errore inizializzazione Supabase: ${e.toString()}"));
    return;
  }

  print("Avvio MyApp...");
  runApp(const MyApp());
}

// --- Widget Radice dell'Applicazione ---
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // --- TORNA A MaterialApp.router ---
    // Gestisce il routing tramite GoRouter.
    // GetX verrà usato solo per State Management.
    return MaterialApp.router(
      title: 'Una Social',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.lightBlueAccent,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(elevation: 0.5, backgroundColor: Colors.white, foregroundColor: Colors.black87),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.lightBlueAccent,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,

      // --- Configurazione GoRouter ---
      // Passa direttamente il routerConfig di GoRouter.
      routerConfig: AppRouter.router,
      // --- Fine Configurazione GoRouter ---
    );
  }
}

// --- Widget per Mostrare Errori Critici ---
// (Invariato, usa MaterialApp standard)
class SupabaseErrorApp extends StatelessWidget {
  final String error;
  const SupabaseErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // Usa MaterialApp standard qui
      theme: ThemeData.light(useMaterial3: true),
      darkTheme: ThemeData.dark(useMaterial3: true),
      themeMode: ThemeMode.system,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error, size: 60),
                const SizedBox(height: 20),
                Text(
                  'Errore Critico Applicazione',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.error),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 15),
                Text(
                  error,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: 25),
                const Text(
                  'Verifica la connessione, il file .env e riavvia l\'applicazione.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}
