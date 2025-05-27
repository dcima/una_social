// lib/app_router.dart
// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:una_social_app/helpers/logger_helper.dart';
import 'dart:async';

import 'package:una_social_app/screens/home_screen.dart';
import 'package:una_social_app/screens/login_screen.dart';
import 'package:una_social_app/screens/set_password_screen.dart';
import 'package:una_social_app/screens/splash_screen.dart';
import 'package:una_social_app/screens/database_screen.dart';
import 'package:una_social_app/screens/strutture_screen.dart';
import 'package:una_social_app/screens/unauthorized_screen.dart';

final _supabase = Supabase.instance.client;

// Helper ASINCRONO per verificare se l'utente è SUPER-ADMIN
// Ora chiama direttamente la tua funzione RPC 'current_user_is_in_group'
Future<bool> checkCurrentUserIsSuperAdmin() async {
  // Non ha più bisogno del parametro User
  // L'utente deve essere loggato per chiamare una funzione che usa auth.uid()
  if (_supabase.auth.currentUser == null) {
    logError("[AppRouter] checkCurrentUserIsSuperAdmin: Utente nullo, non può essere Super Admin.");
    return false;
  }

  try {
    const String superAdminGroupName = 'SUPER-ADMIN'; // Definisci il nome del gruppo una volta
    logInfo("[AppRouter] checkCurrentUserIsSuperAdmin: Chiamata RPC 'current_user_is_in_group' con parametro '$superAdminGroupName'");

    final dynamic response = await _supabase.rpc(
      'current_user_is_in_group',
      params: {'group_name_param': superAdminGroupName},
    );

    // La tua funzione SQL 'current_user_is_in_group' restituisce un booleano.
    // Il client Supabase Dart per RPC lo restituirà direttamente come bool.
    if (response is bool) {
      final bool isAdmin = response;
      logInfo("[AppRouter] checkCurrentUserIsSuperAdmin: Risultato RPC (boolean): $isAdmin");
      return isAdmin;
    } else {
      logError("[AppRouter] checkCurrentUserIsSuperAdmin: Risposta RPC non è booleana, tipo: ${response.runtimeType}, Data: $response. Considerato non admin.");
      return false; // In caso di risposta inattesa, assumi non admin per sicurezza
    }
  } catch (e) {
    logInfo("[AppRouter] checkCurrentUserIsSuperAdmin: Errore durante chiamata RPC: $e");
    return false; // In caso di errore, assumi non admin
  }
}

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
    initialLocation: '/',
    refreshListenable: GoRouterRefreshStream(_supabase.auth.onAuthStateChange),
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
          final user = _supabase.auth.currentUser;
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
        redirect: (context, state) async {
          final user = _supabase.auth.currentUser; // Utile per i controlli iniziali
          final bool loggedIn = user != null;
          final bool passwordSet = user?.userMetadata?['has_set_password'] == true;

          if (!loggedIn) {
            return '/login';
          }
          if (!passwordSet) {
            return '/set-password';
          }

          // Chiama la funzione async per verificare il ruolo
          if (!await checkCurrentUserIsSuperAdmin()) {
            // Non serve più passare 'user'
            logInfo('[GoRouter Redirect /database] L\'utente non è Super Admin (da RPC current_user_is_in_group). Redirect a /unauthorized.');
            return '/unauthorized';
          }
          logInfo('[GoRouter Redirect /database] L_utente è Super Admin (da RPC current_user_is_in_group). Accesso consentito.');
          return null;
        },
      ),
      GoRoute(
        path: '/strutture', // Definisci il percorso
        name: 'strutture', // Nome opzionale per la rotta
        builder: (context, state) => HomeScreen(
          screenName: 'Gestione Strutture', // Nome da mostrare nell'app bar
          child: StruttureScreen(), // Il contenuto principale è la tua nuova schermata
        ),
        redirect: (context, state) async {
          final user = _supabase.auth.currentUser;
          if (user == null) return '/login';
          if (user.userMetadata?['has_set_password'] != true) return '/set-password';

          // Esempio: solo SUPER-ADMIN può vedere le strutture
          // if (!await checkCurrentUserIsSuperAdmin()) {
          //   return '/unauthorized';
          // }
          return null; // Permetti accesso se i controlli passano
        },
      ),
      GoRoute(
        path: '/unauthorized',
        name: 'unauthorized',
        builder: (context, state) => const UnauthorizedScreen(),
      ),
    ],
    // --- LOGICA DI REDIRECT GLOBALE (SINCRONA) ---
    redirect: (BuildContext context, GoRouterState state) {
      final user = _supabase.auth.currentUser;
      final session = _supabase.auth.currentSession;
      final bool loggedIn = session != null;
      final bool passwordSet = user?.userMetadata?['has_set_password'] == true;
      final String currentMatchedLocation = state.matchedLocation;

      logInfo('[GoRouter Global Redirect] Path: $currentMatchedLocation, LoggedIn: $loggedIn, PwdSet: $passwordSet');

      final isPublicRoute = (currentMatchedLocation == '/login' || currentMatchedLocation == '/splash' || currentMatchedLocation == '/' || currentMatchedLocation == '/unauthorized');

      if (loggedIn) {
        if (!passwordSet && currentMatchedLocation != '/set-password') {
          return '/set-password';
        }
        if (passwordSet && (currentMatchedLocation == '/login' || currentMatchedLocation == '/splash' || currentMatchedLocation == '/set-password' || currentMatchedLocation == '/')) {
          if (currentMatchedLocation == '/database') {
            return null;
          }
          if (currentMatchedLocation != '/unauthorized') {
            return '/home';
          }
        }
        return null;
      } else {
        // Non Loggato
        if (!isPublicRoute) {
          return '/login';
        }
        return null;
      }
    },
    errorBuilder: (context, state) {
      /* ... invariato ... */
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
