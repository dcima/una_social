// ignore_for_file: avoid_print, deprecated_member_use

import 'dart:typed_data'; // Required for Uint8List if using image_picker >= 1.0 on web/desktop
// import 'dart:io'; // Required for File type if using image_picker < 1.0 on mobile
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:una_social_app/controllers/personale_controller.dart';
import 'package:una_social_app/models/personale.dart';

class PersonaleProfile extends StatefulWidget {
  final Personale initialPersonale;

  const PersonaleProfile({
    super.key,
    required this.initialPersonale,
  });

  @override
  State<PersonaleProfile> createState() => _PersonaleProfileState();
}

class _PersonaleProfileState extends State<PersonaleProfile> {
  final _formKey = GlobalKey<FormState>();
  // Get the *existing* instance of PersonaleController, should be created by HomeScreen
  // Use tryFind in case the dialog is somehow shown before the controller is ready
  final PersonaleController _personaleController = Get.find<PersonaleController>();
  final _supabase = Supabase.instance.client;

  String? _signedImageUrl;
  bool _isLoadingImageUrl = true; // Per mostrare un indicatore durante il fetch dell'URL

  // Text Editing Controllers
  late TextEditingController _nomeController;
  late TextEditingController _cognomeController;
  late TextEditingController _photoUrlController; // For manual URL input
  late TextEditingController _cvController;
  late TextEditingController _noteBiograficheController;
  late TextEditingController _rssController;
  late TextEditingController _webController;
  late TextEditingController _emailController; // Simplified: first email
  late TextEditingController _telefonoController; // Simplified: first phone

  XFile? _pickedImageFile; // Store the picked image file (platform-agnostic)
  bool _isDirty = false; // Track if any changes were made
  bool _isLoading = false; // Track loading state during async operations

  // Bucket and path configuration
  final String _bucketName = 'una-bucket'; // Your bucket name
  final String _baseFolderPath = 'personale/foto'; // Your folder path

  @override
  void initState() {
    super.initState();
    print('_personaleController: $_personaleController');
    print('_personaleController.personale.value: ${_personaleController.personale.value}');

    // Initialize controllers with data from the Personale model
    _nomeController = TextEditingController(text: widget.initialPersonale.nome);
    _cognomeController = TextEditingController(text: widget.initialPersonale.cognome);
    // photoUrlController holds the *manual input/output* URL, not the display logic source
    _photoUrlController = TextEditingController(text: widget.initialPersonale.photoUrl);
    _cvController = TextEditingController(text: widget.initialPersonale.cv);
    _noteBiograficheController = TextEditingController(text: widget.initialPersonale.noteBiografiche);
    _rssController = TextEditingController(text: widget.initialPersonale.rss);
    _webController = TextEditingController(text: widget.initialPersonale.web);
    // Safely get the first item or empty string
    _emailController = TextEditingController(text: widget.initialPersonale.emails.isNotEmpty ? widget.initialPersonale.emails.first : '');
    _telefonoController = TextEditingController(text: widget.initialPersonale.telefoni.isNotEmpty ? widget.initialPersonale.telefoni.first : '');

    // Add listeners to controllers to detect changes
    _nomeController.addListener(_markDirty);
    _cognomeController.addListener(_markDirty);
    _photoUrlController.addListener(_markDirty);
    _cvController.addListener(_markDirty);
    _noteBiograficheController.addListener(_markDirty);
    _rssController.addListener(_markDirty);
    _webController.addListener(_markDirty);
    _emailController.addListener(_markDirty);
    _telefonoController.addListener(_markDirty);

    // Carica l'URL firmato all'inizializzazione del widget
    _fetchSignedImageUrl();
  }

  @override
  void dispose() {
    // Remove listeners first
    _nomeController.removeListener(_markDirty);
    _cognomeController.removeListener(_markDirty);
    _photoUrlController.removeListener(_markDirty);
    _cvController.removeListener(_markDirty);
    _noteBiograficheController.removeListener(_markDirty);
    _rssController.removeListener(_markDirty);
    _webController.removeListener(_markDirty);
    _emailController.removeListener(_markDirty);
    _telefonoController.removeListener(_markDirty);

    // Then dispose controllers
    _nomeController.dispose();
    _cognomeController.dispose();
    _photoUrlController.dispose();
    _cvController.dispose();
    _noteBiograficheController.dispose();
    _rssController.dispose();
    _webController.dispose();
    _emailController.dispose();
    _telefonoController.dispose();
    super.dispose();
  }

  // Funzione per recuperare l'URL firmato
  Future<void> _fetchSignedImageUrl() async {
    if (!mounted) return; // Verifica se il widget è ancora montato
    setState(() {
      _isLoadingImageUrl = true;
      _signedImageUrl = null; // Resetta l'URL precedente
    });

    final personale = _personaleController.personale.value;
    if (personale == null || personale.universita.isEmpty || personale.id <= 0) {
      print("Dati personali insufficienti per generare il percorso immagine.");
      if (mounted) setState(() => _isLoadingImageUrl = false);
      return;
    }

    // Costruisci il percorso esatto dell'oggetto nel bucket
    // *** Assicurati che questo percorso corrisponda ESATTAMENTE alla tua struttura ***
    final String objectPath = 'personale/foto/${personale.universita}_${personale.id}.jpg';
    print("Tentativo di generare Signed URL per: $objectPath");

    try {
      // Genera l'URL firmato con una scadenza (es. 1 ora)
      final String signedUrl = await _supabase.storage
          .from(_bucketName) // _bucketName = 'una-bucket'
          .createSignedUrl(
            objectPath,
            3600, // Scadenza in secondi (1 ora)
            // Opzionale: puoi aggiungere trasformazioni immagine qui
            // transform: TransformOptions(
            //    width: 200,
            //    height: 200,
            // ),
          );

      if (mounted) {
        setState(() {
          _signedImageUrl = signedUrl;
          _isLoadingImageUrl = false;
        });
        print("Signed URL generato: $_signedImageUrl");
      }
    } on StorageException catch (e) {
      print('Errore StorageException nel generare Signed URL per $objectPath: ${e.message}');
      // Gestisci errori specifici (es. Oggetto non trovato - statusCode 404 o 400 comune)
      if (mounted) setState(() => _isLoadingImageUrl = false);
      // Potresti mostrare un messaggio all'utente qui
    } catch (e) {
      print('Errore generico nel generare Signed URL per $objectPath: $e');
      if (mounted) setState(() => _isLoadingImageUrl = false);
    }
  }

  // Sets the _isDirty flag if it's not already set
  void _markDirty() {
    if (!_isDirty && mounted) {
      setState(() {
        _isDirty = true;
      });
    }
  }

  // --- Image Handling ---

  Future<void> _pickAndUploadImage() async {
    if (_isLoading) return; // Prevent concurrent operations

    setState(() => _isLoading = true);
    _pickedImageFile = null; // Clear previous selection

    try {
      final picker = ImagePicker();
      // Pick image from gallery, request reasonable quality/size if needed
      final XFile? picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85, // Adjust JPG quality (0-100)
        // maxWidth: 1024, // Optional: Limit max width
        // maxHeight: 1024, // Optional: Limit max height
      );

      if (picked == null) {
        if (mounted) setState(() => _isLoading = false);
        return; // User cancelled picker
      }

      _pickedImageFile = picked; // Store picked file info

      // Read image data as bytes
      final Uint8List imageBytes = await _pickedImageFile!.readAsBytes();
      // Define the storage path and filename (always JPG)
      final String fileName = '${widget.initialPersonale.universita}_${widget.initialPersonale.id}.jpg';
      print('Caricamento immagine: $fileName, Size: ${imageBytes.length} bytes');
      final String filePath = '$_baseFolderPath/$fileName'; // e.g., personale/foto/UNIBO_36941.jpg
      print('Percorso file: $filePath');

      // Upload the image bytes to Supabase Storage
      // print('Uploading to bucket: $_bucketName, path: $filePath');
      await _supabase.storage.from(_bucketName).uploadBinary(
            filePath,
            imageBytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg', // Force content type to JPG
              upsert: true, // Overwrite existing file with the same name
            ),
          );

      // Get the public URL (assumes the bucket is PUBLIC)
      final String publicUrl = _supabase.storage.from(_bucketName).getPublicUrl(filePath);

      // Update the text controller and mark form as dirty
      if (mounted) {
        _photoUrlController.text = publicUrl; // Update the URL field
        _markDirty(); // Ensure change is registered
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Immagine caricata con successo.'), backgroundColor: Colors.green),
        );
      }
      _pickedImageFile = null; // Clear picked image after successful upload
    } on StorageException catch (e) {
      // Handle Supabase storage specific errors
      print('StorageException: Code: ${e.statusCode}, Message: ${e.message}, Error: ${e.error}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore caricamento immagine: ${e.message} (Code: ${e.statusCode})'), backgroundColor: Colors.red),
        );
      }
    } catch (e, stackTrace) {
      // Handle other potential errors (e.g., file reading, network)
      print('Errore imprevisto durante caricamento immagine: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore imprevisto durante il caricamento: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      // Ensure loading indicator is turned off
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // --- Profile Update ---

  Future<void> _updateProfile() async {
    // Validate form, check if dirty and not already loading
    if (!_isDirty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nessuna modifica rilevata.'), backgroundColor: Colors.orange),
      );
      return;
    }
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return; // Validation failed

    setState(() => _isLoading = true);

    // Prepare the data map for the Supabase update operation
    // Include only the fields that are editable in this form
    final updateData = {
      'nome': _nomeController.text.trim(),
      'cognome': _cognomeController.text.trim(),
      // Use null if URL is empty, otherwise use the trimmed URL
      'photoUrl': _photoUrlController.text.trim().isEmpty ? null : _photoUrlController.text.trim(),
      'cv': _cvController.text.trim().isEmpty ? null : _cvController.text.trim(),
      'noteBiografiche': _noteBiograficheController.text.trim().isEmpty ? null : _noteBiograficheController.text.trim(),
      'rss': _rssController.text.trim().isEmpty ? null : _rssController.text.trim(),
      'web': _webController.text.trim().isEmpty ? null : _webController.text.trim(),
      // Simplified list handling: assumes single email/phone update
      // For proper list editing, a more complex UI is needed
      'emails': _emailController.text.trim().isEmpty ? [] : [_emailController.text.trim()],
      'telefoni': _telefonoController.text.trim().isEmpty ? [] : [_telefonoController.text.trim()],
      // DO NOT include non-editable fields like 'id', 'universita', 'struttura' here
    };

    try {
      // Perform the update operation targeting the specific user ID
      print('updateData: $updateData');
      await _supabase.from('personale').update(updateData).eq('id', widget.initialPersonale.id); // Match the correct record

      // Success feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profilo aggiornato con successo!'), backgroundColor: Colors.green),
        );
        // Reload data in the main controller to reflect changes globally
        await _personaleController.reload();
        // Close the dialog
        Navigator.of(context).pop();
      }
    } on PostgrestException catch (e) {
      // Handle Supabase database errors
      print('PostgrestException on update: Code: ${e.code}, Message: ${e.message}, Details: ${e.details}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore aggiornamento database: ${e.message}'), backgroundColor: Colors.red),
        );
      }
    } catch (e, stackTrace) {
      // Handle other potential errors
      print('Errore imprevisto durante l\'aggiornamento: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore imprevisto durante l\'aggiornamento: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      // Ensure loading indicator is turned off
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // --- Build Method ---

  @override
  Widget build(BuildContext context) {
    // Central widget for displaying the current profile photo
    // Uses Obx to react to changes in the PersonaleController's data
    Widget currentPhotoDisplay = SizedBox(
      height: 100,
      width: 100,
      child: Builder(
        // Usa Builder per accedere allo stato aggiornato
        builder: (context) {
          if (_isLoadingImageUrl) {
            return const Center(child: CircularProgressIndicator(strokeWidth: 2));
          }

          if (_photoUrlController.text.isNotEmpty) {
            // Usa l'URL manuale se fornito e valido
            final bool hasValidManualUrl = _photoUrlController.text.trim().isNotEmpty && Uri.tryParse(_photoUrlController.text.trim())?.hasAbsolutePath == true;
            if (hasValidManualUrl) {
              print("Visualizzazione immagine da URL manuale: ${_photoUrlController.text}");
              return CircleAvatar(
                key: ValueKey(_photoUrlController.text), // Key per aggiornamento
                radius: 50,
                backgroundImage: NetworkImage(_photoUrlController.text.trim()),
                onBackgroundImageError: (exception, stackTrace) {
                  print("Errore caricamento NetworkImage (manual): $exception");
                  // setState(() => _photoUrlController.text = ''); // Potrebbe causare loop se l'errore persiste
                },
              );
            }
          } else {
            // Usa l'URL firmato se disponibile e valido
            final bool hasValidSignedUrl = _signedImageUrl != null && _signedImageUrl!.isNotEmpty && Uri.tryParse(_signedImageUrl!)?.hasAbsolutePath == true;

            if (hasValidSignedUrl) {
              print("Visualizzazione immagine da Signed URL: $_signedImageUrl");
              return CircleAvatar(
                key: ValueKey(_signedImageUrl), // Key per aggiornamento
                radius: 50,
                backgroundImage: NetworkImage(_signedImageUrl!),
                onBackgroundImageError: (exception, stackTrace) {
                  print("Errore caricamento NetworkImage (Signed URL): $exception");
                  // Considera di mostrare un placeholder in caso di errore qui
                  // setState(() => _signedImageUrl = null); // Potrebbe causare loop se l'errore persiste
                },
              );
            } else {
              print("Nessun Signed URL valido disponibile, mostro placeholder.");
            }
          }
          // Fallback a placeholder se l'URL non è stato caricato o non è valido
          return const CircleAvatar(radius: 50, child: Icon(Icons.person, size: 50));
        },
      ),
    );
    // Main widget structure
    return Stack(
      // Use Stack to overlay the loading indicator
      children: [
        Form(
          key: _formKey,
          child: SingleChildScrollView(
            // Allows scrolling if content overflows
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min, // Fit content in dialog
              crossAxisAlignment: CrossAxisAlignment.stretch, // Stretch fields horizontally
              children: [
                // Photo display and upload button
                Center(child: currentPhotoDisplay),
                const SizedBox(height: 10),
                Center(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Carica Nuova Foto'),
                    onPressed: _isLoading ? null : _pickAndUploadImage, // Disable while loading
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
                  ),
                ),
                const SizedBox(height: 15),

                // --- Form Fields ---

                // Photo URL (Manual Input)
                TextFormField(
                  controller: _photoUrlController,
                  decoration: const InputDecoration(
                    labelText: 'Photo URL',
                    hintText: 'URL immagine (o carica sopra)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.link),
                  ),
                  keyboardType: TextInputType.url,
                  validator: (value) {
                    // Validate URL format if not empty
                    if (value != null && value.trim().isNotEmpty) {
                      if (Uri.tryParse(value.trim())?.hasAbsolutePath != true) {
                        return 'Inserisci un URL valido';
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 15),

                // Nome & Cognome
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start, // Align validators
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _nomeController,
                        decoration: const InputDecoration(labelText: 'Nome', border: OutlineInputBorder()),
                        textCapitalization: TextCapitalization.words,
                        validator: (value) => (value == null || value.trim().isEmpty) ? 'Il nome è obbligatorio' : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _cognomeController,
                        decoration: const InputDecoration(labelText: 'Cognome', border: OutlineInputBorder()),
                        textCapitalization: TextCapitalization.words,
                        validator: (value) => (value == null || value.trim().isEmpty) ? 'Il cognome è obbligatorio' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),

                // Email (Simplified: first one)
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Email Principale', border: OutlineInputBorder(), prefixIcon: Icon(Icons.email)),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'L\'email è obbligatoria';
                    if (!GetUtils.isEmail(value.trim())) return 'Formato email non valido'; // Use GetX validation
                    return null;
                  },
                ),
                const SizedBox(height: 15),

                // Telefono (Simplified: first one)
                TextFormField(
                  controller: _telefonoController,
                  decoration: const InputDecoration(labelText: 'Telefono Principale', border: OutlineInputBorder(), prefixIcon: Icon(Icons.phone)),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 15),

                // CV URL or Text
                TextFormField(
                  controller: _cvController,
                  decoration: const InputDecoration(labelText: 'CV (URL o testo)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.description)),
                  maxLines: 3,
                  keyboardType: TextInputType.multiline,
                ),
                const SizedBox(height: 15),

                // Note Biografiche
                TextFormField(
                  controller: _noteBiograficheController,
                  decoration: const InputDecoration(labelText: 'Note Biografiche', border: OutlineInputBorder(), prefixIcon: Icon(Icons.notes)),
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                  keyboardType: TextInputType.multiline,
                ),
                const SizedBox(height: 15),

                // RSS Feed URL
                TextFormField(
                  controller: _rssController,
                  decoration: const InputDecoration(labelText: 'RSS Feed URL', border: OutlineInputBorder(), prefixIcon: Icon(Icons.rss_feed)),
                  keyboardType: TextInputType.url,
                  validator: (value) {
                    // Validate URL format if not empty
                    if (value != null && value.trim().isNotEmpty) {
                      if (Uri.tryParse(value.trim())?.hasAbsolutePath != true) {
                        return 'Inserisci un URL valido';
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 15),

                // Website URL
                TextFormField(
                  controller: _webController,
                  decoration: const InputDecoration(labelText: 'Sito Web URL', border: OutlineInputBorder(), prefixIcon: Icon(Icons.web)),
                  keyboardType: TextInputType.url,
                  validator: (value) {
                    // Validate URL format if not empty
                    if (value != null && value.trim().isNotEmpty) {
                      if (Uri.tryParse(value.trim())?.hasAbsolutePath != true) {
                        return 'Inserisci un URL valido';
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 25), // More space before actions

                // --- Action Buttons ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isLoading ? null : () => Navigator.of(context).pop(), // Close dialog
                      child: const Text('Annulla'),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.save),
                      label: const Text('Aggiorna'),
                      // Enable button only if form is dirty and not currently loading/saving
                      onPressed: (_isDirty && !_isLoading) ? _updateProfile : null,
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Loading Overlay: displayed on top when _isLoading is true
        if (_isLoading)
          Positioned.fill(
            // Cover the entire Stack area
            child: Container(
              color: Colors.black.withOpacity(0.5), // Semi-transparent background
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }
}
