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

enum ProfileAction { edit, logout, version }

const Color primaryBlue = Color(0xFF0028FF);
const Color primaryGold = Color(0xFFFFD700);

class HomeScreen extends StatefulWidget {
  final String screenName;
  final Widget child;

  const HomeScreen({
    super.key,
    required this.child,
    this.screenName = 'Home',
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PersonaleController ctrlPersonale = Get.find<PersonaleController>();
  final EsterniController ctrlEsterni = Get.find<EsterniController>();
  final AuthController authController = Get.find<AuthController>();
  String _appVersion = 'Caricamento...';
  String _buildNumber = '';
  bool _profileCheckCompleted = false;

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
      _showSnackbar("Per favore, completa il tuo profilo.");
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
        leading: const Icon(Icons.data_object_outlined),
        title: const Text('Database'),
        onTap: () => GoRouter.of(context).go('/app/database'),
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
                          onTap: () => GoRouter.of(context).go('/app/home'),
                        ),
                        if (authController.isSuperAdmin.value == true) ...getSistema(context, authController),
                        ListTile(
                          leading: const Icon(Icons.chat),
                          title: const Text('Chat'),
                          onTap: () => GoRouter.of(context).go('/app/chat'),
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

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 600;
    final currentDbGridControl = _getDbGridControl();
    final canShowDbGridControls = currentDbGridControl != null;
    final UiController uiController = Get.find<UiController>(); // Ottieni il controller

    // Puoi inizializzare il titolo del controller con il screenName passato,
    // se non è già stato impostato da una schermata specifica.
    // Oppure lasciare che siano le singole schermate a impostarlo.
    // Per garantire che ci sia sempre un titolo sensato, lo imposto qui,
    // ma le schermate figlie come ColleghiScreen lo sovrascriveranno.
    if (uiController.currentScreenName.value == 'Caricamento...' || uiController.currentScreenName.value != widget.screenName) {
      uiController.setCurrentScreenName(widget.screenName);
    }

    DBGridConfig? currentGridConfig;
    if (widget.child is DBGridProvider) {
      currentGridConfig = (widget.child as DBGridProvider).dbGridConfig;
    }
    final canToggleView = canShowDbGridControls && (currentGridConfig?.uiModes.length ?? 0) > 1;

    return Scaffold(
      drawer: _buildDrawer(context, isDesktop ? 250.0 : screenWidth * 0.8, 80.0, 40.0 * 0.8),
      body: Column(
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
                  Expanded(child: Text(widget.screenName, style: const TextStyle(fontSize: 20, color: Colors.red, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
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

                    // Re-introduce FutureBuilder since getDisplayAvatarUrl is now async
                    return FutureBuilder<String?>(
                      // Use a unique key to force the future to re-run when the profile changes
                      key: ValueKey('avatar_${activeProfile?.photoUrl}_${authUser.id}'),
                      future: AvatarHelper.getDisplayAvatarUrl(
                        user: activeProfile,
                        authUser: authUser,
                      ),
                      builder: (context, snapshot) {
                        Widget avatarContent;

                        if (snapshot.connectionState == ConnectionState.waiting) {
                          // Show a loader while waiting for the signed URL
                          avatarContent = const CircleAvatar(radius: 18, child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)));
                        } else {
                          // Build the avatar with the result (which could be null)
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
    );
  }
}
