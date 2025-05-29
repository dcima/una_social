// lib/app_router.dart
// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:una_chat/screens/una_chat_main_screen.dart';
import 'package:una_social/helpers/logger_helper.dart'; // Assicurati che esista
import 'dart:async';

// Importa le tue schermate
import 'package:una_social/screens/home_screen.dart';
import 'package:una_social/screens/login_screen.dart';
import 'package:una_social/screens/set_password_screen.dart';
import 'package:una_social/screens/splash_screen.dart';
import 'package:una_social/screens/database_screen.dart';
import 'package:una_social/screens/strutture_screen.dart';
import 'package:una_social/screens/unauthorized_screen.dart';

final _supabase = Supabase.instance.client;

// Helper ASINCRONO per verificare se l'utente è SUPER-ADMIN (invariato)
Future<bool> checkCurrentUserIsSuperAdmin() async {
  if (_supabase.auth.currentUser == null) {
    logError("[AppRouter] checkCurrentUserIsSuperAdmin: Utente nullo, non può essere Super Admin.");
    return false;
  }
  try {
    const String superAdminGroupName = 'SUPER-ADMIN';
    logInfo("[AppRouter] checkCurrentUserIsSuperAdmin: Chiamata RPC 'current_user_is_in_group' con parametro '$superAdminGroupName'");
    final dynamic response = await _supabase.rpc(
      'current_user_is_in_group',
      params: {'group_name_param': superAdminGroupName},
    );
    if (response is bool) {
      final bool isAdmin = response;
      logInfo("[AppRouter] checkCurrentUserIsSuperAdmin: Risultato RPC (boolean): $isAdmin");
      return isAdmin;
    } else {
      logError("[AppRouter] checkCurrentUserIsSuperAdmin: Risposta RPC non è booleana, tipo: ${response.runtimeType}, Data: $response. Considerato non admin.");
      return false;
    }
  } catch (e) {
    logInfo("[AppRouter] checkCurrentUserIsSuperAdmin: Errore durante chiamata RPC: $e");
    return false;
  }
}

// GoRouterRefreshStream (invariato)
class GoRouterRefreshStream extends ChangeNotifier {
  late final StreamSubscription<AuthState> _subscription;
  bool _isDisposed = false;

  GoRouterRefreshStream(Stream<AuthState> stream) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isDisposed) notifyListeners();
    });
    _subscription = stream.asBroadcastStream().listen((AuthState data) {
      if (!_isDisposed) notifyListeners();
    }, onError: (error) {
      if (!_isDisposed) notifyListeners();
    });
  }
  @override
  void dispose() {
    if (!_isDisposed) {
      _isDisposed = true;
      _subscription.cancel();
      super.dispose();
    }
  }
}

class AppRouter {
  static final router = GoRouter(
    initialLocation: '/splash', // Inizia sempre da splash per i controlli iniziali
    refreshListenable: GoRouterRefreshStream(_supabase.auth.onAuthStateChange),
    routes: [
      // --- ROUTE PUBBLICHE E DI AUTENTICAZIONE (PRIMO LIVELLO) ---
      GoRoute(
        path: '/', // Solitamente reindirizza a /splash o /home
        name: 'root',
        builder: (context, state) => const SplashScreen(), // O una landing page
      ),
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/set-password',
        name: 'setPassword',
        builder: (context, state) => const SetPasswordScreen(),
      ),
      GoRoute(
        path: '/unauthorized',
        name: 'unauthorized',
        builder: (context, state) => const UnauthorizedScreen(),
      ),

      // --- GRUPPO DI ROUTE PROTETTE (/app/*) ---
      GoRoute(
        path: '/app', // Prefisso per tutte le route protette
        redirect: (context, state) {
          final user = _supabase.auth.currentUser;
          // Il redirect globale dovrebbe già aver gestito la maggior parte di questo,
          // ma è una buona seconda linea di difesa.
          if (user == null) {
            logInfo('[GoRouter /app Redirect] Utente nullo. Redirect a /login.');
            return '/login';
          }
          if (user.userMetadata?['has_set_password'] != true) {
            logInfo('[GoRouter /app Redirect] Password non impostata. Redirect a /set-password.');
            return '/set-password';
          }
          logInfo('[GoRouter /app Redirect] Utente autenticato e password impostata. Accesso a /app consentito.');
          return null; // Permetti l'accesso al gruppo /app e alle sue figlie
        },
        routes: [
          // Route figlia di default per /app (se si naviga a /app senza un sottomodulo)
          // Potrebbe reindirizzare a /app/home o mostrare un dashboard principale.
          // Per ora, la rendiamo uguale a /app/home.
          GoRoute(
            path: 'home', // Path completo: /app/home
            name: 'home', // Nome univoco per la route
            builder: (context, state) => const HomeScreen(
              screenName: 'Home', // Nome visualizzato nell'AppBar di HomeScreen
              child: Center(child: Text('Contenuto principale della Home')), // Widget contenuto
            ),
            // Non c'è più bisogno del redirect specifico per auth/pwd qui,
            // è gestito dal genitore '/app' e dal redirect globale.
          ),
          GoRoute(
            path: 'database', // Path completo: /app/database
            name: 'database',
            builder: (context, state) => const HomeScreen(
              screenName: 'Database',
              child: DatabaseScreen(), // DatabaseScreen è solo il contenuto
            ),
            redirect: (context, state) async {
              // Questo redirect si attiva DOPO quello del genitore '/app'
              // e dopo il redirect globale. Qui solo logica specifica per /app/database.
              if (!await checkCurrentUserIsSuperAdmin()) {
                logInfo('[GoRouter /app/database Redirect] Utente non Super Admin. Redirect a /unauthorized.');
                return '/unauthorized'; // /unauthorized è una route di primo livello
              }
              logInfo('[GoRouter /app/database Redirect] Utente Super Admin. Accesso consentito.');
              return null;
            },
          ),
          GoRoute(
            path: 'strutture', // Path completo: /app/strutture
            name: 'strutture',
            builder: (context, state) => HomeScreen(
              screenName: 'Gestione Strutture',
              child: StruttureScreen(),
            ),
            // Esempio: redirect specifico se necessario per /app/strutture
            // redirect: (context, state) async {
            //   if (!await altraVerificaSpecifica()) return '/unauthorized';
            //   return null;
            // },
          ),
          GoRoute(
            path: 'una_chat', // Path completo: /app/una_chat
            builder: (context, state) => HomeScreen(
              screenName: 'Una Chat',
              //IMPORTANTE: UnaChatMainScreen qui deve essere il WIDGET DI CONTENUTO,
              //non uno Scaffold completo, perché HomeScreen fornisce già lo Scaffold.
              //Se UnaChatMainScreen che hai creato ha il suo Scaffold, AppBar, BottomNav,
              //dovrai estrarre solo la parte del body per usarla qui.
              child: UnaChatMainScreen(), // Adatta se necessario
            ),
          ),
          // Aggiungi qui le altre tue route protette seguendo lo stesso pattern:
          // GoRoute(
          //   path: 'una_tube', // Path completo: /app/una_tube
          //   name: 'una_tube',
          //   builder: (context, state) => HomeScreen(
          //     screenName: 'Una Tube',
          //     child: UnaTubeContentWidget(), // Sostituisci con il widget di contenuto reale
          //   ),
          // ),
          // GoRoute(
          //   path: 'una_tok', // Path completo: /app/una_tok
          //   name: 'una_tok',
          //   builder: (context, state) => HomeScreen(
          //     screenName: 'Una Tok',
          //     child: UnaTokContentWidget(), // Sostituisci con il widget di contenuto reale
          //   ),
          // ),
        ],
      ),
    ],
    // --- LOGICA DI REDIRECT GLOBALE (SINCRONA) ---
    redirect: (BuildContext context, GoRouterState state) {
      final user = _supabase.auth.currentUser;
      final session = _supabase.auth.currentSession;
      final bool loggedIn = session != null;
      final bool passwordSet = user?.userMetadata?['has_set_password'] == true;

      final String currentMatchedLocation = state.matchedLocation; // Es. '/', '/login', '/app/home'
      final String requestedUri = state.uri.toString(); // L'URI completo, es. /app/home?param=1

      logInfo('[GoRouter Global Redirect] Matched: $currentMatchedLocation, URI: $requestedUri, LoggedIn: $loggedIn, PwdSet: $passwordSet');

      // Definisci i percorsi che non richiedono autenticazione
      final List<String> publicPaths = ['/splash', '/login', '/set-password', '/unauthorized'];
      // La root '/' è speciale, la gestiamo come /splash
      final bool onPublicPath = publicPaths.contains(currentMatchedLocation) || currentMatchedLocation == '/';
      final bool onSetPasswordPath = currentMatchedLocation == '/set-password';

      if (!loggedIn) {
        // UTENTE NON LOGGATO
        if (!onPublicPath) {
          logInfo('[GoRouter Global Redirect] NOT LoggedIn, NOT on public path. Redirect to /login.');
          return '/login'; // Se non è loggato e non sta andando a una pagina pubblica, mandalo al login.
        }
      } else {
        // UTENTE LOGGATO
        if (!passwordSet && !onSetPasswordPath) {
          logInfo('[GoRouter Global Redirect] LoggedIn, Password NOT set, NOT on /set-password. Redirect to /set-password.');
          return '/set-password'; // Se è loggato ma la password non è settata, e non sta andando a /set-password, forzalo lì.
        }
        // Se è loggato, la password è settata, e sta tentando di accedere a /, /splash, /login, o /set-password
        if (passwordSet && (currentMatchedLocation == '/' || currentMatchedLocation == '/splash' || currentMatchedLocation == '/login' || onSetPasswordPath)) {
          logInfo('[GoRouter Global Redirect] LoggedIn, Password SET, on public/setup path. Redirect to /app/home.');
          return '/app/home'; // Mandalo alla home page dell'applicazione.
        }
      }

      // Se nessuna delle condizioni sopra è soddisfatta, non fare nulla, lascia che la navigazione proceda.
      // I redirect specifici delle route (es. per /app/database o il redirect di /app) faranno il loro lavoro.
      logInfo('[GoRouter Global Redirect] No global redirect action needed for this route.');
      return null;
    },
    errorBuilder: (context, state) {
      logError('[GoRouter ErrorBuilder] URI: ${state.uri}, Errore: ${state.error}');
      return Scaffold(
        appBar: AppBar(title: const Text('Errore Navigazione')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Pagina non trovata o errore del router.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Text('Percorso Richiesto: ${state.uri}', textAlign: TextAlign.center),
                if (state.error != null) ...[
                  const SizedBox(height: 8),
                  Text('Dettagli Errore: ${state.error}', textAlign: TextAlign.center),
                ]
              ],
            ),
          ),
        ),
      );
    },
  );
}
