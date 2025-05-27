// ignore_for_file: avoid_print, deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:una_social_app/controllers/personale_controller.dart';
import 'package:una_social_app/helpers/auth_helper.dart';
import 'package:una_social_app/models/personale.dart';
import 'package:una_social_app/painters/star_painter.dart';
import 'package:una_social_app/screens/personale_profile.dart';

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

  // Initialize GetX Controller
  final PersonaleController ctrl = Get.put(PersonaleController());
  // State for toggling grid/list view (if applicable to child)
  bool gridView = false;

  @override
  void initState() {
    super.initState();
    _initPackageInfo();
  }

  Future<void> _initPackageInfo() async {
    final PackageInfo info = await PackageInfo.fromPlatform();
    setState(() {
      _appVersion = info.version;
      _buildNumber = info.buildNumber;
    });
  }

  // Method to toggle the view state
  void _toggleView() => setState(() => gridView = !gridView);

  // --- Helper function to show the version view dialog ---
  void _showVersionDialog(BuildContext context, String value) {
    String displayVersion = 'Versione: $_appVersion';
    if (_buildNumber.isNotEmpty && _buildNumber != "0") {
      // "0" è il default se non c'è +X
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

  // --- Helper function to show the profile editing dialog ---
  void _showProfileDialog(BuildContext context, Personale currentUser) {
    showDialog(
      context: context,
      // Consider barrierDismissible: true if you want users to tap outside to close
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Modifica Profilo'),
          // Use scrollable content if PersonaleProfile might overflow
          contentPadding: EdgeInsets.zero,
          scrollable: true, // Makes content scrollable if needed
          content: SizedBox(
            // Adjust width constraints as needed, especially for desktop
            width: MediaQuery.of(context).size.width * 0.6, // Example width
            // Pass the current user data to the editing widget
            child: PersonaleProfile(initialPersonale: currentUser),
          ),
        );
      },
    );
  }

  // --- Helper function to show snackbars safely after build ---
  void _showSnackbar(BuildContext ctx, String message, {bool isError = false}) {
    if (!ctx.mounted) return; // Check if context is still valid
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!ctx.mounted) return; // Double check after callback delay
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.redAccent : Colors.green, // Use green for success?
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating, // Optional: makes it float
        ),
      );
    });
  }

  // --- Helper function to generate the Supabase signed URL ---
  Future<String?> _getSignedAvatarUrl(Personale currentUser) async {
    // Se currentUser.photoUrl è null o vuoto, procedi a generare la signed URL.
    // Altrimenti, usa il photoUrl esistente (che potrebbe essere un fallback o una URL già funzionante)
    if (currentUser.photoUrl != null && currentUser.photoUrl!.isNotEmpty) {
      //print("HomeScreen - _getSignedAvatarUrl: Using existing photoUrl: ${currentUser.photoUrl}");
      return currentUser.photoUrl; // Restituisci la URL esistente
    }

    //print('HomeScreen: _getSignedAvatarUrl: Generazione URL firmato per l'avatar di ${currentUser.nome} ${currentUser.cognome} (${currentUser.id})');
    // ... resto della logica per generare la signed URL ...
    final ente = currentUser.ente;
    final id = currentUser.id;

    if (ente.isEmpty || id <= 0) {
      //print("HomeScreen - _getSignedAvatarUrl: Dati insufficienti (ente o id mancanti).");
      return null;
    }

    final String imagePath = 'personale/foto/${ente}_$id.jpg';
    const String bucketName = 'una-bucket';
    const int expiresIn = 86400 * 365 * 50; // token temporaneo di 50 anni (in secondi) !!!!
    try {
      final supabase = Supabase.instance.client;
      final signedUrl = await supabase.storage.from(bucketName).createSignedUrl(imagePath, expiresIn);
      //print("HomeScreen - _getSignedAvatarUrl: URL firmato generato: $signedUrl");
      // NON aggiornare currentUser.photoUrl qui con la signed URL temporanea.
      return signedUrl;
    } on StorageException catch (e) {
      // Questa eccezione avviene se createSignedUrl stesso fallisce (es. bucket non trovato, o a volte per oggetto non trovato)
      print("HomeScreen - _getSignedAvatarUrl: StorageException durante createSignedUrl per $imagePath: ${e.message} (StatusCode: ${e.statusCode})");
      return null; // Indica che la generazione della URL è fallita
    } catch (e, stackTrace) {
      print("HomeScreen - _getSignedAvatarUrl: Errore imprevisto durante createSignedUrl per $imagePath: $e\nStackTrace: $stackTrace");
      return null;
    }
  }

  // --- Widget to build the avatar from a given URL (signed or fallback) ---
  Widget _buildAvatarFromUrl(BuildContext context, String url, bool isSignedUrlAttempt, Personale personale) {
    final bool hasValidUrl = Uri.tryParse(url)?.hasAbsolutePath ?? false;

    // AGGIUNTA LOG
    print("HomeScreen - _buildAvatarFromUrl: Attempting to load. Valid URL: $hasValidUrl, isSignedUrlAttempt: $isSignedUrlAttempt, URL: $url");

    if (!hasValidUrl) {
      print("HomeScreen - _buildAvatarFromUrl: URL non valido fornito: $url");
      return isSignedUrlAttempt ? _buildAvatarFromFallback(context, personale) : _buildDefaultAvatar(context, "URL fallback non valido ($url)");
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
            // AGGIUNTA LOG
            print("HomeScreen - _buildAvatarFromUrl - errorBuilder: Error loading. isSignedUrlAttempt: $isSignedUrlAttempt, URL: '$url', Error: $error");

            if (isSignedUrlAttempt) {
              // Non chiamare _showSnackbar qui per ora, per semplificare il debug
              // _showSnackbar(context, "Errore immagine Supabase, uso fallback...", isError: true);
              return _buildAvatarFromFallback(context, personale);
            } else {
              // _showSnackbar(context, "Errore immagine fallback, uso icona default.", isError: true);
              return _buildDefaultAvatar(context, "Errore fallback ($url)");
            }
          },
        ),
      ),
    );
  }

  // --- Widget to attempt building the avatar using the fallback URL from Personale model ---
  Widget _buildAvatarFromFallback(BuildContext context, Personale personale) {
    final String? fallbackUrl = personale.photoUrl; // Get fallback URL from model
    final bool hasValidFallback = fallbackUrl != null && fallbackUrl.isNotEmpty && (Uri.tryParse(fallbackUrl)?.hasAbsolutePath ?? false);

    if (hasValidFallback) {
      //print("Tentativo con URL fallback: $fallbackUrl");
      // Call the main URL builder, indicating it's NOT a signed URL attempt
      return _buildAvatarFromUrl(context, fallbackUrl, false, personale);
    } else {
      //print("Nessun URL fallback valido trovato (${fallbackUrl ?? 'null'}), uso icona default.");
      // No snackbar here, as the previous step might have shown one
      return _buildDefaultAvatar(context, "No fallback"); // Return default if no valid fallback
    }
  }

  // --- Widget to build the default placeholder avatar ---
  Widget _buildDefaultAvatar(BuildContext context, String reason) {
    // AGGIUNTA LOG
    print("HomeScreen - _buildDefaultAvatar: Costruzione avatar default. Reason: $reason");
    return CircleAvatar(
      radius: 18,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      child: Icon(Icons.person_outline, size: 18, color: Theme.of(context).colorScheme.onPrimaryContainer),
    );
  }

  // --- Helper method to build the Drawer widget ---
  // This method encapsulates the drawer creation logic
  Widget _buildDrawer(BuildContext context, double drawerWidth, double starGraphicSize, double starRadius) {
    return Drawer(
      child: SizedBox(
        width: drawerWidth,
        child: SafeArea(
          // Avoids status bar/notch overlap
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            // IMPORTANT: Builder provides the correct context for Navigator.pop
            child: Builder(
              builder: (BuildContext drawerContext) {
                // Context BELOW the Scaffold
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Star Graphic
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
                    // Title
                    Text('Una Social', style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                    const SizedBox(height: 8),
                    const Divider(), // Separator
                    const SizedBox(height: 8),
                    // Menu Items
                    ListTile(
                      leading: const Icon(Icons.home_outlined, color: primaryBlue), // Example: Home icon
                      title: const Text('Home'), // Example: Home item
                      onTap: () {
                        Navigator.pop(drawerContext); // Use drawerContext to close
                        GoRouter.of(drawerContext).go('/home'); // Navigate
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.storage_rounded, color: primaryBlue),
                      title: const Text('Database'),
                      onTap: () {
                        Navigator.pop(drawerContext); // Use drawerContext to close
                        GoRouter.of(drawerContext).push('/database'); // Navigate
                      },
                    ),
                    // Add more ListTiles for other sections...

                    const Spacer(), // Pushes following items to the bottom
                    const Divider(),
                    // App Info Item
                    ListTile(
                      leading: const Icon(Icons.info_outline, color: Colors.grey),
                      title: const Text('App Info', style: TextStyle(color: Colors.grey)),
                      onTap: () {
                        Navigator.pop(drawerContext); // Use drawerContext to close
                        // Show About Dialog
                        showAboutDialog(
                          context: context, // Use the main context here is fine
                          applicationName: 'Una Social',
                          applicationVersion: ctrl.appVersion.value.isNotEmpty ? ctrl.appVersion.value : 'N/A',
                          // applicationIcon: FlutterLogo(), // Optional icon
                          // children: [...], // Optional extra info
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
    // This is the 'outer' context
    // Calculate drawer width based on screen size
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isDesktop = screenWidth > 600; // Example breakpoint
    final double drawerWidth = isDesktop ? 200.0 : screenWidth * 0.8;

    // Define sizes for the star graphic in the drawer
    const double starGraphicSize = 80.0;
    const double starRadius = starGraphicSize / 2 * 0.8;

    // Define the Search Bar widget separately for clarity
    Widget searchBar = Expanded(
      // Use Expanded to allow shrinking
      child: Container(
        constraints: const BoxConstraints(maxWidth: 250), // Max width for search
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: TextField(
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
            //print("Search submitted: $value");
          },
        ),
      ),
    );

    // --- Main Scaffold Structure ---
    return Scaffold(
      // Assign the drawer using the helper method
      drawer: _buildDrawer(context, drawerWidth, starGraphicSize, starRadius),
      // Body is a Column containing AppBar, Content, Status Bar
      body: Column(
        children: [
          // --- Top Row (AppBar Simulation) ---
          Material(
            // Provides elevation/shadow like AppBar
            elevation: 1.0, // Subtle shadow
            color: Theme.of(context).appBarTheme.backgroundColor ?? Theme.of(context).canvasColor,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              height: kToolbarHeight, // Standard AppBar height
              // Use SafeArea for top padding if needed, depends on design
              // child: SafeArea( // Uncomment if content goes under status bar
              child: Row(
                children: [
                  // --- Menu Button ---
                  Builder(// IMPORTANT: Provides context below Scaffold
                      builder: (BuildContext innerContext) {
                    // Context for Scaffold.of
                    return IconButton(
                      tooltip: "Apri menù",
                      icon: const Icon(Icons.menu),
                      onPressed: () => Scaffold.of(innerContext).openDrawer(), // Use innerContext
                    );
                  }),
                  const SizedBox(width: 8),
                  // --- Logo and Title ---
                  const FlutterLogo(size: 24),
                  const SizedBox(width: 8),
                  const Text('Una Social', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 12),
                  // --- Screen Name ---
                  Expanded(
                    child: Text(
                      widget.screenName, // Display current screen name
                      style: const TextStyle(fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  // --- Search Bar ---
                  searchBar,
                  // --- Action Buttons ---
                  IconButton(
                    tooltip: "Ricarica Dati Utente",
                    icon: const Icon(Icons.refresh),
                    onPressed: ctrl.reload, // Call controller's reload method
                  ),
                  IconButton(
                    tooltip: gridView ? "Passa a vista elenco" : "Passa a vista griglia",
                    icon: Icon(gridView ? Icons.grid_view_rounded : Icons.view_list_rounded),
                    onPressed: _toggleView, // Toggle local state
                  ),
                  IconButton(
                    tooltip: "Impostazioni Applicazione",
                    icon: const Icon(Icons.settings_outlined),
                    onPressed: () {
                      _showSnackbar(context, "Impostazioni non implementate.");
                      // TODO: Navigate to settings screen: GoRouter.of(context).push('/settings');
                    },
                  ),
                  const SizedBox(width: 10),

                  // --- Profile Avatar and Menu ---
                  Obx(() {
                    // Listens to the personale data in the controller
                    final personale = ctrl.personale.value;

                    // State 1: Controller is loading or has error initially
                    if (personale == null) {
                      if (ctrl.message.value.toLowerCase().contains('errore')) {
                        // Controller loaded with an error state
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Tooltip(
                              // Show error on hover
                              message: "Errore caricamento: ${ctrl.message.value}",
                              child: _buildDefaultAvatar(context, "Errore controller")),
                        );
                      } else {
                        // Controller is still loading initial data
                        return const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8.0),
                          child: SizedBox(
                            width: 36,
                            height: 36,
                            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                          ),
                        );
                      }
                    }

                    // State 2: Personale data exists, fetch signed URL
                    return FutureBuilder<String?>(
                      // Key ensures refetch if user ID changes (e.g., after edit/reload)
                      key: ValueKey('avatar_${personale.id}'),
                      future: _getSignedAvatarUrl(personale),
                      builder: (context, snapshot) {
                        Widget avatarWidget; // The widget to display (avatar or loading)

                        // Determine avatar based on FutureBuilder state
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          avatarWidget = const CircleAvatar(radius: 18, child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)));
                        } else if (snapshot.hasError) {
                          // Error getting signed URL, attempt fallback
                          avatarWidget = _buildAvatarFromFallback(context, personale);
                        } else if (snapshot.hasData && snapshot.data != null && snapshot.data!.isNotEmpty) {
                          // Got a signed URL, attempt to display it
                          avatarWidget = _buildAvatarFromUrl(context, snapshot.data!, true, personale);
                        } else {
                          // Future completed but no valid signed URL returned, attempt fallback
                          avatarWidget = _buildAvatarFromFallback(context, personale);
                        }

                        // Wrap the determined avatar in the PopupMenuButton
                        return PopupMenuButton<ProfileAction>(
                          tooltip: "Opzioni Profilo",
                          // Builds the menu items
                          itemBuilder: (BuildContext context) => <PopupMenuEntry<ProfileAction>>[
                            const PopupMenuItem<ProfileAction>(
                                value: ProfileAction.edit, child: ListTile(leading: Icon(Icons.edit_outlined, size: 20), title: Text('Modifica profilo', style: TextStyle(fontSize: 14)), contentPadding: EdgeInsets.symmetric(horizontal: 8), dense: true)),
                            const PopupMenuDivider(height: 1),
                            const PopupMenuItem<ProfileAction>(
                                value: ProfileAction.version, child: ListTile(leading: Icon(Icons.track_changes, size: 20), title: Text('Versione', style: TextStyle(fontSize: 14)), contentPadding: EdgeInsets.symmetric(horizontal: 8), dense: true)),
                            const PopupMenuItem<ProfileAction>(
                                value: ProfileAction.logout,
                                child: ListTile(
                                    leading: Icon(Icons.exit_to_app, color: Colors.redAccent, size: 20), title: Text('Esci', style: TextStyle(color: Colors.redAccent, fontSize: 14)), contentPadding: EdgeInsets.symmetric(horizontal: 8), dense: true)),
                          ],
                          // Handles menu item selection
                          onSelected: (ProfileAction action) async {
                            switch (action) {
                              case ProfileAction.edit:
                                if (ctrl.personale.value != null) {
                                  // Use the main context for dialogs
                                  _showProfileDialog(context, ctrl.personale.value!);
                                } else {
                                  _showSnackbar(context, "Dati utente non disponibili.", isError: true);
                                }
                                break;
                              case ProfileAction.logout:
                                AuthHelper.setLogoutReason(LogoutReason.userInitiated);
                                //print("[HomeScreen] Logout: Avvio signOut (fire and forget)...");

                                // Chiamiamo signOut() ma non attendiamo (await) il suo completamento qui
                                // per evitare di mantenere il contesto del PopupMenuButton attivo
                                // mentre il widget potrebbe essere smontato.
                                Supabase.instance.client.auth.signOut().then((_) {
                                  //print("[HomeScreen] Logout: signOut promise completata (successo o fallimento gestito internamente da Supabase/listener).");
                                  // Non fare nulla qui che dipenda dal context di HomeScreen,
                                  // perché GoRouter dovrebbe aver già gestito il redirect.
                                  // Se il widget è ancora montato e si vuole mostrare un messaggio di successo (raro per il logout),
                                  // bisognerebbe farlo con cautela e controlli 'mounted'.
                                }).catchError((error, stackTrace) {
                                  //print("[HomeScreen] Logout: Errore esplicito durante signOut(): $error\nStack: $stackTrace");
                                  AuthHelper.clearLastLogoutReason(); // Pulisci solo se il signOut stesso fallisce

                                  // È rischioso usare 'context' qui perché il widget potrebbe essere smontato.
                                  // Loggare l'errore è la cosa più sicura.
                                  // Se si volesse tentare una Snackbar, bisognerebbe farlo con estrema cautela:
                                  // if (mounted && context.findRenderObject() != null && context.findRenderObject()!.attached) {
                                  //   if (error is AuthException) {
                                  //     SnackbarHelper.showErrorSnackbar(context, "Errore logout: ${error.message}");
                                  //   } else if (!error.toString().contains("Looking up a deactivated widget's ancestor is unsafe")) {
                                  //     SnackbarHelper.showErrorSnackbar(context, "Errore logout inatteso.");
                                  //   }
                                  // }
                                });

                                // A questo punto, il PopupMenuButton si chiuderà normalmente.
                                // L'evento onAuthStateChange (ascoltato da GoRouter e dal PersonaleController)
                                // si occuperà della navigazione e della pulizia dello stato.
                                break;
                              case ProfileAction.version:
                                _showVersionDialog(context, ctrl.appVersion.value); // Show version dialog
                            }
                          },
                          offset: const Offset(0, kToolbarHeight * 0.8), // Position menu below button
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          // The child is the avatar itself, which triggers the menu
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0),
                            child: avatarWidget, // Display the avatar (or loading)
                          ),
                        );
                      },
                    );
                  }), // End Obx for profile avatar
                  const SizedBox(width: 10),
                ],
              ),
              //  ), // End SafeArea
            ),
          ), // End AppBar Row

          // --- Main Content Area ---
          Expanded(
            // The main content takes the remaining vertical space
            child: widget.child, // Display the child widget passed to HomeScreen
          ),

          // --- Bottom Row (Status Bar) ---
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            height: 35, // Compact height
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
              color: Theme.of(context).colorScheme.surface, // Use theme surface color
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Status Message (from controller)
                Expanded(
                  child: Obx(
                    // Listens to controller's message
                    () => Tooltip(
                      message: ctrl.message.value, // Full message on hover
                      child: Text(
                        ctrl.message.value.isEmpty ? 'Pronto.' : ctrl.message.value, // Show default if empty
                        style: Theme.of(context).textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis, // Prevent overflow
                        maxLines: 1,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10), // Spacer
                // Connected Users Count (from controller)
                Obx(
                  // Listens to connected users count
                  () => Text(
                    '${ctrl.connectedUsers.value} utenti',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                const SizedBox(width: 10), // Spacer
                // App Version (from controller)
                Obx(() => TextButton(
                      // Make version clickable for AboutDialog
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
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.secondary), // Use accent color
                      ),
                    )),
              ],
            ),
          ), // End Status Bar
        ],
      ),
    );
  }
}
