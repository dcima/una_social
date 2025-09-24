// lib/app_router.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Screen Imports
import 'package:una_chat/screens/una_chat_main_screen.dart';
// NOTA: Usa i percorsi relativi corretti per il tuo progetto
import 'package:una_social/screens/colleghi_screen.dart';
import 'package:una_social/screens/database/strutture.dart';
import 'package:una_social/screens/database_screen.dart';
import 'package:una_social/screens/database/ambiti.dart';
import 'package:una_social/screens/database/campus.dart';
import 'package:una_social/screens/database/docenti_inesistenti.dart';
import 'package:una_social/screens/database/personale.dart';
import 'package:una_social/screens/home_screen.dart';
import 'package:una_social/screens/import_contacts_screen.dart';
import 'package:una_social/screens/login_screen.dart';
import 'package:una_social/screens/set_password_screen.dart';
import 'package:una_social/screens/splash_screen.dart';

// Controller Imports
import 'package:una_social/controllers/auth_controller.dart';
import 'package:una_social/controllers/profile_controller.dart';
import 'package:una_social/controllers/ui_controller.dart';

// Helper Imports
import 'package:una_social/helpers/logger_helper.dart';

final _supabase = Supabase.instance.client;
final AuthController authController = Get.find<AuthController>();
final ProfileController profileController = Get.find<ProfileController>();
final UiController uiController = Get.put<UiController>(UiController());

class GoRouterRefreshStream extends ChangeNotifier {
  late final StreamSubscription<AuthState> _subscription;
  bool _isDisposed = false;

  GoRouterRefreshStream(Stream<AuthState> stream) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isDisposed) _safeNotifyListeners(); // Usa la funzione con ritardo
    });
    _subscription = stream.asBroadcastStream().listen((AuthState data) {
      if (!_isDisposed) _safeNotifyListeners(); // Usa la funzione con ritardo
    }, onError: (error) {
      if (!_isDisposed) _safeNotifyListeners(); // Usa la funzione con ritardo
    });
  }

  // Nuova funzione per ritardare la notifica ai listener del router
  void _safeNotifyListeners() {
    // Ritarda leggermente la notifica per permettere alle operazioni UI in corso
    // (come la chiusura di un popup) di completarsi prima che il router
    // inizi una nuova navigazione.
    Future.delayed(const Duration(milliseconds: 50), () {
      if (!_isDisposed) {
        notifyListeners();
      }
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

// L'enum può essere semplificato se usi i nomi come stringhe
enum AppRoute {
  importContacts,
  colleghi,
}

class AppRouter {
  static final _shellNavigatorKey = GlobalKey<NavigatorState>();

  static final List<GoRoute> publicRoutes = [
    GoRoute(path: '/splash', name: 'splash', builder: (context, state) => const SplashScreen()),
    GoRoute(path: '/login', name: 'login', builder: (context, state) => const LoginScreen()),
    GoRoute(path: '/set-password', name: 'set-password', builder: (context, state) => const SetPasswordScreen()),
  ];

  static final List<GoRoute> superAdminRoutes = [
    GoRoute(
        path: '/app/ambiti',
        name: 'ambiti',
        builder: (context, state) => HomeScreen(
              screenName: "Ambiti",
              child: AmbitiScreen(),
            ),
        redirect: (context, state) async => await authController.checkIsSuperAdmin() ? null : '/app/home'),
    GoRoute(
        path: '/app/campus',
        name: 'campus',
        builder: (context, state) => HomeScreen(
              screenName: "Campus",
              child: CampusScreen(),
            ),
        redirect: (context, state) async => await authController.checkIsSuperAdmin() ? null : '/app/home'),
    GoRoute(
        path: '/app/database',
        name: 'database',
        builder: (context, state) => HomeScreen(
              screenName: "Database",
              child: DatabaseScreen(),
            ),
        redirect: (context, state) async => await authController.checkIsSuperAdmin() ? null : '/app/home'),
    GoRoute(
        path: '/app/docenti_inesistenti',
        name: 'docenti_inesistenti',
        builder: (context, state) => HomeScreen(screenName: "Docenti inesistenti", child: DocentiInesistentiScreen()),
        redirect: (context, state) async => await authController.checkIsSuperAdmin() ? null : '/app/home'),
    GoRoute(
        path: '/app/personale',
        name: 'personale',
        builder: (context, state) => HomeScreen(
              screenName: "Personale",
              child: PersonaleScreen(),
            ),
        redirect: (context, state) async => await authController.checkIsSuperAdmin() ? null : '/app/home'),
    GoRoute(
        path: '/app/strutture',
        name: 'strutture',
        builder: (context, state) => HomeScreen(
              screenName: "Strutture",
              child: StruttureScreen(),
            ),
        redirect: (context, state) async => await authController.checkIsSuperAdmin() ? null : '/app/home'),
  ];

  static FutureOr<String?> _socialRedirect(BuildContext context, GoRouterState state) async {
    await profileController.checkUserRelationships();
    if (!profileController.hasAcceptedRelationships.value) {
      logInfo("[Router Social] Utente senza contatti. Reindirizzo da ${state.matchedLocation} a /app/import-contacts");
      return '/app/import-contacts'; // Restituisci il percorso come stringa per il redirect
    }
    logInfo("[Router Social] Utente con contatti. Accesso a ${state.matchedLocation} consentito.");
    return null;
  }

  static final GoRouter router = GoRouter(
    initialLocation: '/splash',
    debugLogDiagnostics: true, // UTILISSIMO per debuggare, lascialo attivo per ora
    refreshListenable: GoRouterRefreshStream(_supabase.auth.onAuthStateChange),
    routes: [
      ...publicRoutes,
      ...superAdminRoutes,

      GoRoute(
        path: '/app/import-contacts', // Il percorso ora corrisponde a quello del redirect
        name: AppRoute.importContacts.name,
        builder: (context, state) => HomeScreen(screenName: "Importa contatti", child: ImportContactsScreen()),
        routes: [
          // La rotta figlia è definita correttamente qui
          GoRoute(
            path: 'colleghi', // Il percorso completo sarà /app/import-contacts/colleghi
            name: AppRoute.colleghi.name,
            builder: (context, state) {
              uiController.setCurrentScreenName("Colleghi"); // Titolo predefinito per Colleghi, sarà aggiornato dalla schermata
              return HomeScreen(screenName: "Colleghi", child: ColleghiScreen());
            },
          ),
        ],
      ),

      // ShellRoute per le schermate principali che condividono la UI (HomeScreen)
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) {
          // Imposta il titolo predefinito per le schermate interne alla ShellRoute
          final screenNameFromRoute = state.topRoute?.name ?? 'Home';
          uiController.setCurrentScreenName(screenNameFromRoute.capitalizeFirst.toString()); // Utilizza capitalizeFirst per una buona formattazione
          return HomeScreen(screenName: screenNameFromRoute.capitalizeFirst.toString(), child: child);
        },
        routes: [
          // Le rotte figlie della ShellRoute.
          // La rotta 'import-contacts' è stata rimossa da qui.
          GoRoute(
            path: '/app/home',
            name: 'home',
            builder: (context, state) => const Center(child: Text('Contenuto principale della Home')),
          ),
          GoRoute(
            path: '/app/chat',
            name: 'chat',
            builder: (context, state) => HomeScreen(screenName: "Chat", child: UnaChatMainScreen()),
            redirect: _socialRedirect,
          ),
        ],
      ),
    ],
    redirect: (BuildContext context, GoRouterState state) {
      // ... Il tuo redirect globale rimane invariato ...
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
      // ... Il tuo errorBuilder rimane invariato ...
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
