// lib/app_router.dart
// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

import 'package:una_social_app/screens/home_screen.dart';
import 'package:una_social_app/screens/login_screen.dart';
import 'package:una_social_app/screens/set_password_screen.dart';
import 'package:una_social_app/screens/splash_screen.dart';
import 'package:una_social_app/screens/database_screen.dart';
import 'package:una_social_app/screens/unauthorized_screen.dart'; // *** Importa una schermata per accesso negato ***

// Helper SINCRONO per verificare se l'utente è SUPER_ADMIN basandosi sui custom claims
bool _isUserSuperAdminSync(User? user) {
  if (user == null) {
    // print("Router Check (Sync): Utente nullo, non è Super Admin.");
    return false;
  }

  // Adatta questo percorso al tuo setup di custom claims effettivo.
  // Esempio: user.appMetadata['groups']
  // Potrebbe anche essere user.userMetadata['groups'] o un claim custom.
  final dynamic groupsClaim = user.appMetadata['groups'];

  if (groupsClaim == null) {
    // print("Router Check (Sync): Claim 'groups' nullo in appMetadata per ${user.email}.");
    return false;
  }

  if (groupsClaim is List) {
    try {
      // Assicura che gli elementi siano stringhe
      final List<String> userGroups = List<String>.from(groupsClaim.map((item) => item.toString()));
      // Controlla se il gruppo 'SUPER-ADMIN' è presente (case-sensitive)
      final bool isAdmin = userGroups.contains('SUPER_ADMIN'); // CAMBIA 'SUPER-ADMIN' SE IL TUO GRUPPO HA UN NOME DIVERSO
      // print("Router Check (Sync): Utente ${user.email}, Gruppi (da claim): $userGroups, È Super Admin: $isAdmin");
      return isAdmin;
    } catch (e) {
      print("Router Check (Sync): Errore durante la conversione dei gruppi da claim per ${user.email}: $e");
      return false;
    }
  } else {
    // print("Router Check (Sync): Claim 'groups' per ${user.email} non è una lista, tipo: ${groupsClaim.runtimeType}");
    return false;
  }
}

class GoRouterRefreshStream extends ChangeNotifier {
  // ... (codice GoRouterRefreshStream invariato) ...
  late final StreamSubscription<AuthState> _subscription;
  bool _isDisposed = false;

  GoRouterRefreshStream(Stream<AuthState> stream) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isDisposed) notifyListeners();
    });

    _subscription = stream.asBroadcastStream().listen((AuthState data) {
      print("[GoRouterRefreshStream] Auth state changed: ${data.event}");
      if (!_isDisposed) {
        notifyListeners();
      }
    }, onError: (error) {
      print("[GoRouterRefreshStream] Error in auth stream: $error");
      if (!_isDisposed) {
        notifyListeners();
      }
    });
    print("[GoRouterRefreshStream] Listener auth state creato.");
  }

  @override
  void dispose() {
    if (!_isDisposed) {
      print("[GoRouterRefreshStream] Disposing listener auth state.");
      _isDisposed = true;
      _subscription.cancel();
      super.dispose();
    }
  }
}

class AppRouter {
  static final router = GoRouter(
    initialLocation: '/',
    refreshListenable: GoRouterRefreshStream(Supabase.instance.client.auth.onAuthStateChange),
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
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
        path: '/home',
        name: 'home',
        builder: (context, state) => const HomeScreen(
          screenName: 'Home',
          child: Center(child: Text('Contenuto principale Home')),
        ),
        redirect: (context, state) {
          final user = Supabase.instance.client.auth.currentUser;
          final passwordSet = user?.userMetadata?['has_set_password'] == true;
          if (user != null && !passwordSet) {
            return '/set-password';
          }
          return null;
        },
      ),
      GoRoute(
        path: '/set-password',
        name: 'setPassword',
        builder: (context, state) => const SetPasswordScreen(),
      ),
      GoRoute(
        path: '/database',
        name: 'database',
        builder: (context, state) => const HomeScreen(
          screenName: 'Database',
          child: DatabaseScreen(),
        ),
        // *** REDIRECT SPECIFICO PER /database PER CONTROLLO RUOLO ***
        redirect: (context, state) {
          final user = Supabase.instance.client.auth.currentUser;
          final bool loggedIn = user != null;
          final bool passwordSet = user?.userMetadata?['has_set_password'] == true;

          // 1. Prima controlla se è loggato e password impostata (come prima)
          if (!loggedIn) {
            print('[GoRouter Redirect /database] Not logged in. Redirecting to /login.');
            return '/login'; // Reindirizza a login se non loggato
          }
          if (!passwordSet) {
            print('[GoRouter Redirect /database] Logged in, password not set. Redirecting to /set-password.');
            return '/set-password'; // Reindirizza se la password non è impostata
          }

          // 2. Se loggato e password impostata, controlla il ruolo
          if (!_isUserSuperAdminSync(user)) {
            print('[GoRouter Redirect /database] User is not admin. Redirecting to /unauthorized.');
            return '/unauthorized';
          }
          // Se tutti i controlli passano, permette l'accesso
          return null;
        },
      ),
      // *** AGGIUNTA ROUTE PER ACCESSO NEGATO ***
      GoRoute(
        path: '/unauthorized',
        name: 'unauthorized',
        builder: (context, state) => const UnauthorizedScreen(),
      ),
    ],
    // --- LOGICA DI REDIRECT GLOBALE ---
    // Il redirect globale ora si concentra sull'autenticazione generale e sul flusso di impostazione password.
    // I controlli di ruolo specifici sono gestiti nei redirect delle singole route.
    redirect: (BuildContext context, GoRouterState state) {
      final supabaseClient = Supabase.instance.client;
      final user = supabaseClient.auth.currentUser;
      final session = supabaseClient.auth.currentSession;
      final bool loggedIn = session != null;
      final bool passwordSet = user?.userMetadata?['has_set_password'] == true;
      final String currentMatchedLocation = state.matchedLocation;

      print('[GoRouter Global Redirect] Path: $currentMatchedLocation, LoggedIn: $loggedIn, PwdSet: $passwordSet, isAdmin: ${_isUserSuperAdminSync(user)}');

      final isPublicRoute = (currentMatchedLocation == '/login' || currentMatchedLocation == '/splash' || currentMatchedLocation == '/' || currentMatchedLocation == '/unauthorized'); // Anche unauthorized è pubblica

      // CASO 1: Utente Loggato
      if (loggedIn) {
        // 1a: Loggato, ma password non impostata
        if (!passwordSet && currentMatchedLocation != '/set-password') {
          print('[GoRouter Global Redirect] Logged in, password required. Redirecting to /set-password.');
          return '/set-password';
        }
        // 1b: Loggato, password impostata, ma su /login, /splash, o /set-password (non dovrebbe essere lì)
        if (passwordSet && (currentMatchedLocation == '/login' || currentMatchedLocation == '/splash' || currentMatchedLocation == '/set-password' || currentMatchedLocation == '/')) {
          // Eccezione: se sta andando a /database E NON è admin, il redirect di /database lo manderà a /unauthorized.
          // Non vogliamo che questo redirect globale lo mandi di nuovo a /home.
          if (currentMatchedLocation == '/database' && !_isUserSuperAdminSync(user)) {
            return null; // Lascia che il redirect di /database gestisca
          }
          print('[GoRouter Global Redirect] Logged in & PwdSet. Redirecting from $currentMatchedLocation to /home.');
          return '/home';
        }
        // Per la rotta /database, il suo redirect specifico ha già gestito il ruolo.
        // Se l'utente è admin e va a /database, il redirect di /database ritorna null,
        // quindi questo redirect globale non dovrebbe interferire.
        // Se l'utente NON è admin e va a /database, il redirect di /database lo manda a /unauthorized.
        // Questo redirect globale non dovrebbe rimandarlo a /home se è su /unauthorized.

        print('[GoRouter Global Redirect] Logged in. Allowing navigation to $currentMatchedLocation.');
        return null;
      }
      // CASO 2: Utente NON Loggato
      else {
        if (!isPublicRoute) {
          print('[GoRouter Global Redirect] Not logged in. Redirecting to /login from protected route $currentMatchedLocation.');
          return '/login';
        }
        print('[GoRouter Global Redirect] Not logged in. Allowing navigation to public route $currentMatchedLocation.');
        return null;
      }
    },
    errorBuilder: (context, state) {
      // ... (errorBuilder invariato) ...
      print('[GoRouter Error] Path: ${state.uri}, Error: ${state.error}');
      return Scaffold(
        appBar: AppBar(title: const Text('Errore Navigazione')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Pagina non trovata o errore del router.\n\nURI Richiesto: ${state.uri}\nErrore: ${state.error}',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    },
  );
}
