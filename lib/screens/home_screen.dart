// home_screen.dart /screens\home_screen.dart
//************** INIZIO CODICE DART *******************
// lib/screens/home_screen.dart
// ignore_for_file: avoid_print, deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:una_social/controllers/auth_controller.dart';
import 'package:una_social/controllers/esterni_controller.dart';
import 'package:una_social/controllers/personale_controller.dart';
import 'package:una_social/controllers/ui_controller.dart';
import 'package:una_social/helpers/auth_helper.dart';
import 'package:una_social/helpers/avatar_helper.dart';
import 'package:una_social/helpers/db_grid.dart';
import 'package:una_social/models/esterni.dart';
import 'package:una_social/models/i_user_profile.dart';
import 'package:una_social/models/personale.dart';
import 'package:una_social/painters/star_painter.dart';
import 'package:una_social/screens/esterni_profile.dart';
import 'package:una_social/screens/personale_profile.dart';
import 'package:una_social/app_router.dart'; // Importa AppRoute
import 'package:una_social/helpers/logger_helper.dart'; // Importa il logger

enum ProfileAction { edit, logout, version }

const Color primaryBlue = Color(0xFF0028FF);
const Color primaryGold = Color(0xFFFFD700);

class HomeScreen extends StatefulWidget {
  final Widget child;

  const HomeScreen({
    super.key,
    required this.child,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PersonaleController ctrlPersonale = Get.find<PersonaleController>();
  final EsterniController ctrlEsterni = Get.find<EsterniController>();
  final AuthController authController = Get.find<AuthController>();
  final UiController uiController = Get.find<UiController>();
  String _appVersion = 'Caricamento...';
  String _buildNumber = '';
  bool _profileCheckCompleted = false;

  // Variabile per prevenire il doppio tap/click sul drawer
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    _initPackageInfo();
  }

  Future<void> _initPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _appVersion = info.version;
        _buildNumber = info.buildNumber;
      });
    }
  }

  // Funzione per gestire i tap sulle voci del drawer con debouncing
  void _handleDrawerTap(VoidCallback action) {
    if (_isNavigating) {
      // Se una navigazione è già in corso, ignora il tap
      return;
    }

    setState(() {
      _isNavigating = true; // Imposta lo stato di navigazione a true
    });

    action(); // Esegui l'azione di navigazione e chiusura del drawer

    // Resetta lo stato di navigazione dopo un breve ritardo.
    // Questo permette alla navigazione di iniziare e al drawer di chiudersi,
    // ignorando tap multipli nel frattempo.
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        // Assicurati che il widget sia ancora montato prima di chiamare setState
        setState(() {
          _isNavigating = false; // Reimposta lo stato a false
        });
      }
    });
  }

  void _showSnackbar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  DBGridControl? _getDbGridControl() {
    if (widget.child is DBGridProvider) {
      final provider = widget.child as DBGridProvider;
      final state = provider.dbGridWidgetKey.currentState;
      if (state != null && state is DBGridControl) {
        return state as DBGridControl;
      }
    }
    return null;
  }

  void _handleToggleView() {
    final control = _getDbGridControl();
    if (control != null) {
      control.toggleUIModePublic();
      if (mounted) setState(() {});
    } else {
      _showSnackbar("Controllo della vista non disponibile.", isError: true);
    }
  }

  void _showVersionDialog() {
    if (!mounted) return;
    String displayVersion = 'Versione: $_appVersion';
    if (_buildNumber.isNotEmpty && _buildNumber != "0") {
      displayVersion += '+$_buildNumber';
    }
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Versione Applicazione', style: Theme.of(dialogContext).textTheme.titleMedium),
        content: Text(displayVersion),
        actions: [TextButton(child: const Text('Chiudi'), onPressed: () => Navigator.of(dialogContext).pop())],
      ),
    );
  }

  void _showProfileDialog(dynamic profile) {
    if (!mounted) return;
    Widget contentWidget;
    String title;
    if (profile is Personale) {
      title = 'Modifica Profilo Personale';
      contentWidget = PersonaleProfile(initialPersonale: profile);
    } else if (profile is Esterni) {
      title = profile.id.isEmpty ? 'Completa il tuo Profilo' : 'Modifica Profilo Esterno';
      contentWidget = EsterniProfile(initialEsterni: profile);
    } else {
      _showSnackbar("Tipo di profilo non riconosciuto.", isError: true);
      return;
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        contentPadding: EdgeInsets.zero,
        scrollable: true,
        content: SizedBox(
          width: MediaQuery.of(dialogContext).size.width * 0.8,
          child: contentWidget,
        ),
      ),
    );
  }

  void _promptToCompleteProfile(User authUser) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showSnackbar("Per favor, completa il tuo profilo.");
      final newEsternoProfile = Esterni(
        id: '',
        authUuid: authUser.id,
        emailPrincipale: authUser.email,
      );
      _showProfileDialog(newEsternoProfile);
    });
  }

  Widget _buildAvatar(String? url) {
    if (url == null || url.isEmpty) {
      return CircleAvatar(radius: 18, backgroundColor: Theme.of(context).colorScheme.primaryContainer, child: Icon(Icons.person_outline, size: 18, color: Theme.of(context).colorScheme.onPrimaryContainer));
    }
    return CircleAvatar(
      radius: 18,
      backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
      child: ClipOval(
        child: Image.network(
          url,
          key: ValueKey(url),
          width: 36,
          height: 36,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) => progress == null ? child : const Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))),
          errorBuilder: (context, error, stackTrace) => CircleAvatar(radius: 18, backgroundColor: Theme.of(context).colorScheme.errorContainer, child: Icon(Icons.error_outline, size: 18, color: Theme.of(context).colorScheme.onErrorContainer)),
        ),
      ),
    );
  }

  List<Widget> getSistema(BuildContext context, AuthController authController) {
    return [
      ListTile(
        leading: const Icon(Icons.storage_outlined),
        title: const Text('Database'),
        onTap: () {
          _handleDrawerTap(() {
            final currentUri = GoRouter.of(context).routerDelegate.currentConfiguration.uri.toString();
            appLogger.info('[HomeScreen Drawer] Current URI before navigating to Database: $currentUri');
            GoRouter.of(context).go(AppRoute.database.path);
            Navigator.of(context).pop();
          });
        },
      ),
    ];
  }

  Widget _buildDrawer(BuildContext context, double drawerWidth, double starGraphicSize, double starRadius) {
    return Drawer(
      width: drawerWidth,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              SizedBox(
                width: starGraphicSize,
                height: starGraphicSize,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(size: Size(starGraphicSize, starGraphicSize), painter: StarPainter(radius: starRadius, color: primaryGold, rotation: 0)),
                    Text("UNA", style: GoogleFonts.pacifico(color: primaryBlue, fontSize: starRadius * 0.6)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text('Una Social', style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Divider(),
              Expanded(
                child: Obx(() => ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        ListTile(
                          leading: const Icon(Icons.home_outlined),
                          title: const Text('Home'),
                          onTap: () {
                            _handleDrawerTap(() {
                              final currentUri = GoRouter.of(context).routerDelegate.currentConfiguration.uri.toString();
                              appLogger.info('[HomeScreen Drawer] Current URI before navigating to Home: $currentUri');
                              GoRouter.of(context).go(AppRoute.home.path);
                              Navigator.of(context).pop();
                            });
                          },
                        ),
                        if (authController.isSuperAdmin.value == true) ...getSistema(context, authController),
                        ListTile(
                          leading: const Icon(Icons.chat),
                          title: const Text('Chat'),
                          onTap: () {
                            _handleDrawerTap(() {
                              final currentUri = GoRouter.of(context).routerDelegate.currentConfiguration.uri.toString();
                              appLogger.info('[HomeScreen Drawer] Current URI before navigating to Chat: $currentUri');
                              GoRouter.of(context).go(AppRoute.chat.path);
                              Navigator.of(context).pop();
                            });
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.person_add_alt_1_outlined),
                          title: const Text('Importa Contatti'),
                          onTap: () {
                            _handleDrawerTap(() {
                              final currentUri = GoRouter.of(context).routerDelegate.currentConfiguration.uri.toString();
                              appLogger.info('[HomeScreen Drawer] Current URI before navigating to Import Contacts: $currentUri');
                              GoRouter.of(context).go(AppRoute.importContacts.path);
                              Navigator.of(context).pop();
                            });
                          },
                        ),
                      ],
                    )),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBreadcrumbsWidget(BuildContext contextForNavigation) {
    return Obx(() {
      final breadcrumbs = uiController.breadcrumbs;
      if (breadcrumbs.isEmpty) {
        return Text(
          uiController.currentScreenName.value,
          style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
          overflow: TextOverflow.ellipsis,
        );
      }

      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: breadcrumbs.map<Widget>((item) {
            final isLast = item == breadcrumbs.last;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () {
                    if (!isLast) {
                      final currentUri = GoRouter.of(contextForNavigation).routerDelegate.currentConfiguration.uri.toString();
                      appLogger.info('[HomeScreen Breadcrumb] Current URI: $currentUri, Navigating to: ${item.path} (using context.go)');
                      contextForNavigation.go(item.path);
                    }
                  },
                  child: Row(
                    children: [
                      if (item.icon != null)
                        Padding(
                          padding: const EdgeInsets.only(right: 4.0),
                          child: Icon(item.icon, size: 16, color: isLast ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                      Text(
                        item.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: isLast ? FontWeight.bold : FontWeight.normal,
                          color: isLast ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (!isLast)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: Icon(Icons.chevron_right, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
              ],
            );
          }).toList(),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 600;
    final currentDbGridControl = _getDbGridControl();
    final canShowDbGridControls = currentDbGridControl != null;

    final currentGridConfig = (widget.child is DBGridProvider) ? (widget.child as DBGridProvider).dbGridConfig : null;
    final canToggleView = canShowDbGridControls && (currentGridConfig?.uiModes.length ?? 0) > 1;

    final BuildContext? shellNavContext = AppRouter.shellNavigatorKey.currentContext;

    // Logga il percorso corrente quando il widget HomeScreen viene ricostruito
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && shellNavContext != null) {
        final currentUri = GoRouter.of(shellNavContext).routerDelegate.currentConfiguration.uri.toString();
        appLogger.info('[HomeScreen Build] Current ShellRoute URI: $currentUri');
      }
    });

    return Scaffold(
      drawer: _buildDrawer(context, isDesktop ? 250.0 : screenWidth * 0.8, 80.0, 40.0 * 0.8),
      body: SafeArea(
        child: Column(
          children: [
            Material(
              elevation: 1.0,
              child: SizedBox(
                height: kToolbarHeight,
                child: Row(
                  children: [
                    Builder(builder: (innerContext) => IconButton(tooltip: "Apri menù", icon: const Icon(Icons.menu), onPressed: () => Scaffold.of(innerContext).openDrawer())),
                    const SizedBox(width: 8),
                    const FlutterLogo(size: 24),
                    const SizedBox(width: 8),
                    const Text('Una Social', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 12),
                    Expanded(child: shellNavContext != null ? _buildBreadcrumbsWidget(shellNavContext) : const SizedBox.shrink()),
                    if (canShowDbGridControls) ...[
                      IconButton(tooltip: "Ricarica Dati", icon: const Icon(Icons.refresh), onPressed: currentDbGridControl.refreshData),
                      if (canToggleView) IconButton(tooltip: "Cambia vista", icon: const Icon(Icons.view_quilt_outlined), onPressed: _handleToggleView),
                    ],
                    const SizedBox(width: 10),
                    Obx(() {
                      final authUser = Supabase.instance.client.auth.currentUser;
                      if (authUser == null) return Padding(padding: const EdgeInsets.all(8.0), child: _buildAvatar(null));

                      final Personale? personale = ctrlPersonale.personale.value;
                      final Esterni? esterno = ctrlEsterni.esterni.value;
                      final IUserProfile? activeProfile = personale ?? esterno;
                      final bool isLoading = ctrlPersonale.isLoading.value || ctrlEsterni.isLoading.value;

                      final bool isExternalUser = personale == null;
                      final bool profileIsMissing = esterno == null;
                      if (!_profileCheckCompleted && isExternalUser && !isLoading && profileIsMissing) {
                        _profileCheckCompleted = true;
                        _promptToCompleteProfile(authUser);
                      }

                      if (activeProfile == null && isLoading) {
                        return const Padding(padding: EdgeInsets.symmetric(horizontal: 16.0), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)));
                      }

                      return FutureBuilder<String?>(
                        key: ValueKey('avatar_${activeProfile?.photoUrl}_${authUser.id}'),
                        future: AvatarHelper.getDisplayAvatarUrl(
                          user: activeProfile,
                          authUser: authUser,
                        ),
                        builder: (context, snapshot) {
                          Widget avatarContent;

                          if (snapshot.connectionState == ConnectionState.waiting) {
                            avatarContent = const CircleAvatar(radius: 18, child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)));
                          } else {
                            avatarContent = _buildAvatar(snapshot.data);
                          }

                          return PopupMenuButton<ProfileAction>(
                            tooltip: "Opzioni Profilo",
                            itemBuilder: (popupContext) => [
                              const PopupMenuItem(value: ProfileAction.edit, child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('Modifica profilo'), dense: true)),
                              const PopupMenuDivider(),
                              const PopupMenuItem(value: ProfileAction.version, child: ListTile(leading: Icon(Icons.info_outline), title: Text('Versione'), dense: true)),
                              const PopupMenuItem(value: ProfileAction.logout, child: ListTile(leading: Icon(Icons.exit_to_app, color: Colors.redAccent), title: Text('Esci', style: TextStyle(color: Colors.redAccent)), dense: true)),
                            ],
                            onSelected: (action) {
                              switch (action) {
                                case ProfileAction.edit:
                                  final profileToEdit = activeProfile ?? Esterni(id: '', authUuid: authUser.id, emailPrincipale: authUser.email);
                                  _showProfileDialog(profileToEdit);
                                  break;
                                case ProfileAction.logout:
                                  AuthHelper.setLogoutReason(LogoutReason.userInitiated);
                                  Supabase.instance.client.auth.signOut();
                                  break;
                                case ProfileAction.version:
                                  _showVersionDialog();
                                  break;
                              }
                            },
                            offset: const Offset(0, kToolbarHeight * 0.8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8.0), child: avatarContent),
                          );
                        },
                      );
                    }),
                    const SizedBox(width: 10),
                  ],
                ),
              ),
            ),
            Expanded(child: widget.child),
          ],
        ),
      ),
    );
  }
}
//************** FINE CODICE DART *******************
