// lib/main.dart
// ignore_for_file: avoid_print, deprecated_member_use

import 'dart:async';

import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:una_social/app_router.dart';
import 'package:una_social/controllers/auth_controller.dart';
import 'package:una_social/controllers/esterni_controller.dart';
import 'package:una_social/controllers/personale_controller.dart';
import 'package:una_social/controllers/profile_controller.dart'; // <-- 1. IMPORTA IL NUOVO CONTROLLER
import 'package:una_social/helpers/logger_helper.dart';

const String supabaseUrlEnvKey = 'SUPABASE_URL';
const String supabaseAnonKeyEnvKey = 'SUPABASE_ANON_KEY';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  setUrlStrategy(PathUrlStrategy());

  logInfo("App avviata. Tentativo di inizializzazione Supabase...");

  const String supabaseUrl = String.fromEnvironment(supabaseUrlEnvKey, defaultValue: '');
  const String supabaseAnonKey = String.fromEnvironment(supabaseAnonKeyEnvKey, defaultValue: '');

  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    String errorMessage = "ERRORE CRITICO: Le variabili d'ambiente Supabase non sono definite.";
    logError(errorMessage);
    runApp(SupabaseErrorApp(error: errorMessage));
    return;
  }

  logInfo("Supabase URL (da --dart-define): $supabaseUrl");

  try {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
      debug: true,
    );
    logInfo("Client Supabase inizializzato. In attesa di uno stato di autenticazione stabile...");

    // --- CANCELLO DI SINCRONIZZAZIONE ROBUSTO ---
    final authCompleter = Completer<void>();
    StreamSubscription? subscription;
    subscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (data) {
        final event = data.event;
        if (event == AuthChangeEvent.signedIn || event == AuthChangeEvent.tokenRefreshed || event == AuthChangeEvent.passwordRecovery) {
          logInfo("Stato di autenticazione PRONTO ($event). Sblocco dell'app.");
          if (!authCompleter.isCompleted) {
            authCompleter.complete();
            subscription?.cancel();
          }
        } else if (event == AuthChangeEvent.initialSession && data.session == null) {
          logInfo("Stato di autenticazione PRONTO (Nessun utente). Sblocco dell'app.");
          if (!authCompleter.isCompleted) {
            authCompleter.complete();
            subscription?.cancel();
          }
        }
      },
      onError: (error) {
        logError("Errore critico nel flusso di autenticazione: $error");
        if (!authCompleter.isCompleted) {
          authCompleter.completeError(error);
          subscription?.cancel();
        }
      },
    );

    await authCompleter.future;
    logInfo("Sincronizzazione autenticazione completata. Inizializzo i controller.");

    Get.put(AuthController(), permanent: true);
    Get.put(PersonaleController(), permanent: true);
    Get.put(EsterniController(), permanent: true);
    Get.put(ProfileController(), permanent: true); // <-- 2. INIETTA IL NUOVO CONTROLLER
    logInfo("[Main] Tutti i controller sono stati inizializzati.");
  } catch (e, stackTrace) {
    logError("ERRORE CRITICO durante l'inizializzazione:", e, stackTrace);
    runApp(SupabaseErrorApp(error: "Errore inizializzazione Supabase: ${e.toString()}"));
    return;
  }

  logInfo("Avvio dell'interfaccia utente (MyApp)...");
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Nessuna modifica necessaria qui. GetMaterialApp.router è corretto.
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
      routerDelegate: AppRouter.router.routerDelegate,
      routeInformationParser: AppRouter.router.routeInformationParser,
      routeInformationProvider: AppRouter.router.routeInformationProvider,
    );
  }
}

// Nessuna modifica necessaria a SupabaseErrorApp
class SupabaseErrorApp extends StatelessWidget {
  final String error;
  const SupabaseErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
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
              ],
            ),
          ),
        ),
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}
