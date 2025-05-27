// lib/main.dart
// ignore_for_file: avoid_print, deprecated_member_use

import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart'; // *** Importa GetX ***
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:una_social_app/app_router.dart';
import 'package:una_social_app/controllers/auth_controller.dart'; // *** Importa AuthController ***
import 'package:una_social_app/helpers/logger_helper.dart'; // Importa il logger

// --- ValueNotifier Globale RIMOSSO ---
// final ValueNotifier<AuthStatus> appAuthStatusNotifier = ValueNotifier(AuthStatus.loading);
// enum AuthStatus { loading, authenticated, unauthenticated }
// --- FINE ValueNotifier RIMOSSO ---

const String supabaseUrlEnvKey = 'SUPABASE_URL';
const String supabaseAnonKeyEnvKey = 'SUPABASE_ANON_KEY';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  setUrlStrategy(PathUrlStrategy());

  logInfo("App avviata. Tentativo di inizializzazione Supabase...");

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
    errorMessage += "Assicurati che siano definite con --dart-define.";

    logError(errorMessage);

    runApp(SupabaseErrorApp(error: errorMessage));
    return;
  }

  logInfo("Supabase URL (da --dart-define): $supabaseUrl");

  try {
    logInfo("Inizializzazione Supabase...");
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
      debug: true, // Puoi impostare a false per produzione
    );
    logInfo("Supabase inizializzato.");

    // *** Inizializza AuthController di GetX dopo Supabase ***
    Get.put(AuthController(), permanent: true); // permanent: true per mantenerlo vivo durante tutta l'app
    logInfo("[Main] AuthController inizializzato con GetX.");

    // Il listener onAuthStateChange in AuthController gestirà l'aggiornamento
    // dello stato dei gruppi/permessi. GoRouterRefreshStream (usato da AppRouter)
    // ascolterà anch'esso onAuthStateChange per triggerare i redirect del router.
    // Non è più necessario un listener separato qui in main.dart per aggiornare
    // uno stato di autenticazione globale come appAuthStatusNotifier.
    // AuthHelper può ancora essere usato per tracciare la ragione del logout.

    logInfo("Listener onAuthStateChange in AuthController si occuperà dello stato utente.");
  } catch (e, stackTrace) {
    logError("ERRORE CRITICO init Supabase:", e, stackTrace);

    // Non possiamo usare AuthController qui se Supabase fallisce
    runApp(SupabaseErrorApp(error: "Errore inizializzazione Supabase: ${e.toString()}"));
    return;
  }

  logInfo("Avvio MyApp...");
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Usa GetMaterialApp per l'integrazione completa con GetX,
    // anche se GoRouter gestisce la navigazione principale.
    return GetMaterialApp.router(
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
      // Configurazione di GoRouter
      routerDelegate: AppRouter.router.routerDelegate,
      routeInformationParser: AppRouter.router.routeInformationParser,
      routeInformationProvider: AppRouter.router.routeInformationProvider,
    );
  }
}

class SupabaseErrorApp extends StatelessWidget {
  final String error;
  const SupabaseErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // Non GetMaterialApp qui, è una schermata di errore fallback
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
                  'Verifica la connessione, le variabili d\'ambiente Supabase definite con --dart-define e riavvia l\'applicazione.',
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
