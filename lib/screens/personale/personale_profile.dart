// ignore_for_file: avoid_print, deprecated_member_use

import 'dart:typed_data'; // Required for Uint8List
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:una_social_app/controllers/personale_controller.dart';
import 'package:una_social_app/models/personale.dart'; // Assicurati che questo modello sia aggiornato

// Nuova classe helper
class ContactEntryItem {
  final TextEditingController tagController;
  final TextEditingController valueController;
  // key univoca per aiutare Flutter a identificare i widget nella lista
  final UniqueKey uniqueKey = UniqueKey();

  ContactEntryItem({String tag = '', String value = ''})
      : tagController = TextEditingController(text: tag),
        valueController = TextEditingController(text: value);

  Map<String, String> toMap() {
    return {
      'tag': tagController.text.trim(),
      'valore': valueController.text.trim(),
    };
  }

  void dispose() {
    tagController.dispose();
    valueController.dispose();
  }
}

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
  final PersonaleController _personaleController = Get.find<PersonaleController>();
  final _supabase = Supabase.instance.client;

  String? _signedImageUrl;
  bool _isLoadingImageUrl = true;

  late TextEditingController _nomeController;
  late TextEditingController _cognomeController;
  late TextEditingController _photoUrlController;
  late TextEditingController _cvController;
  late TextEditingController _noteBiograficheController;
  late TextEditingController _rssController;
  late TextEditingController _webController;

  // Liste per i campi dinamici
  final List<ContactEntryItem> _emailEntries = [];
  final List<ContactEntryItem> _phoneEntries = [];

  XFile? _pickedImageFile;
  bool _isDirty = false;
  bool _isLoading = false;

  final String _bucketName = 'una-bucket';
  final String _baseFolderPath = 'personale/foto';

  @override
  void initState() {
    super.initState();
    _nomeController = TextEditingController(text: widget.initialPersonale.nome);
    _cognomeController = TextEditingController(text: widget.initialPersonale.cognome);
    _photoUrlController = TextEditingController(text: widget.initialPersonale.photoUrl);
    _cvController = TextEditingController(text: widget.initialPersonale.cv);
    _noteBiograficheController = TextEditingController(text: widget.initialPersonale.noteBiografiche);
    _rssController = TextEditingController(text: widget.initialPersonale.rss);
    _webController = TextEditingController(text: widget.initialPersonale.web);

    // Inizializza email entries
    for (var emailMap in widget.initialPersonale.emails) {
      final entry = ContactEntryItem(
        tag: emailMap['tag'] ?? '',
        value: emailMap['valore'] ?? '',
      );
      _emailEntries.add(entry);
      entry.tagController.addListener(_markDirty);
      entry.valueController.addListener(_markDirty);
    }

    // Inizializza phone entries
    for (var phoneMap in widget.initialPersonale.telefoni) {
      final entry = ContactEntryItem(
        tag: phoneMap['tag'] ?? '',
        value: phoneMap['valore'] ?? '',
      );
      _phoneEntries.add(entry);
      entry.tagController.addListener(_markDirty);
      entry.valueController.addListener(_markDirty);
    }

    _nomeController.addListener(_markDirty);
    _cognomeController.addListener(_markDirty);
    _photoUrlController.addListener(_markDirty);
    _cvController.addListener(_markDirty);
    _noteBiograficheController.addListener(_markDirty);
    _rssController.addListener(_markDirty);
    _webController.addListener(_markDirty);

    _fetchSignedImageUrl();
  }

  @override
  void dispose() {
    _nomeController.removeListener(_markDirty);
    _cognomeController.removeListener(_markDirty);
    _photoUrlController.removeListener(_markDirty);
    _cvController.removeListener(_markDirty);
    _noteBiograficheController.removeListener(_markDirty);
    _rssController.removeListener(_markDirty);
    _webController.removeListener(_markDirty);

    _nomeController.dispose();
    _cognomeController.dispose();
    _photoUrlController.dispose();
    _cvController.dispose();
    _noteBiograficheController.dispose();
    _rssController.dispose();
    _webController.dispose();

    for (var entry in _emailEntries) {
      entry.tagController.removeListener(_markDirty);
      entry.valueController.removeListener(_markDirty);
      entry.dispose();
    }
    for (var entry in _phoneEntries) {
      entry.tagController.removeListener(_markDirty);
      entry.valueController.removeListener(_markDirty);
      entry.dispose();
    }
    super.dispose();
  }

  Future<void> _fetchSignedImageUrl() async {
    // ... (invariato, ma assicurati che usi i dati corretti per objectPath)
    if (!mounted) return;
    setState(() {
      _isLoadingImageUrl = true;
      _signedImageUrl = null;
    });

    final personale = _personaleController.personale.value; // o widget.initialPersonale se più aggiornato
    if (personale == null || personale.universita.isEmpty || personale.id <= 0) {
      print("Dati personali insufficienti per generare il percorso immagine.");
      if (mounted) setState(() => _isLoadingImageUrl = false);
      return;
    }
    final String objectPath = 'personale/foto/${personale.universita}_${personale.id}.jpg';
    try {
      final String signedUrl = await _supabase.storage.from(_bucketName).createSignedUrl(objectPath, 3600);
      if (mounted) {
        setState(() {
          _signedImageUrl = signedUrl;
          _isLoadingImageUrl = false;
        });
      }
    } catch (e) {
      print('Errore nel generare Signed URL per $objectPath: $e');
      if (mounted) setState(() => _isLoadingImageUrl = false);
    }
  }

  void _markDirty() {
    if (!_isDirty && mounted) {
      setState(() => _isDirty = true);
    }
  }

  void _addEmailEntry() {
    setState(() {
      final newEntry = ContactEntryItem();
      newEntry.tagController.addListener(_markDirty);
      newEntry.valueController.addListener(_markDirty);
      _emailEntries.add(newEntry);
      _markDirty();
    });
  }

  void _removeEmailEntry(ContactEntryItem entry) {
    setState(() {
      entry.tagController.removeListener(_markDirty);
      entry.valueController.removeListener(_markDirty);
      entry.dispose();
      _emailEntries.remove(entry);
      _markDirty();
    });
  }

  void _addPhoneEntry() {
    setState(() {
      final newEntry = ContactEntryItem();
      newEntry.tagController.addListener(_markDirty);
      newEntry.valueController.addListener(_markDirty);
      _phoneEntries.add(newEntry);
      _markDirty();
    });
  }

  void _removePhoneEntry(ContactEntryItem entry) {
    setState(() {
      entry.tagController.removeListener(_markDirty);
      entry.valueController.removeListener(_markDirty);
      entry.dispose();
      _phoneEntries.remove(entry);
      _markDirty();
    });
  }

  Future<void> _pickAndUploadImage() async {
    // ... (invariato)
    if (_isLoading) return;
    setState(() => _isLoading = true);
    _pickedImageFile = null;

    try {
      final picker = ImagePicker();
      final XFile? picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (picked == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      _pickedImageFile = picked;
      final Uint8List imageBytes = await _pickedImageFile!.readAsBytes();
      final String fileName = '${widget.initialPersonale.universita}_${widget.initialPersonale.id}.jpg';
      final String filePath = '$_baseFolderPath/$fileName';
      await _supabase.storage.from(_bucketName).uploadBinary(
            filePath,
            imageBytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
          );
      final String publicUrl = _supabase.storage.from(_bucketName).getPublicUrl(filePath);
      if (mounted) {
        _photoUrlController.text = publicUrl;
        _markDirty();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Immagine caricata con successo.'), backgroundColor: Colors.green),
        );
      }
      _pickedImageFile = null;
    } catch (e) {
      print('Errore caricamento immagine: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore caricamento immagine: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateProfile() async {
    if (!_isDirty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nessuna modifica rilevata.'), backgroundColor: Colors.orange),
      );
      return;
    }
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    // Prepara emails e telefoni, filtrando quelli vuoti (solo valore vuoto)
    final List<Map<String, String>> updatedEmails = _emailEntries
        .map((entry) => entry.toMap())
        .where((map) => map['valore']!.isNotEmpty) // Solo se il valore non è vuoto
        .toList();

    final List<Map<String, String>> updatedPhones = _phoneEntries
        .map((entry) => entry.toMap())
        .where((map) => map['valore']!.isNotEmpty) // Solo se il valore non è vuoto
        .toList();

    final updateData = {
      'nome': _nomeController.text.trim(),
      'cognome': _cognomeController.text.trim(),
      'photoUrl': _photoUrlController.text.trim().isEmpty ? null : _photoUrlController.text.trim(),
      'cv': _cvController.text.trim().isEmpty ? null : _cvController.text.trim(),
      'noteBiografiche': _noteBiograficheController.text.trim().isEmpty ? null : _noteBiograficheController.text.trim(),
      'rss': _rssController.text.trim().isEmpty ? null : _rssController.text.trim(),
      'web': _webController.text.trim().isEmpty ? null : _webController.text.trim(),
      'emails': updatedEmails, // Campo aggiornato
      'telefoni': updatedPhones, // Campo aggiornato
    };

    try {
      await _supabase.from('personale').update(updateData).eq('id', widget.initialPersonale.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profilo aggiornato!'), backgroundColor: Colors.green),
        );
        await _personaleController.reload();
        if (!mounted) return;
        Navigator.of(context).pop();
      }
    } catch (e) {
      print('Errore aggiornamento profilo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore aggiornamento: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildContactEntryRow({
    required ContactEntryItem entry,
    required String valueLabel,
    required String tagHint,
    required String valueHint,
    required VoidCallback onRemove,
    required TextInputType valueInputType,
    required IconData valueIcon,
    required String? Function(String?)? valueValidator,
  }) {
    return Padding(
      key: entry.uniqueKey, // Usa UniqueKey per la riga
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: TextFormField(
              controller: entry.tagController,
              decoration: InputDecoration(
                labelText: 'Tag',
                hintText: tagHint,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              textCapitalization: TextCapitalization.words,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: TextFormField(
              controller: entry.valueController,
              decoration: InputDecoration(
                labelText: valueLabel,
                hintText: valueHint,
                border: const OutlineInputBorder(),
                prefixIcon: Icon(valueIcon),
                isDense: true,
              ),
              keyboardType: valueInputType,
              validator: valueValidator,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
            onPressed: onRemove,
            tooltip: 'Rimuovi',
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget currentPhotoDisplay = // ... (invariato)
        SizedBox(
      height: 100,
      width: 100,
      child: Builder(
        builder: (context) {
          if (_isLoadingImageUrl) {
            return const Center(child: CircularProgressIndicator(strokeWidth: 2));
          }
          if (_photoUrlController.text.isNotEmpty) {
            final bool hasValidManualUrl = _photoUrlController.text.trim().isNotEmpty && Uri.tryParse(_photoUrlController.text.trim())?.hasAbsolutePath == true;
            if (hasValidManualUrl) {
              return CircleAvatar(
                key: ValueKey(_photoUrlController.text),
                radius: 50,
                backgroundImage: NetworkImage(_photoUrlController.text.trim()),
                onBackgroundImageError: (exception, stackTrace) {/* ... */},
              );
            }
          } else {
            final bool hasValidSignedUrl = _signedImageUrl != null && _signedImageUrl!.isNotEmpty && Uri.tryParse(_signedImageUrl!)?.hasAbsolutePath == true;
            if (hasValidSignedUrl) {
              return CircleAvatar(
                key: ValueKey(_signedImageUrl),
                radius: 50,
                backgroundImage: NetworkImage(_signedImageUrl!),
                onBackgroundImageError: (exception, stackTrace) {/* ... */},
              );
            }
          }
          return const CircleAvatar(radius: 50, child: Icon(Icons.person, size: 50));
        },
      ),
    );

    return Stack(
      children: [
        Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(child: currentPhotoDisplay),
                const SizedBox(height: 10),
                Center(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Carica Nuova Foto'),
                    onPressed: _isLoading ? null : _pickAndUploadImage,
                  ),
                ),
                const SizedBox(height: 15),
                TextFormField(
                  controller: _photoUrlController,
                  decoration: const InputDecoration(labelText: 'Photo URL', hintText: 'URL immagine', border: OutlineInputBorder(), prefixIcon: Icon(Icons.link)),
                  keyboardType: TextInputType.url,
                  validator: (value) {
                    if (value != null && value.trim().isNotEmpty && Uri.tryParse(value.trim())?.hasAbsolutePath != true) {
                      return 'Inserisci un URL valido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _nomeController,
                        decoration: const InputDecoration(labelText: 'Nome', border: OutlineInputBorder()),
                        validator: (value) => (value == null || value.trim().isEmpty) ? 'Il nome è obbligatorio' : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _cognomeController,
                        decoration: const InputDecoration(labelText: 'Cognome', border: OutlineInputBorder()),
                        validator: (value) => (value == null || value.trim().isEmpty) ? 'Il cognome è obbligatorio' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // --- Sezione Email Dinamiche ---
                Text('Emails', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (_emailEntries.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text('Nessuna email aggiunta.', style: TextStyle(color: Colors.grey[600])),
                  ),
                ..._emailEntries.map((entry) => _buildContactEntryRow(
                      entry: entry,
                      valueLabel: 'Email',
                      tagHint: 'Es. Lavoro, Personale',
                      valueHint: 'indirizzo@email.com',
                      onRemove: () => _removeEmailEntry(entry),
                      valueInputType: TextInputType.emailAddress,
                      valueIcon: Icons.email,
                      valueValidator: (value) {
                        if (value != null && value.trim().isNotEmpty && !GetUtils.isEmail(value.trim())) {
                          return 'Formato email non valido';
                        }
                        // Rendi l'email obbligatoria se il tag è presente o viceversa?
                        // O semplicemente ignora le entry con valore vuoto al salvataggio.
                        // Per ora, la validazione è solo sul formato se non vuoto.
                        return null;
                      },
                    )),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('Aggiungi Email'),
                    onPressed: _addEmailEntry,
                  ),
                ),
                const SizedBox(height: 20),

                // --- Sezione Telefoni Dinamici ---
                Text('Telefoni', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (_phoneEntries.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text('Nessun telefono aggiunto.', style: TextStyle(color: Colors.grey[600])),
                  ),
                ..._phoneEntries.map((entry) => _buildContactEntryRow(
                      entry: entry,
                      valueLabel: 'Numero Telefono',
                      tagHint: 'Es. Cellulare, Ufficio',
                      valueHint: 'Numero di telefono',
                      onRemove: () => _removePhoneEntry(entry),
                      valueInputType: TextInputType.phone,
                      valueIcon: Icons.phone,
                      valueValidator: (value) {
                        // Aggiungi validazioni specifiche per numeri di telefono se necessario
                        return null;
                      },
                    )),

                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('Aggiungi Telefono'),
                    onPressed: _addPhoneEntry,
                  ),
                ),
                const SizedBox(height: 15),

                // ... (altri campi esistenti: CV, Note, RSS, Web)
                TextFormField(
                  controller: _cvController,
                  decoration: const InputDecoration(labelText: 'CV (URL o testo)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.description)),
                  maxLines: 3,
                ),
                const SizedBox(height: 15),
                TextFormField(
                  controller: _noteBiograficheController,
                  decoration: const InputDecoration(labelText: 'Note Biografiche', border: OutlineInputBorder(), prefixIcon: Icon(Icons.notes)),
                  maxLines: 5,
                ),
                const SizedBox(height: 15),
                TextFormField(
                  controller: _rssController,
                  decoration: const InputDecoration(labelText: 'RSS Feed URL', border: OutlineInputBorder(), prefixIcon: Icon(Icons.rss_feed)),
                  keyboardType: TextInputType.url,
                  validator: (value) {
                    if (value != null && value.trim().isNotEmpty && Uri.tryParse(value.trim())?.hasAbsolutePath != true) {
                      return 'Inserisci un URL valido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 15),
                TextFormField(
                  controller: _webController,
                  decoration: const InputDecoration(labelText: 'Sito Web URL', border: OutlineInputBorder(), prefixIcon: Icon(Icons.web)),
                  keyboardType: TextInputType.url,
                  validator: (value) {
                    if (value != null && value.trim().isNotEmpty && Uri.tryParse(value.trim())?.hasAbsolutePath != true) {
                      return 'Inserisci un URL valido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 25),

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                      child: const Text('Annulla'),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.save),
                      label: const Text('Aggiorna'),
                      onPressed: (_isDirty && !_isLoading) ? _updateProfile : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (_isLoading)
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(child: CircularProgressIndicator(color: Colors.white)),
            ),
          ),
      ],
    );
  }
}
