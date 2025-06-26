// lib/main.dart
// ignore_for_file: avoid_print, deprecated_member_use

import 'dart:async';

import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:una_social/app_router.dart';
import 'package:una_social/controllers/auth_controller.dart';
import 'package:una_social/helpers/logger_helper.dart';

const String supabaseUrlEnvKey = 'SUPABASE_URL';
const String supabaseAnonKeyEnvKey = 'SUPABASE_ANON_KEY';

Future<void> main() async {
  // 1. Assicura che i binding di Flutter siano pronti
  WidgetsFlutterBinding.ensureInitialized();
  setUrlStrategy(PathUrlStrategy());

  logInfo("App avviata. Tentativo di inizializzazione Supabase...");

  // 2. Controlla le variabili d'ambiente Supabase
  const String supabaseUrl = String.fromEnvironment(supabaseUrlEnvKey, defaultValue: '');
  const String supabaseAnonKey = String.fromEnvironment(supabaseAnonKeyEnvKey, defaultValue: '');

  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    String errorMessage = "ERRORE CRITICO: Le variabili d'ambiente Supabase non sono definite. "
        "Assicurati che siano fornite tramite --dart-define.";
    logError(errorMessage);
    runApp(SupabaseErrorApp(error: errorMessage));
    return;
  }

  logInfo("Supabase URL (da --dart-define): $supabaseUrl");

  try {
    // 1. Inizializza Supabase (questo non attende la sessione dall'URL)
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
      debug: true,
    );
    logInfo("Supabase inizializzato con successo.");

    // 2. --- LA SOLUZIONE ALLA RACE CONDITION ---
    // Creiamo un "cancello" (un Completer) che si aprirà solo quando
    // avremo ricevuto la conferma della sessione iniziale.
    final completer = Completer<void>();
    StreamSubscription? subscription;

    subscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      // Attendiamo l'evento che ci dice che Supabase ha finito di controllare
      // sia il local storage sia l'URL.
      if (data.event == AuthChangeEvent.initialSession) {
        logInfo("Evento 'initialSession' ricevuto. Lo stato di autenticazione è stabile.");
        // Abbiamo la nostra risposta. Apriamo il cancello.
        if (!completer.isCompleted) {
          completer.complete();
        }
        // Cancelliamo la sottoscrizione per non interferire con GoRouter.
        subscription?.cancel();
      }
    }, onError: (error) {
      logError("Errore nel flusso di autenticazione iniziale: $error");
      if (!completer.isCompleted) {
        completer.completeError(error);
      }
      subscription?.cancel();
    });

    // 3. Attendiamo che il cancello si apra.
    // L'app rimarrà "bloccata" qui finché l'evento initialSession non arriva.
    await completer.future;

    // 4. Inizializza i controller di GetX dopo che Supabase è pronto
    Get.put(AuthController(), permanent: true);
    logInfo("[Main] AuthController inizializzato con GetX.");
  } catch (e, stackTrace) {
    logError("ERRORE CRITICO durante l'inizializzazione di Supabase:", e, stackTrace);
    runApp(SupabaseErrorApp(error: "Errore inizializzazione Supabase: ${e.toString()}"));
    return;
  }

  // 5. Avvia l'applicazione principale SOLO DOPO che tutto è pronto.
  logInfo("Avvio MyApp...");
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Usa GetMaterialApp.router per l'integrazione con GoRouter
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

      // --- LA CORREZIONE È QUI ---
      // GetMaterialApp.router non usa 'routerConfig'.
      // Dobbiamo usare i parametri delegate-based che mi aveva mostrato prima.
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
                  'Verifica la connessione e le variabili d\'ambiente, poi riavvia l\'applicazione.',
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
