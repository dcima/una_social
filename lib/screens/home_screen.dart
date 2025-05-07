// ignore_for_file: avoid_print, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:una_social_app/controllers/personale_controller.dart';
import 'package:una_social_app/models/personale.dart'; // Make sure Personale has universita and id fields
import 'package:una_social_app/screens/personale/personale_profile.dart'; // Import the profile editing screen/dialog
import 'package:una_social_app/painters/star_painter.dart'; // Adjust path as needed

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
          // Actions might be needed if PersonaleProfile doesn't have its own save/cancel
          actions: <Widget>[
            TextButton(
              child: const Text('Annulla'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            // Add a Save button here if PersonaleProfile doesn't handle saving itself
            // TextButton(
            //   child: const Text('Salva'),
            //   onPressed: () { /* TODO: Trigger save logic in PersonaleProfile */ Navigator.of(dialogContext).pop(); },
            // ),
          ],
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
  Future<String?> _getSignedAvatarUrl(Personale personale) async {
    // Adjust field names to match your Personale model exactly
    final universita = personale.universita;
    final id = personale.id;

    // Validate necessary data for path construction
    if (universita.isEmpty || id <= 0) {
      print("Dati insufficienti per generare il percorso Supabase (universita o id mancanti).");
      return null;
    }

    // Construct the storage path EXACTLY matching your bucket structure
    final String imagePath = 'personale/foto/${universita}_$id.jpg'; // Example: 'personale/foto/UNIBO_36941.jpg'
    const String bucketName = 'una-bucket'; // Your bucket name
    const int expiresIn = 3600; // Signed URL validity duration (seconds)

    try {
      print("Tentativo di generare Signed URL per: $imagePath");
      final supabase = Supabase.instance.client;

      // Optional: Check if the file actually exists before generating the URL
      // This prevents generating URLs for non-existent files but adds latency.
      // try {
      //   await supabase.storage.from(bucketName).getMetadata(imagePath);
      // } catch (e) {
      //   print("File $imagePath non trovato in $bucketName ($e). Salto generazione Signed URL.");
      //   return null; // File doesn't exist, don't proceed
      // }

      // Generate the signed URL
      final signedUrl = await supabase.storage.from(bucketName).createSignedUrl(imagePath, expiresIn);

      print("Signed URL generato: $signedUrl");
      return signedUrl;
    } on StorageException catch (e) {
      // Catch specific Supabase storage errors
      print("StorageException durante createSignedUrl per $imagePath: ${e.message} (StatusCode: ${e.statusCode})");
      // Handle common errors like object not found (404/400) or access denied (403)
      // if (e.statusCode == '404' || e.statusCode == '400') { ... }
      return null;
    } catch (e, stackTrace) {
      // Catch any other unexpected errors
      print("Errore imprevisto durante createSignedUrl per $imagePath: $e\nStackTrace: $stackTrace");
      return null;
    }
  }

  // --- Widget to build the avatar from a given URL (signed or fallback) ---
  Widget _buildAvatarFromUrl(BuildContext context, String url, bool isSignedUrlAttempt, Personale personale) {
    // Validate the URL before attempting to load
    final bool hasValidUrl = Uri.tryParse(url)?.hasAbsolutePath ?? false;

    if (!hasValidUrl) {
      print("URL non valido fornito a _buildAvatarFromUrl: $url");
      // If the current URL is invalid, determine next step
      return isSignedUrlAttempt
          ? _buildAvatarFromFallback(context, personale) // If signed URL was bad, try fallback
          : _buildDefaultAvatar(context, "URL fallback non valido"); // If fallback was also bad, show default
    }

    print("Visualizzazione immagine da URL ${isSignedUrlAttempt ? 'firmato' : 'fallback'}: $url");

    return CircleAvatar(
      radius: 18, // Matches desired size
      backgroundColor: Theme.of(context).colorScheme.surfaceVariant, // Placeholder bg
      child: ClipOval(
        // Ensures the image is clipped to a circle
        child: Image.network(
          url,
          key: ValueKey(url), // Important for updating image if URL changes
          width: 36, // Double the radius
          height: 36,
          fit: BoxFit.cover, // Covers the circle area, cropping if necessary
          // Shows loading progress
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child; // Image loaded, show it
            return Center(
              // Show progress indicator while loading
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, value: loadingProgress.expectedTotalBytes != null ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes! : null),
              ),
            );
          },
          // Handles errors during image loading
          errorBuilder: (context, error, stackTrace) {
            print("Errore caricamento NetworkImage (${isSignedUrlAttempt ? 'firmato' : 'fallback'} '$url'): $error");
            if (isSignedUrlAttempt) {
              // If loading the SIGNED URL failed, try the fallback URL
              _showSnackbar(context, "Errore immagine Supabase, uso fallback...", isError: true);
              return _buildAvatarFromFallback(context, personale); // Return the fallback attempt
            } else {
              // If loading the FALLBACK URL also failed, show the default avatar
              _showSnackbar(context, "Errore immagine fallback, uso icona default.", isError: true);
              return _buildDefaultAvatar(context, "Errore fallback"); // Return the default icon
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
      print("Tentativo con URL fallback: $fallbackUrl");
      // Call the main URL builder, indicating it's NOT a signed URL attempt
      return _buildAvatarFromUrl(context, fallbackUrl, false, personale);
    } else {
      print("Nessun URL fallback valido trovato (${fallbackUrl ?? 'null'}), uso icona default.");
      // No snackbar here, as the previous step might have shown one
      return _buildDefaultAvatar(context, "No fallback"); // Return default if no valid fallback
    }
  }

  // --- Widget to build the default placeholder avatar ---
  Widget _buildDefaultAvatar(BuildContext context, String reason) {
    print("Costruzione avatar default (Motivo: $reason)");
    // Returns a simple CircleAvatar with an icon
    return CircleAvatar(
      radius: 18,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer, // Use theme color
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
            /* TODO: Implement search functionality */ print("Search submitted: $value");
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
                                try {
                                  await Supabase.instance.client.auth.signOut();
                                  // Use GoRouter to navigate back to login after logout
                                  if (mounted) {
                                    // Ensure widget is still in tree
                                    GoRouter.of(context).go('/login');
                                  }
                                } catch (e) {
                                  print("Errore durante logout: $e");
                                  if (mounted) {
                                    _showSnackbar(context, "Errore logout: ${e is AuthException ? e.message : e.toString()}", isError: true);
                                  }
                                }
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
