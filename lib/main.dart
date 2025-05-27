// lib/main.dart
// ignore_for_file: avoid_print, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:una_social_app/app_router.dart';
import 'package:una_social_app/helpers/auth_helper.dart'; // Importa l'helper

// --- ValueNotifier Globale per lo stato di autenticazione dell'app ---
final ValueNotifier<AuthStatus> appAuthStatusNotifier = ValueNotifier(AuthStatus.loading);

enum AuthStatus { loading, authenticated, unauthenticated }
// --- FINE ValueNotifier ---

const String supabaseUrlEnvKey = 'SUPABASE_URL';
const String supabaseAnonKeyEnvKey = 'SUPABASE_ANON_KEY';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  setUrlStrategy(PathUrlStrategy());
  ////print("URL Strategy impostata su Path.");

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
    //print(errorMessage);
    runApp(SupabaseErrorApp(error: errorMessage));
    return;
  }

  ////print("Supabase URL (da --dart-define): $supabaseUrl");

  try {
    //print("Inizializzazione Supabase...");
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
      debug: true,
    );
    //print("Supabase inizializzato.");

    //print("Impostazione listener onAuthStateChange...");
    Supabase.instance.client.auth.onAuthStateChange.listen(
      (data) {
        final AuthChangeEvent event = data.event;
        final Session? session = data.session;
        //print('[MAIN AUTH LISTENER] Evento Ricevuto: $event, Sessione: ${session != null ? "Presente (User ID: ${session.user.id})" : "Assente"}');

        // Se l'evento NON è signedOut, e la ragione era invalidRefreshToken,
        // la "crisi" è passata (es. l'utente si è riloggato), quindi resettiamo.
        // Questo evita che un vecchio messaggio di "sessione scaduta" appaia dopo un login successivo.
        if (event != AuthChangeEvent.signedOut && AuthHelper.lastLogoutReason == LogoutReason.invalidRefreshToken) {
          AuthHelper.clearLastLogoutReason();
        }

        switch (event) {
          case AuthChangeEvent.initialSession:
            if (session != null && !session.isExpired) {
              //print('[MAIN AUTH LISTENER] initialSession: Utente valido. Notifier -> authenticated.');
              appAuthStatusNotifier.value = AuthStatus.authenticated;
            } else {
              //print('[MAIN AUTH LISTENER] initialSession: Nessun utente valido. Notifier -> unauthenticated.');
              // Se la sessione iniziale non è valida e la ragione era già invalidRefreshToken (da un errore precedente),
              // non la sovrascriviamo con 'none', lasciamo che la LoginScreen la gestisca.
              if (AuthHelper.lastLogoutReason != LogoutReason.invalidRefreshToken) {
                AuthHelper.clearLastLogoutReason(); // Pulisce ragioni precedenti se non è un invalid refresh
              }
              appAuthStatusNotifier.value = AuthStatus.unauthenticated;
            }
            break;
          case AuthChangeEvent.signedIn:
          case AuthChangeEvent.tokenRefreshed:
          case AuthChangeEvent.mfaChallengeVerified:
          case AuthChangeEvent.userUpdated:
            if (appAuthStatusNotifier.value != AuthStatus.authenticated) {
              //print('[MAIN AUTH LISTENER] Evento $event: Stato Loggato. Notifier -> authenticated.');
              appAuthStatusNotifier.value = AuthStatus.authenticated;
            }
            // Se l'utente si logga con successo, qualsiasi ragione di logout precedente è irrilevante
            AuthHelper.clearLastLogoutReason();
            break;
          case AuthChangeEvent.signedOut:
          case AuthChangeEvent.userDeleted:
            if (appAuthStatusNotifier.value != AuthStatus.unauthenticated) {
              //print('[MAIN AUTH LISTENER] Evento $event: Stato Sloggato. Notifier -> unauthenticated.');
              appAuthStatusNotifier.value = AuthStatus.unauthenticated;
            }
            // NON pulire la ragione qui, potrebbe essere stata impostata dall'onError.
            // Se AuthHelper.lastLogoutReason è ancora LogoutReason.none,
            // significa che il logout è stato probabilmente avviato altrove (es. user-initiated o scadenza token non gestita da onError qui).
            // Se l'utente si è disconnesso esplicitamente, la HomeScreen dovrebbe aver impostato UserInitiated.
            break;
          case AuthChangeEvent.passwordRecovery:
            //print('[MAIN AUTH LISTENER] Gestito evento passwordRecovery. Stato auth non modificato.');
            break;
        }
      },
      onError: (error) {
        //print('[MAIN AUTH LISTENER] Errore nello stream onAuthStateChange: $error');
        if (error is AuthException && (error.statusCode == '400' || error.message.toLowerCase().contains('invalid refresh token'))) {
          //print('[MAIN AUTH LISTENER] Causa logout specifica: Invalid Refresh Token.');
          AuthHelper.setLogoutReason(LogoutReason.invalidRefreshToken);
        }
        // Altrimenti, non impostiamo una ragione specifica qui, ma trattiamo l'errore come un potenziale logout
        if (appAuthStatusNotifier.value != AuthStatus.unauthenticated) {
          //print('[MAIN AUTH LISTENER] Errore stream: Notifier -> unauthenticated.');
          appAuthStatusNotifier.value = AuthStatus.unauthenticated;
        }
      },
    );
    //print("Listener onAuthStateChange impostato.");
  } catch (e) {
    //print("ERRORE CRITICO init Supabase: $e");
    //print("Stack trace: $stackTrace");
    appAuthStatusNotifier.value = AuthStatus.unauthenticated;
    runApp(SupabaseErrorApp(error: "Errore inizializzazione Supabase: ${e.toString()}"));
    return;
  }

  //print("Avvio MyApp...");
  runApp(const MyApp());
}

// ... resto di main.dart invariato (MyApp, SupabaseErrorApp) ...
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
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
      routerConfig: AppRouter.router,
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
