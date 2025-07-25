// lib/main.dart
import 'dart:async';

import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:una_social/app_router.dart';
import 'package:una_social/controllers/auth_controller.dart';
import 'package:una_social/controllers/esterni_controller.dart';
import 'package:una_social/controllers/personale_controller.dart';
import 'package:una_social/controllers/profile_controller.dart';
import 'package:una_social/helpers/logger_helper.dart';

const String supabaseUrlEnvKey = 'SUPABASE_URL';
const String supabaseAnonKeyEnvKey = 'SUPABASE_ANON_KEY';

Future<void> main() async {
  // --- MODIFICA CHIAVE: USARE runZonedGuarded ---
  // Questo crea una "zona" protetta per l'app. Il secondo parametro è un
  // gestore di errori globale che cattura tutte le eccezioni non gestite
  // all'interno della zona, inclusa quella proveniente dal nostro stream.
  await runZonedGuarded<Future<void>>(
    () async {
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

      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
        ),
        debug: true,
      );

      logInfo("Client Supabase inizializzato. Avvio del monitoraggio dell'autenticazione...");

      // Questo listener rimane attivo e gestisce i cambiamenti di stato
      Supabase.instance.client.auth.onAuthStateChange.listen(
        (data) {
          final event = data.event;
          logInfo("Evento Auth ricevuto in tempo reale: $event");
          if (event == AuthChangeEvent.signedOut) {
            logInfo("Sessione terminata. L'UI (gestita da AppRouter/AuthController) dovrebbe ora mostrare la schermata di login.");
          }
        },
        // Il blocco onError viene ancora eseguito come prima
        onError: (error) {
          logError("ERRORE NEL FLUSSO DI AUTENTICAZIONE IN TEMPO REALE: $error");
          if (error is AuthApiException && (error.message.contains('Invalid Refresh Token') || error.statusCode == '400')) {
            logError("Refresh token non valido rilevato. La sessione locale è corrotta o è scaduta sul server. Eseguo il logout forzato per pulirla.");
            Supabase.instance.client.auth.signOut();
          }
        },
      );

      // Aspettiamo solo lo stato iniziale per avviare l'UI
      await Supabase.instance.client.auth.onAuthStateChange.first;
      logInfo("Sincronizzazione autenticazione iniziale completata. Inizializzo i controller.");

      Get.put(AuthController(), permanent: true);
      Get.put(PersonaleController(), permanent: true);
      Get.put(EsterniController(), permanent: true);
      Get.put(ProfileController(), permanent: true);
      logInfo("[Main] Tutti i controller sono stati inizializzati.");

      logInfo("Avvio dell'interfaccia utente (MyApp)...");
      runApp(const MyApp());
    },
    // --- GESTORE GLOBALE DEGLI ERRORI ---
    (error, stack) {
      // Qui intercettiamo l'errore prima che venga mostrato come "non gestito".
      // Possiamo decidere di loggarlo in modo meno aggressivo.
      if (error is AuthApiException) {
        // Riconosciamo questo errore come "gestito" dalla nostra logica di sign-out.
        // Lo logghiamo come INFO invece che come SEVERE per non spaventare.
        logInfo("AuthApiException gestita a livello globale: ${error.message}");
      } else {
        // Per tutti gli altri errori imprevisti, li logghiamo come critici.
        logError("ERRORE NON GESTITO A LIVELLO GLOBALE:", error, stack);
      }
    },
  );
}

// ... (il resto del file MyApp e SupabaseErrorApp rimane invariato) ...
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
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
