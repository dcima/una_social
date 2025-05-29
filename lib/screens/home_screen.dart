// ignore_for_file: avoid_print, deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:una_social/controllers/personale_controller.dart';
import 'package:una_social/helpers/auth_helper.dart';
import 'package:una_social/helpers/db_grid.dart';
import 'package:una_social/helpers/logger_helper.dart';
import 'package:una_social/models/personale.dart';
import 'package:una_social/painters/star_painter.dart';
import 'package:una_social/screens/personale_profile.dart';

// Enum for profile menu actions
enum ProfileAction { edit, logout, version }

// Color Constants (consider moving to a shared theme file)
const Color primaryBlue = Color(0xFF0028FF);
const Color primaryGold = Color(0xFFFFD700);
const Color tertiaryColor = Colors.white;

class HomeScreen extends StatefulWidget {
  final String screenName;
  final Widget child; // The main content widget for the current screen

  const HomeScreen({
    super.key,
    required this.screenName,
    required this.child,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _appVersion = 'Caricamento...';
  String _buildNumber = '';

  final PersonaleController ctrl = Get.put(PersonaleController());

  @override
  void initState() {
    super.initState();
    _initPackageInfo();
  }

  Future<void> _initPackageInfo() async {
    final PackageInfo info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _appVersion = info.version;
        _buildNumber = info.buildNumber;
      });
    }
  }

  void _handleToggleView() {
    appLogger.debug("HomeScreen - _handleToggleView: Child type: ${widget.child.runtimeType}");

    if (widget.child is DBGridProvider) {
      final dbGridProvider = widget.child as DBGridProvider;
      final State<DBGridWidget>? actualState = dbGridProvider.dbGridWidgetKey.currentState;

      if (actualState != null && actualState is DBGridControl) {
        final dbGridControl = actualState as DBGridControl;
        dbGridControl.toggleUIModePublic();
        appLogger.info("HomeScreen: Called toggleUIModePublic() on DBGridControl via DBGridProvider.");
        if (mounted) setState(() {});
      } else {
        appLogger.warning("HomeScreen: Could not get DBGridControl from DBGridProvider's key.");
        _showSnackbar(context, "Error trying to change view (control not found).", isError: true);
      }
    } else {
      appLogger.info("HomeScreen: Toggle view button pressed, but child is not a DBGridProvider.");
      _showSnackbar(context, "View toggle not applicable to this screen.");
    }
  }

  void _showVersionDialog(BuildContext context, String value) {
    String displayVersion = 'Versione: $_appVersion';
    if (_buildNumber.isNotEmpty && _buildNumber != "0") {
      displayVersion += '+$_buildNumber';
    }
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(
            'Versione Applicazione',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          content: Text(displayVersion),
          actions: <Widget>[
            TextButton(
              child: const Text('Chiudi'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
          ],
        );
      },
    );
  }

  void _showProfileDialog(BuildContext context, Personale currentUser) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Modifica Profilo'),
          contentPadding: EdgeInsets.zero,
          scrollable: true,
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.6,
            child: PersonaleProfile(initialPersonale: currentUser),
          ),
        );
      },
    );
  }

  void _showSnackbar(BuildContext ctx, String message, {bool isError = false}) {
    if (!ctx.mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!ctx.mounted) return;
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.redAccent : Colors.green,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    });
  }

  Future<String?> _getSignedAvatarUrl(Personale? currentUserFromDb, String authUserEmail, String controllerMessage) async {
    const String bucketName = 'una-bucket';
    const int expiresIn = 86400 * 365 * 50; // 50 years
    final supabase = Supabase.instance.client;

    if (currentUserFromDb != null) {
      if (currentUserFromDb.photoUrl != null && currentUserFromDb.photoUrl!.isNotEmpty) {
        logInfo("HomeScreen - _getSignedAvatarUrl: Using existing photoUrl from Personale object: ${currentUserFromDb.photoUrl}");
        return currentUserFromDb.photoUrl;
      }
      logInfo("HomeScreen: _getSignedAvatarUrl: Generating signed URL for ${currentUserFromDb.nome} ${currentUserFromDb.cognome} (ID: ${currentUserFromDb.id}) from 'personale/foto/' path.");
      final ente = currentUserFromDb.ente;
      final id = currentUserFromDb.id;

      if (ente.isEmpty || id <= 0) {
        logInfo("HomeScreen - _getSignedAvatarUrl: Insufficient data (ente or id missing in Personale object) for 'personale/foto/' path.");
        return null;
      }
      final String imagePath = 'personale/foto/${ente}_$id.jpg';

      try {
        final signedUrl = await supabase.storage.from(bucketName).createSignedUrl(imagePath, expiresIn);
        logInfo("HomeScreen - _getSignedAvatarUrl: Signed URL for 'personale/foto/' generated: $signedUrl");
        return signedUrl;
      } on StorageException catch (e) {
        logInfo("HomeScreen - _getSignedAvatarUrl: StorageException for 'personale/foto/$imagePath': ${e.message} (StatusCode: ${e.statusCode})");
        return null;
      } catch (e, stackTrace) {
        logInfo("HomeScreen - _getSignedAvatarUrl: Unexpected error for 'personale/foto/$imagePath': $e\nStackTrace: $stackTrace");
        return null;
      }
    } else {
      logInfo("HomeScreen - _getSignedAvatarUrl: currentUserFromDb is null.");
      if (controllerMessage == 'Profilo personale non trovato.') {
        logInfo("HomeScreen - _getSignedAvatarUrl: Controller message indicates 'Profilo personale non trovato.' Attempting to load from 'esterni/foto/' for email: $authUserEmail");
        if (authUserEmail.isEmpty) {
          logInfo("HomeScreen - _getSignedAvatarUrl: Auth user email is empty, cannot form 'esterni/foto/' path.");
          return null;
        }
        final String emailFileName = authUserEmail.replaceAll(RegExp(r'[^\w.@-]'), '_');
        final String imagePath = 'esterni/foto/$emailFileName.jpg';
        logInfo("HomeScreen - _getSignedAvatarUrl: Attempting path: $imagePath in bucket: $bucketName");
        try {
          final signedUrl = await supabase.storage.from(bucketName).createSignedUrl(imagePath, expiresIn);
          logInfo("HomeScreen - _getSignedAvatarUrl: Signed URL for 'esterni/foto/' generated: $signedUrl");
          return signedUrl;
        } on StorageException catch (e) {
          logInfo("HomeScreen - _getSignedAvatarUrl: StorageException for 'esterni/foto/$imagePath': ${e.message} (StatusCode: ${e.statusCode})");
          return null;
        } catch (e, stackTrace) {
          logInfo("HomeScreen - _getSignedAvatarUrl: Unexpected error for 'esterni/foto/$imagePath': $e\nStackTrace: $stackTrace");
          return null;
        }
      } else {
        logInfo("HomeScreen - _getSignedAvatarUrl: currentUserFromDb is null and message is '$controllerMessage'. Not attempting 'esterni/foto/'.");
        return null;
      }
    }
  }

  Widget _buildAvatarFromUrl(BuildContext context, String url, bool isSignedUrlAttempt, Personale? personaleForFallbackContext) {
    final bool hasValidUrl = Uri.tryParse(url)?.hasAbsolutePath ?? false;
    if (!hasValidUrl) {
      return isSignedUrlAttempt ? _buildAvatarFromFallback(context, personaleForFallbackContext) : _buildDefaultAvatar(context, "URL fallback non valido ($url)");
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
          fit: BoxFit.fill,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, value: loadingProgress.expectedTotalBytes != null ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes! : null),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            if (isSignedUrlAttempt) {
              return _buildAvatarFromFallback(context, personaleForFallbackContext);
            } else {
              return _buildDefaultAvatar(context, "Errore fallback ($url)");
            }
          },
        ),
      ),
    );
  }

  Widget _buildAvatarFromFallback(BuildContext context, Personale? personaleForFallbackContext) {
    if (personaleForFallbackContext == null) {
      return _buildDefaultAvatar(context, "No Personale data for fallback");
    }
    final String? fallbackUrl = personaleForFallbackContext.photoUrl;
    final bool hasValidFallback = fallbackUrl != null && fallbackUrl.isNotEmpty && (Uri.tryParse(fallbackUrl)?.hasAbsolutePath ?? false);
    if (hasValidFallback) {
      return _buildAvatarFromUrl(context, fallbackUrl, false, personaleForFallbackContext);
    } else {
      return _buildDefaultAvatar(context, "No fallback in Personale data");
    }
  }

  Widget _buildDefaultAvatar(BuildContext context, String reason) {
    return CircleAvatar(
      radius: 18,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      child: Icon(Icons.person_outline, size: 18, color: Theme.of(context).colorScheme.onPrimaryContainer),
    );
  }

  // --- Helper method to build the Drawer widget ---
  Widget _buildDrawer(BuildContext context, double drawerWidth, double starGraphicSize, double starRadius) {
    final chatExpansionController = ExpansionTileController();
    final chatSettingsExpansionController = ExpansionTileController();
    final systemExpansionController = ExpansionTileController();

    // Rinominato: Rimosso underscore iniziale
    Widget buildTappableExpansionTileTitle({
      required BuildContext navContext,
      required IconData icon,
      required String title,
      required String routePath,
      required ExpansionTileController controller,
      Color? iconColor = primaryBlue,
      TextStyle? titleStyle,
    }) {
      return InkWell(
        onTap: () {
          GoRouter.of(navContext).go(routePath);
          if (!controller.isExpanded) {
            controller.expand();
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
          child: Row(
            children: [
              Icon(icon, color: iconColor ?? Theme.of(navContext).iconTheme.color),
              const SizedBox(width: 32),
              Expanded(child: Text(title, style: titleStyle ?? TextStyle(color: iconColor))),
            ],
          ),
        ),
      );
    }

    return Drawer(
      child: SizedBox(
        width: drawerWidth,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Builder(
              builder: (BuildContext drawerContext) {
                return Column(
                  key: const Key('drawerColumn'),
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: starGraphicSize,
                      height: starGraphicSize,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CustomPaint(
                            size: Size(starGraphicSize, starGraphicSize),
                            painter: StarPainter(radius: starRadius, rotation: 0, color: primaryGold),
                          ),
                          Text("UNA", style: GoogleFonts.pacifico(color: primaryBlue, fontSize: starRadius * 0.6)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('Una Social', style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                    const SizedBox(height: 8),
                    const Divider(),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView(
                        padding: EdgeInsets.zero,
                        children: [
                          ListTile(
                            leading: const Icon(Icons.home_outlined, color: primaryBlue),
                            title: const Text('Home'),
                            onTap: () {
                              Navigator.pop(drawerContext);
                              GoRouter.of(drawerContext).go('home');
                            },
                          ),
                          ExpansionTile(
                            controller: chatExpansionController,
                            tilePadding: EdgeInsets.zero,
                            title: buildTappableExpansionTileTitle(
                              // Rinominato
                              navContext: drawerContext,
                              icon: Icons.chat,
                              title: 'Una Chat',
                              routePath: '/app/una_chat',
                              controller: chatExpansionController,
                              titleStyle: const TextStyle(color: primaryBlue),
                            ),
                            childrenPadding: const EdgeInsets.only(left: 15.0),
                            children: [
                              ListTile(
                                leading: const Icon(Icons.phone, color: primaryBlue),
                                title: const Text('Chiamate'),
                                onTap: () {
                                  Navigator.pop(drawerContext);
                                  GoRouter.of(drawerContext).push('una_chat_chiamate');
                                },
                              ),
                              ListTile(
                                leading: const Icon(Icons.donut_large_outlined, color: primaryBlue),
                                title: const Text('Stato'),
                                onTap: () {
                                  Navigator.pop(drawerContext);
                                  GoRouter.of(drawerContext).push('una_chat_stato');
                                },
                              ),
                              ListTile(
                                leading: const Icon(Icons.star, color: primaryBlue),
                                title: const Text('Messaggi importanti'),
                                onTap: () {
                                  Navigator.pop(drawerContext);
                                  GoRouter.of(drawerContext).push('una_chat_importanti');
                                },
                              ),
                              ListTile(
                                leading: const Icon(Icons.archive, color: primaryBlue),
                                title: const Text('Chat archiviate'),
                                onTap: () {
                                  Navigator.pop(drawerContext);
                                  GoRouter.of(drawerContext).push('una_chat_archiviate');
                                },
                              ),
                              ExpansionTile(
                                controller: chatSettingsExpansionController,
                                tilePadding: EdgeInsets.zero,
                                title: buildTappableExpansionTileTitle(
                                  // Rinominato
                                  navContext: drawerContext,
                                  icon: Icons.settings,
                                  title: 'Impostazioni',
                                  routePath: 'una_chat_settings',
                                  controller: chatSettingsExpansionController,
                                  titleStyle: const TextStyle(color: primaryBlue),
                                ),
                                children: [
                                  ListTile(
                                    leading: const Icon(Icons.tune, color: Colors.deepPurple),
                                    title: const Text('Generale'),
                                    onTap: () {
                                      Navigator.pop(drawerContext);
                                      GoRouter.of(drawerContext).push('un_chat_settings_generale');
                                    },
                                  ),
                                  ListTile(
                                    leading: const Icon(Icons.key, color: Colors.deepPurple),
                                    title: const Text('Account'),
                                    onTap: () {
                                      Navigator.pop(drawerContext);
                                      GoRouter.of(drawerContext).push('una_chat_settings_account');
                                    },
                                  ),
                                  ListTile(
                                    leading: const Icon(Icons.chat_bubble, color: Colors.deepPurple),
                                    title: const Text('Chat (opzioni)'),
                                    onTap: () {
                                      Navigator.pop(drawerContext);
                                      GoRouter.of(drawerContext).push('una_chat_settings_chat');
                                    },
                                  ),
                                  ListTile(
                                    leading: const Icon(Icons.videocam, color: Colors.deepPurple),
                                    title: const Text('Video e audio'),
                                    onTap: () {
                                      Navigator.pop(drawerContext);
                                      GoRouter.of(drawerContext).push('una_chat_settings_video_audio');
                                    },
                                  ),
                                  ListTile(
                                    leading: const Icon(Icons.notifications, color: Colors.deepPurple),
                                    title: const Text('Notifiche'),
                                    onTap: () {
                                      Navigator.pop(drawerContext);
                                      GoRouter.of(drawerContext).push('una_chat_settings_notifiche');
                                    },
                                  ),
                                  ListTile(
                                    leading: const Icon(Icons.brush, color: Colors.deepPurple),
                                    title: const Text('Personalizzazione'),
                                    onTap: () {
                                      Navigator.pop(drawerContext);
                                      GoRouter.of(drawerContext).push('una_chat_settings_personalizzazione');
                                    },
                                  ),
                                  ListTile(
                                    leading: const Icon(Icons.archive, color: Colors.deepPurple),
                                    title: const Text('Archiviazione'),
                                    onTap: () {
                                      Navigator.pop(drawerContext);
                                      GoRouter.of(drawerContext).push('una_chat_settings_archiviazione');
                                    },
                                  ),
                                  ListTile(
                                    leading: const Icon(Icons.keyboard, color: Colors.deepPurple),
                                    title: const Text('Collegamenti rapidi'),
                                    onTap: () {
                                      Navigator.pop(drawerContext);
                                      GoRouter.of(drawerContext).push('una_chat_settings_collegamenti_rapidi');
                                    },
                                  ),
                                  ListTile(
                                    leading: const Icon(Icons.info, color: Colors.deepPurple),
                                    title: const Text('Aiuto'),
                                    onTap: () {
                                      Navigator.pop(drawerContext);
                                      GoRouter.of(drawerContext).push('una_chat_settings_aiuto');
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                          ExpansionTile(
                            childrenPadding: const EdgeInsets.only(left: 15.0),
                            leading: const Icon(Icons.build, color: primaryBlue),
                            title: const Text('Sistema', style: TextStyle(color: primaryBlue)),
                            children: [
                              ListTile(
                                leading: const Icon(Icons.business_center, color: Colors.deepPurple),
                                title: const Text('Strutture'),
                                onTap: () {
                                  Navigator.pop(drawerContext);
                                  GoRouter.of(drawerContext).push('/app/strutture');
                                },
                              ),
                              ListTile(
                                leading: const Icon(Icons.storage_rounded, color: Colors.deepPurple),
                                title: const Text('Database'),
                                onTap: () {
                                  Navigator.pop(drawerContext);
                                  GoRouter.of(drawerContext).push('/app/database');
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.info_outline, color: Colors.grey),
                      title: const Text('App Info', style: TextStyle(color: Colors.grey)),
                      onTap: () {
                        Navigator.pop(drawerContext);
                        showAboutDialog(
                          context: context,
                          applicationName: 'Una Social',
                          applicationVersion: ctrl.appVersion.value.isNotEmpty ? ctrl.appVersion.value : 'N/A',
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isDesktop = screenWidth > 600;
    final double drawerWidth = isDesktop ? 200.0 : screenWidth * 0.8;
    const double starGraphicSize = 80.0;
    const double starRadius = starGraphicSize / 2 * 0.8;

    Widget searchBar = Expanded(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 250),
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: TextField(
          key: const Key('searchField'),
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
            hintText: 'Cerca...',
            hintStyle: TextStyle(color: Theme.of(context).hintColor.withOpacity(0.6)),
            prefixIcon: const Icon(Icons.search, size: 20),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
          ),
          onSubmitted: (value) {
            // Implement search logic
          },
        ),
      ),
    );

    bool shouldShowDbGridControls = false;
    bool canShowSearchBar = false; // Variabile separata per la search bar
    IconData currentToggleIcon = Icons.view_quilt_outlined;
    String currentToggleTooltip = "Cambia vista";
    DBGridConfig? currentGridConfig;
    DBGridControl? currentDbGridControl;

    if (widget.child is DBGridProvider) {
      final dbGridProvider = widget.child as DBGridProvider;
      currentGridConfig = dbGridProvider.dbGridConfig;
      final State<DBGridWidget>? actualState = dbGridProvider.dbGridWidgetKey.currentState;
      if (actualState != null && actualState is DBGridControl) {
        currentDbGridControl = actualState as DBGridControl;
      }

      if (currentDbGridControl != null) {
        shouldShowDbGridControls = true; // Controlli generali DBGrid (refresh, toggle)

        // Logica per la search bar:
        // Modifica questa condizione se hai un modo diverso per abilitare la ricerca
        // per una specifica istanza di DBGrid. Per ora, assumiamo che sia sempre
        // abilitata se shouldShowDbGridControls è true.
        canShowSearchBar = true;

        if (currentGridConfig.uiModes.length > 1) {
          final currentMode = currentDbGridControl.currentDisplayUIMode;
          if (currentMode == UIMode.grid) {
            currentToggleIcon = Icons.article_outlined;
            currentToggleTooltip = "Passa a vista modulo";
          } else if (currentMode == UIMode.form) {
            int currentIndex = currentGridConfig.uiModes.indexOf(currentMode);
            int nextIndex = (currentIndex + 1) % currentGridConfig.uiModes.length;
            UIMode nextMode = currentGridConfig.uiModes[nextIndex];

            if (nextMode == UIMode.grid) {
              currentToggleIcon = Icons.grid_view_rounded;
              currentToggleTooltip = "Passa a vista griglia";
            } else if (nextMode == UIMode.map) {
              currentToggleIcon = Icons.map_outlined;
              currentToggleTooltip = "Passa a vista mappa";
            } else {
              currentToggleIcon = Icons.grid_view_rounded;
              currentToggleTooltip = "Passa a vista griglia";
            }
          } else if (currentMode == UIMode.map) {
            currentToggleIcon = Icons.grid_view_rounded;
            currentToggleTooltip = "Passa a vista griglia";
          }
        } else {
          // Se c'è solo una modalità, non mostrare il toggle
          // ma potresti voler mostrare comunque refresh e search.
          // shouldShowDbGridControls rimane true per refresh.
        }
      }
    }

    return Scaffold(
      drawer: _buildDrawer(context, drawerWidth, starGraphicSize, starRadius),
      body: Column(
        children: [
          Material(
            elevation: 1.0,
            color: Theme.of(context).appBarTheme.backgroundColor ?? Theme.of(context).canvasColor,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              height: kToolbarHeight,
              child: Row(
                children: [
                  Builder(builder: (BuildContext innerContext) {
                    return IconButton(
                      tooltip: "Apri menù",
                      icon: const Icon(Icons.menu),
                      onPressed: () => Scaffold.of(innerContext).openDrawer(),
                    );
                  }),
                  const SizedBox(width: 8),
                  const FlutterLogo(size: 24),
                  const SizedBox(width: 8),
                  const Text('Una Social', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.screenName,
                      style: const TextStyle(fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  if (canShowSearchBar) searchBar, // Usa la nuova variabile
                  if (shouldShowDbGridControls)
                    IconButton(
                      key: const Key('reloadButton'),
                      tooltip: "Ricarica Dati",
                      icon: const Icon(Icons.refresh),
                      onPressed: () {
                        if (currentDbGridControl != null) {
                          currentDbGridControl.refreshData();
                          logInfo("Refresh data for DBGrid triggered from HomeScreen.");
                        } else {
                          ctrl.reload();
                          logInfo("General reload triggered from HomeScreen (no DBGridControl).");
                        }
                      },
                    ),
                  if (shouldShowDbGridControls && currentGridConfig != null && currentGridConfig.uiModes.length > 1)
                    IconButton(
                      key: const Key('toggleViewButton'),
                      tooltip: currentToggleTooltip,
                      icon: Icon(currentToggleIcon),
                      onPressed: _handleToggleView,
                    ),
                  const SizedBox(width: 10),
                  Obx(() {
                    final personaleFromDb = ctrl.personale.value;
                    final authUser = Supabase.instance.client.auth.currentUser;
                    final currentMessage = ctrl.message.value;

                    if (authUser == null) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: _buildDefaultAvatar(context, "Utente non autenticato"),
                      );
                    }

                    bool isLoadingProfile = personaleFromDb == null && (currentMessage == 'Caricamento dati utente...' || currentMessage == 'Ricaricamento...' || currentMessage.isEmpty && ctrl.personale.value == null);
                    if (isLoadingProfile) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8.0),
                        child: SizedBox(width: 36, height: 36, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
                      );
                    }

                    bool hasLoadError = personaleFromDb == null && currentMessage.toLowerCase().contains('errore') && currentMessage != 'Profilo personale non trovato.';
                    if (hasLoadError) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Tooltip(message: "Errore: $currentMessage", child: _buildDefaultAvatar(context, "Errore controller: $currentMessage")),
                      );
                    }

                    return FutureBuilder<String?>(
                      key: ValueKey('avatar_${authUser.id}_${personaleFromDb?.photoUrl}'),
                      future: _getSignedAvatarUrl(personaleFromDb, authUser.email!, currentMessage),
                      builder: (context, snapshot) {
                        Widget avatarWidget;
                        Personale? effectivePersonaleForFallback = personaleFromDb;

                        if (snapshot.connectionState == ConnectionState.waiting) {
                          avatarWidget = const CircleAvatar(radius: 18, child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)));
                        } else if (snapshot.hasError) {
                          avatarWidget = _buildAvatarFromFallback(context, effectivePersonaleForFallback);
                        } else if (snapshot.hasData && snapshot.data != null && snapshot.data!.isNotEmpty) {
                          avatarWidget = _buildAvatarFromUrl(context, snapshot.data!, true, effectivePersonaleForFallback);
                        } else {
                          avatarWidget = _buildAvatarFromFallback(context, effectivePersonaleForFallback);
                        }

                        final List<PopupMenuEntry<ProfileAction>> menuItems = [];
                        if (personaleFromDb != null) {
                          menuItems.add(const PopupMenuItem<ProfileAction>(
                              value: ProfileAction.edit, child: ListTile(leading: Icon(Icons.edit_outlined, size: 20), title: Text('Modifica profilo', style: TextStyle(fontSize: 14)), contentPadding: EdgeInsets.symmetric(horizontal: 8), dense: true)));
                          menuItems.add(const PopupMenuDivider(height: 1));
                        }
                        menuItems.addAll([
                          const PopupMenuItem<ProfileAction>(
                              value: ProfileAction.version, child: ListTile(leading: Icon(Icons.track_changes, size: 20), title: Text('Versione', style: TextStyle(fontSize: 14)), contentPadding: EdgeInsets.symmetric(horizontal: 8), dense: true)),
                          const PopupMenuItem<ProfileAction>(
                              value: ProfileAction.logout,
                              child: ListTile(
                                  leading: Icon(Icons.exit_to_app, color: Colors.redAccent, size: 20), title: Text('Esci', style: TextStyle(color: Colors.redAccent, fontSize: 14)), contentPadding: EdgeInsets.symmetric(horizontal: 8), dense: true)),
                        ]);

                        return PopupMenuButton<ProfileAction>(
                          tooltip: "Opzioni Profilo",
                          itemBuilder: (BuildContext context) => menuItems,
                          onSelected: (ProfileAction action) {
                            switch (action) {
                              case ProfileAction.edit:
                                if (personaleFromDb != null) {
                                  _showProfileDialog(context, personaleFromDb);
                                } else {
                                  _showSnackbar(context, "Dati utente non disponibili per la modifica.", isError: true);
                                }
                                break;
                              case ProfileAction.logout:
                                AuthHelper.setLogoutReason(LogoutReason.userInitiated);
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  if (mounted) {
                                    Future.delayed(const Duration(milliseconds: 50), () {
                                      if (mounted) {
                                        Supabase.instance.client.auth.signOut().then((_) {}).catchError((error, stackTrace) {
                                          if (mounted) {
                                            AuthHelper.clearLastLogoutReason();
                                          }
                                        });
                                      }
                                    });
                                  }
                                });
                                break;
                              case ProfileAction.version:
                                _showVersionDialog(context, ctrl.appVersion.value);
                            }
                          },
                          offset: const Offset(0, kToolbarHeight * 0.8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0),
                            child: avatarWidget,
                          ),
                        );
                      },
                    );
                  }),
                  const SizedBox(width: 10),
                ],
              ),
            ),
          ),
          Expanded(
            child: widget.child,
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            height: 35,
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
              color: Theme.of(context).colorScheme.surface,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Obx(
                    () => Tooltip(
                      message: ctrl.message.value,
                      child: Text(
                        ctrl.message.value.isEmpty ? 'Pronto.' : ctrl.message.value,
                        style: Theme.of(context).textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Obx(
                  () => Text(
                    '${ctrl.connectedUsers.value} utenti',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                const SizedBox(width: 10),
                Obx(() => TextButton(
                      style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                      onPressed: () {
                        showAboutDialog(
                          context: context,
                          applicationName: 'Una Social',
                          applicationVersion: ctrl.appVersion.value.isNotEmpty ? ctrl.appVersion.value : 'N/A',
                        );
                      },
                      child: Text(
                        'v${ctrl.appVersion.value.isNotEmpty ? ctrl.appVersion.value : "N/A"}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.secondary),
                      ),
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
