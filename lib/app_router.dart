// lib/app_router.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Screen Imports
import 'package:una_chat/screens/una_chat_main_screen.dart';
import 'package:una_social/screens/splash_screen.dart';
import 'package:una_social/screens/login_screen.dart';
import 'package:una_social/screens/set_password_screen.dart';
import 'package:una_social/screens/home_screen.dart';
import 'package:una_social/screens/database_screen.dart';
import 'package:una_social/screens/database/ambiti.dart';
import 'package:una_social/screens/database/campus.dart';
import 'package:una_social/screens/database/docenti_inesistenti.dart';
import 'package:una_social/screens/database/personale.dart';
import 'package:una_social/screens/strutture_screen.dart';
import 'package:una_social/screens/import_contacts_screen.dart';

// Controller Imports
import 'package:una_social/controllers/auth_controller.dart';
import 'package:una_social/controllers/profile_controller.dart';

// Helper Imports
import 'package:una_social/helpers/logger_helper.dart';

final _supabase = Supabase.instance.client;
final AuthController authController = Get.find<AuthController>();
final ProfileController profileController = Get.find<ProfileController>();

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
  // Navigator key per lo ShellRoute
  static final _shellNavigatorKey = GlobalKey<NavigatorState>();

  static final List<GoRoute> publicRoutes = [
    GoRoute(path: '/splash', name: 'splash', builder: (context, state) => const SplashScreen()),
    GoRoute(path: '/login', name: 'login', builder: (context, state) => const LoginScreen()),
    GoRoute(path: '/set-password', name: 'set-password', builder: (context, state) => const SetPasswordScreen()),
  ];

  static final List<GoRoute> superAdminRoutes = [
    GoRoute(path: '/app/database', name: 'database', builder: (context, state) => const DatabaseScreen(), redirect: (context, state) async => await authController.checkIsSuperAdmin() ? null : '/app/home'),
    GoRoute(path: '/app/ambiti', name: 'ambiti', builder: (context, state) => const AmbitiScreen(), redirect: (context, state) async => await authController.checkIsSuperAdmin() ? null : '/app/home'),
    GoRoute(path: '/app/campus', name: 'campus', builder: (context, state) => const CampusScreen(), redirect: (context, state) async => await authController.checkIsSuperAdmin() ? null : '/app/home'),
    GoRoute(path: '/app/docenti_inesistenti', name: 'docenti_inesistenti', builder: (context, state) => const DocentiInesistentiScreen(), redirect: (context, state) async => await authController.checkIsSuperAdmin() ? null : '/app/home'),
    GoRoute(path: '/app/personale', name: 'personale', builder: (context, state) => const PersonaleScreen(), redirect: (context, state) async => await authController.checkIsSuperAdmin() ? null : '/app/home'),
  ];

  static FutureOr<String?> _socialRedirect(BuildContext context, GoRouterState state) async {
    await profileController.checkUserRelationships();
    if (!profileController.hasAcceptedRelationships.value) {
      logInfo("[Router Social] Utente senza contatti. Reindirizzo da ${state.matchedLocation} a /app/import-contacts");
      return '/app/import-contacts';
    }
    logInfo("[Router Social] Utente con contatti. Accesso a ${state.matchedLocation} consentito.");
    return null;
  }

  static final GoRouter router = GoRouter(
    initialLocation: '/splash',
    refreshListenable: GoRouterRefreshStream(_supabase.auth.onAuthStateChange),
    routes: [
      ...publicRoutes,
      ...superAdminRoutes, // Le route SuperAdmin ora sono a livello principale

      // --- INIZIO SOSTITUZIONE CON SHELLROUTE ---
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        // --- INIZIO CORREZIONE ---
        builder: (context, state, child) {
          // Leggiamo il nome della rotta corrente dallo stato della navigazione.
          // Usiamo un valore di fallback per sicurezza.
          final screenName = state.topRoute?.name ?? 'Home';

          // Passiamo il nome dinamico al widget HomeScreen.
          return HomeScreen(screenName: screenName, child: child);
        },
        // --- FINE CORREZIONE ---
        // Le rotte figlie dello ShellRoute.
        routes: [
          GoRoute(
            path: '/app/home',
            name: 'home',
            builder: (context, state) => const Center(child: Text('Contenuto principale della Home')),
          ),
          GoRoute(
            path: '/app/strutture',
            name: 'strutture',
            builder: (context, state) => StruttureScreen(),
          ),
          GoRoute(
            path: '/app/chat',
            name: 'chat',
            builder: (context, state) => UnaChatMainScreen(),
            redirect: _socialRedirect, // Il redirect ora funzionerà come previsto
          ),
          GoRoute(
            path: '/app/import-contacts',
            name: 'import-contacts',
            builder: (context, state) => const ImportContactsScreen(),
            redirect: (context, state) async {
              await profileController.checkUserRelationships();
              if (profileController.hasAcceptedRelationships.value) {
                logInfo("[Router] Utente su import-contacts ma con amici. Reindirizzo a /app/chat.");
                return '/app/chat';
              }
              return null;
            },
          ),
        ],
      ),
      // --- FINE SOSTITUZIONE CON SHELLROUTE ---
    ],
    redirect: (BuildContext context, GoRouterState state) {
      final user = _supabase.auth.currentUser;
      final bool loggedIn = user != null;
      final bool passwordSet = user?.userMetadata?['has_set_password'] as bool? ?? false;
      final String location = state.matchedLocation;

      logInfo('[GoRouter Global] Evaluating: Path="$location", LoggedIn=$loggedIn, PasswordSet=$passwordSet');

      if (loggedIn && !passwordSet) {
        if (location != '/set-password') {
          logInfo('[GoRouter Global] Redirect: Loggato ma password non impostata. Forzo -> /set-password');
          return '/set-password';
        }
        return null;
      }

      if (loggedIn && passwordSet) {
        final bool onSetupOrPublicPath = location == '/splash' || location == '/login' || location == '/set-password' || location == '/';
        if (onSetupOrPublicPath) {
          logInfo('[GoRouter Global] Redirect: Utente autenticato su pagina pubblica. Forzo -> /app/home');
          return '/app/home';
        }
      }

      if (!loggedIn) {
        final bool isPublicPath = publicRoutes.any((route) => route.path == location);
        if (!isPublicPath && location != '/unauthorized') {
          logInfo('[GoRouter Global] Redirect: Non loggato su pagina protetta. Forzo -> /login');
          return '/login';
        }
      }

      logInfo('[GoRouter Global] Nessun redirect necessario.');
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
                const Text('Pagina non trovata o errore del router.', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
