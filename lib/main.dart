// lib/main.dart
import 'dart:async';

import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:una_social/app_router.dart'; // Assumendo che AppRouter gestisca GoRouter e il reindirizzamento
import 'package:una_social/controllers/auth_controller.dart'; // Assumendo che AuthController gestisca lo stato di login
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
  // all'interno della zona.
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

      // Inizializza il client Supabase
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
        ),
        debug: true,
      );
      logInfo("Client Supabase inizializzato.");

      // Inizializza AuthController molto presto. Questo controller dovrebbe gestire lo stato di autenticazione.
      final AuthController authController = Get.put(AuthController(), permanent: true);
      logInfo("AuthController inizializzato.");

      // --- Critico: Gestione della validazione iniziale della sessione per ripartenze sporche ---
      // Dopo Supabase.initialize, currentSession potrebbe non essere nullo anche se il refresh token non è valido.
      // Tentiamo esplicitamente di rinfrescare la sessione per forzare la validazione.
      try {
        final Session? session = Supabase.instance.client.auth.currentSession;
        if (session != null) {
          logInfo("Sessione Supabase rilevata. Tentativo di ripristino/validazione esplicita...");
          // Tentando di rinfrescare la sessione, verrà lanciata una AuthApiException se il refresh token non è valido/scaduto.
          // Se ha successo, currentSession verrà aggiornato, o rimarrà lo stesso se valido.
          await Supabase.instance.client.auth.refreshSession();
          logInfo("Sessione Supabase validata/rinfrescata con successo.");
          authController.setIsLoggedIn(true); // Assicurati che AuthController rifletta questo
        } else {
          logInfo("Nessuna sessione Supabase attiva all'avvio.");
          authController.setIsLoggedIn(false); // Assicurati che AuthController rifletta questo
        }
      } on AuthApiException catch (e) {
        // Questo cattura specificamente l'errore 'Invalid Refresh Token' o altri errori di autenticazione.
        if (e.message.contains('Invalid Refresh Token') || e.statusCode == '400') {
          logError("Refresh token non valido rilevato durante l'avvio: ${e.message}. Eseguo il logout forzato per pulire la cache.");
          await Supabase.instance.client.auth.signOut(); // Pulisce lo storage locale e attiva l'evento signedOut
          authController.setIsLoggedIn(false); // Assicurati che AuthController sappia che siamo disconnessi
        } else {
          // Rilancia altre AuthApiException che potrebbero indicare problemi diversi
          logError("AuthApiException imprevista durante la validazione iniziale: ${e.message}", e);
          await Supabase.instance.client.auth.signOut(); // Logout per sicurezza in caso di altri errori di autenticazione
          authController.setIsLoggedIn(false);
        }
      } catch (e, s) {
        // Cattura qualsiasi altro errore imprevisto durante la gestione iniziale della sessione
        logError("Errore imprevisto durante la gestione iniziale della sessione: $e", e, s);
        await Supabase.instance.client.auth.signOut(); // Forza il logout
        authController.setIsLoggedIn(false);
      }

      // Ora che lo stato iniziale di autenticazione è stato gestito,
      // inizializziamo gli altri controller.
      Get.put(PersonaleController(), permanent: true);
      Get.put(EsterniController(), permanent: true);
      Get.put(ProfileController(), permanent: true);
      logInfo("[Main] Tutti i controller sono stati inizializzati.");

      logInfo("Avvio dell'interfaccia utente (MyApp)...");
      runApp(const MyApp());
    },
    // --- GESTORE GLOBALE DEGLO ERRORI ---
    (error, stack) {
      // Questo gestore globale cattura tutti gli errori non gestiti nella zona.
      // Per AuthApiException, assicuriamo un logout e lo logghiamo come info (poiché è "gestito" reindirizzando al login).
      if (error is AuthApiException) {
        logInfo("AuthApiException catturata a livello globale: ${error.message}. Tentativo di logout.");
        // Assicurati che signOut sia chiamato. Questo si propagherà a AuthController tramite il suo listener.
        // È importante non awaitare qui per non bloccare il gestore di errori.
        Supabase.instance.client.auth.signOut();
      } else {
        // Per tutti gli altri errori inaspettati, loggali come critici.
        logError("ERRORE NON GESTITO A LIVELLO GLOBALE:", error, stack);
      }
    },
  );
}

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
