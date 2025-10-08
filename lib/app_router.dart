import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:una_social/screens/contatti/import_contacts_screen.dart';
import 'package:una_social/screens/database/ambiti.dart';
import 'package:una_social/screens/database/campus.dart';
import 'package:una_social/screens/database/database_screen.dart';
import 'package:una_social/screens/database/docenti_inesistenti.dart';
import 'package:una_social/screens/database/esterni.dart';
import 'package:una_social/screens/database/groups.dart';
import 'package:una_social/screens/database/personale.dart';
import 'package:una_social/screens/database/strutture.dart';
import 'package:una_social/screens/home_screen.dart';
import 'package:una_social/controllers/ui_controller.dart';
import 'package:una_social/screens/login_screen.dart';

enum AppRoute {
  login('/login'),
  home('/app/home'),
  database('/app/database'),
  chat('/app/chat'),
  ambiti('/app/ambiti'),
  importContacts('/app/import-contacts'),
  colleghi('/app/colleghi'),
  ;

  const AppRoute(this.path);
  final String path;
}

class AppRouter {
  static final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
  static final GlobalKey<NavigatorState> _shellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'shell');

  // *** NUOVA VARIABILE STATICA PER TRACCIARE L'ULTIMO PERCORSO DEI BREADCRUMBS ***
  static String? _lastBreadcrumbPath;

  static final GoRouter router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoute.login.path,
    debugLogDiagnostics: true,
    refreshListenable: GoRouterRefreshStream(Supabase.instance.client.auth.onAuthStateChange),
    redirect: (BuildContext context, GoRouterState state) {
      final bool loggedIn = Supabase.instance.client.auth.currentUser != null;
      final bool loggingIn = state.matchedLocation == AppRoute.login.path;

      if (!loggedIn) {
        // Se non loggato e non sta andando alla pagina di login, reindirizza al login
        return loggingIn ? null : AppRoute.login.path;
      }

      // Se loggato e sta cercando di accedere alla pagina di login, reindirizza alla home
      if (loggingIn) {
        return AppRoute.home.path;
      }

      // Se il percorso cambia a una rotta non-app (es. /login), resetta il tracker
      if (!state.uri.toString().startsWith('/app')) {
        _lastBreadcrumbPath = null;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoute.login.path,
        builder: (context, state) => const LoginScreen(),
      ),
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) {
          final UiController uiController = Get.find<UiController>();
          final currentFullPath = state.uri.toString(); // Ottieni il percorso completo attuale

          // *** APPLICAZIONE DELLA LOGICA DI CONTROLLO ***
          // Schedula l'aggiornamento dei breadcrumbs solo se il percorso è cambiato
          if (_lastBreadcrumbPath != currentFullPath) {
            _lastBreadcrumbPath = currentFullPath; // Aggiorna l'ultimo percorso tracciato
            WidgetsBinding.instance.addPostFrameCallback((_) {
              uiController.updateBreadcrumbs(UiController.buildBreadcrumbsFromPath(currentFullPath));
            });
          }
          // *** FINE LOGICA DI CONTROLLO ***

          return HomeScreen(
            child: child,
          );
        },
        routes: [
          GoRoute(
            path: AppRoute.home.path,
            builder: (context, state) => const Center(child: Text('Contenuto della Home')),
          ),
          GoRoute(
            path: AppRoute.database.path,
            builder: (context, state) => const DatabaseScreen(),
          ),
          GoRoute(
            path: AppRoute.chat.path,
            builder: (context, state) => const Center(child: Text('Schermata Chat')),
          ),
          GoRoute(
            path: AppRoute.ambiti.path,
            builder: (context, state) => const Ambiti(),
          ),
          GoRoute(
            path: AppRoute.importContacts.path,
            name: AppRoute.importContacts.name,
            builder: (context, state) => const ImportContactsScreen(),
          ),
          GoRoute(
            path: AppRoute.colleghi.path,
            name: AppRoute.colleghi.name,
            builder: (context, state) => const Center(child: Text('Schermata Colleghi')),
          ),
          GoRoute(
            path: '${AppRoute.database.path}/:tableName',
            builder: (context, state) {
              final tableName = state.pathParameters['tableName']!;
              switch (tableName.toLowerCase()) {
                case 'ambiti':
                  return Ambiti();
                case 'campus':
                  return Campus();
                case 'docenti_inesistenti':
                  return DocentiInesistenti();
                case 'esterni':
                  return Esterni();
                case 'groups':
                  return Groups();
                case 'personale':
                  return Personale();
                case 'strutture':
                  return Strutture();
                default:
                  return Center(
                    child: Text('Schermata di gestione per la tabella: ${_capitalize(tableName)}'),
                  );
              }
            },
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Errore')),
      body: Center(child: Text('Pagina non trovata: ${state.uri}')),
    ),
  );

  static String _capitalize(String s) => s.isNotEmpty ? s[0].toUpperCase() + s.substring(1).replaceAll('_', ' ') : '';
}

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<AuthState> stream) {
    notifyListeners();
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<AuthState> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
