// lib/app_router.dart
// ignore_for_file: avoid_print

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:una_chat/screens/una_chat_main_screen.dart';
import 'package:una_social/controllers/auth_controller.dart'; // <-- IMPORTA IL CONTROLLER AGGIORNATO
import 'package:una_social/helpers/logger_helper.dart'; // Assicurati che esista
import 'package:una_social/screens/database/ambiti.dart';
import 'package:una_social/screens/database/campus.dart';
import 'package:una_social/screens/database/docenti_inesistenti.dart';
import 'package:una_social/screens/database/personale.dart';
import 'package:una_social/screens/database_screen.dart';
import 'package:una_social/screens/home_screen.dart';
import 'package:una_social/screens/login_screen.dart';
import 'package:una_social/screens/set_password_screen.dart';
import 'package:una_social/screens/splash_screen.dart';
import 'package:una_social/screens/strutture_screen.dart';

final _supabase = Supabase.instance.client;
final AuthController authController = Get.put(AuthController());

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
  static final List<GoRoute> publicRoutes = [
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
      name: 'set-password',
      builder: (context, state) => const SetPasswordScreen(),
    ),
  ];
  static final List<GoRoute> superAdminRoutes = [
    GoRoute(
      path: 'database', // Path completo: /app/database
      name: 'database',
      builder: (context, state) => const HomeScreen(
        screenName: 'Database',
        child: DatabaseScreen(),
      ),
      redirect: (context, state) async {
        if (!await authController.checkIsSuperAdmin()) {
          logInfo('[GoRouter /app/database Redirect] Utente non Super Admin. Redirect a /unauthorized.');
          const String errorMessage = 'Accesso negato. Sono richiesti privilegi di Super Amministratore.';
          final String encodedMessage = Uri.encodeComponent(errorMessage);
          return '/unauthorized?message=$encodedMessage';
        }
        logInfo('[GoRouter /app/database Redirect] Utente Super Admin. Accesso consentito.');
        return null;
      },
    ),
    GoRoute(
      path: 'ambiti', // Path completo: /app/ambiti
      name: 'ambiti',
      builder: (context, state) => const HomeScreen(
        screenName: 'Ambiti',
        child: AmbitiScreen(),
      ),
      redirect: (context, state) async {
        if (!await authController.checkIsSuperAdmin()) {
          logInfo('[GoRouter /app/ambiti Redirect] Utente non Super Admin. Redirect a /unauthorized.');
          const String errorMessage = 'Accesso negato. Sono richiesti privilegi di Super Amministratore.';
          final String encodedMessage = Uri.encodeComponent(errorMessage);
          return '/unauthorized?message=$encodedMessage';
        }
        logInfo('[GoRouter /app/ambiti Redirect] Utente Super Admin. Accesso consentito.');
        return null;
      },
    ),
    GoRoute(
      path: 'campus', // Path completo: /app/ambiti
      name: 'campus',
      builder: (context, state) => const HomeScreen(
        screenName: 'Campus',
        child: CampusScreen(),
      ),
      redirect: (context, state) async {
        if (!await authController.checkIsSuperAdmin()) {
          logInfo('[GoRouter /app/campus Redirect] Utente non Super Admin. Redirect a /unauthorized.');
          const String errorMessage = 'Accesso negato. Sono richiesti privilegi di Super Amministratore.';
          final String encodedMessage = Uri.encodeComponent(errorMessage);
          return '/unauthorized?message=$encodedMessage';
        }
        logInfo('[GoRouter /app/campus Redirect] Utente Super Admin. Accesso consentito.');
        return null;
      },
    ),
    GoRoute(
      path: 'docenti_inesistenti', // Path completo: /app/ambiti
      name: 'docenti_inesistenti',
      builder: (context, state) => const HomeScreen(
        screenName: 'Docenti inesistenti',
        child: DocentiInesistentiScreen(),
      ),
      redirect: (context, state) async {
        if (!await authController.checkIsSuperAdmin()) {
          logInfo('[GoRouter /app/docenti_inesistenti Redirect] Utente non Super Admin. Redirect a /unauthorized.');
          const String errorMessage = 'Accesso negato. Sono richiesti privilegi di Super Amministratore.';
          final String encodedMessage = Uri.encodeComponent(errorMessage);
          return '/unauthorized?message=$encodedMessage';
        }
        logInfo('[GoRouter /app/docenti_inesistenti Redirect] Utente Super Admin. Accesso consentito.');
        return null;
      },
    ),
    GoRoute(
      path: 'personale', // Path completo: /app/ambiti
      name: 'personale',
      builder: (context, state) => const HomeScreen(
        screenName: 'Personale',
        child: PersonaleScreen(),
      ),
      redirect: (context, state) async {
        if (!await authController.checkIsSuperAdmin()) {
          logInfo('[GoRouter /app/personale Redirect] Utente non Super Admin. Redirect a /unauthorized.');
          const String errorMessage = 'Accesso negato. Sono richiesti privilegi di Super Amministratore.';
          final String encodedMessage = Uri.encodeComponent(errorMessage);
          return '/unauthorized?message=$encodedMessage';
        }
        logInfo('[GoRouter /app/personale Redirect] Utente Super Admin. Accesso consentito.');
        return null;
      },
    ),
  ];

  static final router = GoRouter(
    initialLocation: '/splash',
    refreshListenable: GoRouterRefreshStream(_supabase.auth.onAuthStateChange),
    routes: [
      // ...public routes...
      ...publicRoutes,
      GoRoute(
        path: '/app',
        redirect: (context, state) {
          final user = _supabase.auth.currentUser;
          if (user == null) {
            logInfo('[GoRouter /app Redirect] Utente nullo. Redirect a /login.');
            return '/login';
          }
          if (user.userMetadata?['has_set_password'] != true) {
            logInfo('[GoRouter /app Redirect] Password non impostata. Redirect a /set-password.');
            return '/set-password';
          }
          logInfo('[GoRouter /app Redirect] Utente autenticato e password impostata. Accesso a /app consentito.');
          return null;
        },
        routes: [
          GoRoute(
            path: 'home',
            name: 'home',
            builder: (context, state) => const HomeScreen(
              screenName: 'Home',
              child: Center(child: Text('Contenuto principale della Home')),
            ),
          ),
          ...superAdminRoutes, // <-- Qui vengono aggiunte tutte le route Super Admin
          GoRoute(
            path: 'strutture',
            name: 'strutture',
            builder: (context, state) => HomeScreen(
              screenName: 'Gestione Strutture',
              child: StruttureScreen(),
            ),
          ),
          GoRoute(
            path: 'chat',
            builder: (context, state) => HomeScreen(
              screenName: 'Chat',
              child: UnaChatMainScreen(),
            ),
          ),
          // ...altre route protette...
        ],
      ),
    ],
    // ...redirect globale ed errorBuilder invariati...
    redirect: (BuildContext context, GoRouterState state) {
      final user = _supabase.auth.currentUser;
      final bool loggedIn = user != null;

      // NOTA: Controlla se 'has_set_password' esiste davvero nei tuoi metadati.
      // Se non esiste, questo sarà sempre 'false'.
      final bool passwordSet = user?.userMetadata?['has_set_password'] as bool? ?? false;

      final String location = state.matchedLocation;
      logInfo('[GoRouter] Evaluating: Path="$location", LoggedIn=$loggedIn, PasswordSet=$passwordSet');

      // --- PRIORITÀ 1: L'utente è loggato ma non ha impostato la password ---
      // Questo è il caso più importante da gestire.
      if (loggedIn && !passwordSet) {
        // Se non si trova GIÀ sulla pagina per impostare la password, ce lo mandiamo.
        if (location != '/set-password') {
          logInfo('[GoRouter] Redirect: Logged in but password not set. Forcing -> /set-password');
          return '/set-password';
        }
        // Se è già lì, non facciamo nulla per evitare loop di redirect.
        return null;
      }

      // --- PRIORITÀ 2: L'utente è completamente autenticato e configurato ---
      if (loggedIn && passwordSet) {
        // Se per qualche motivo finisce su una pagina di setup/pubblica, lo mandiamo alla home.
        final bool onSetupOrPublicPath = location == '/splash' || location == '/login' || location == '/set-password' || location == '/';
        if (onSetupOrPublicPath) {
          logInfo('[GoRouter] Redirect: Fully authenticated user on a public/setup page. Forcing -> /app/home');
          return '/app/home';
        }
      }

      // --- PRIORITÀ 3: L'utente non è loggato ---
      if (!loggedIn) {
        final bool isPublicPath = ['/splash', '/login', '/set-password', '/unauthorized'].contains(location) || location == '/';
        // Se cerca di accedere a una pagina protetta, lo mandiamo al login.
        if (!isPublicPath) {
          logInfo('[GoRouter] Redirect: Not logged in and accessing a protected page. Forcing -> /login');
          return '/login';
        }
      }

      // Se nessuna delle regole precedenti ha attivato un redirect, la navigazione è permessa.
      logInfo('[GoRouter] No redirect needed for this route.');
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
