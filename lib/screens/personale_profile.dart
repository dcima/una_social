// ignore_for_file: avoid_print, deprecated_member_use

import 'dart:typed_data'; // Required for Uint8List
import 'package:flutter/material.dart';
import 'package:get/get.dart'; // Per GetUtils.isEmail
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:una_social_app/controllers/personale_controller.dart'; // Assumi esista
import 'package:una_social_app/models/personale.dart';

// Helper per email e telefoni (tag/valore)
class ContactEntryItem {
  final TextEditingController tagController;
  final TextEditingController valueController;
  final UniqueKey uniqueKey = UniqueKey();

  ContactEntryItem({required String t, required String v})
      : tagController = TextEditingController(text: t),
        valueController = TextEditingController(text: v);

  Map<String, String> toMap() {
    return {
      'tag': tagController.text.trim(),
      'valore': valueController.text.trim(),
    };
  }

  void dispose() {
    print('ContactEntryItem: dispose()');
    tagController.dispose();
    valueController.dispose();
  }
}

// Helper per i ruoli (lista di stringhe)
class RuoloEntryItem {
  final TextEditingController controller;
  final UniqueKey uniqueKey = UniqueKey();

  RuoloEntryItem({String testo = ''}) : controller = TextEditingController(text: testo);

  String get text => controller.text.trim();

  void dispose() {
    print('RuoloEntryItem: dispose()');
    controller.dispose();
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

  // Controller per campi obbligatori
  late TextEditingController _enteController;
  late TextEditingController _strutturaController;
  late TextEditingController _emailPrincipaleController;
  late TextEditingController _nomeController;
  late TextEditingController _cognomeController;

  // Controller per campi opzionali
  late TextEditingController _photoUrlController;
  late TextEditingController _cvController;
  late TextEditingController _noteBiograficheController;
  late TextEditingController _rssController;
  late TextEditingController _webController;

  // Liste per i campi dinamici (JSONB)
  final List<RuoloEntryItem> _ruoliEntries = [];
  final List<ContactEntryItem> _altreEmailEntries = [];
  final List<ContactEntryItem> _phoneEntries = [];

  XFile? _pickedImageFile;
  bool _isDirty = false;
  bool _isLoading = false; // Loading generale per salvataggio/upload

  // Stato per la visualizzazione dell'immagine
  String? _currentDisplayImageUrl; // URL attualmente usato per visualizzare l'immagine
  bool _isLoadingDisplayImageUrl = true; // Loading per fetch signed URL
  bool _displayImageFailedToLoad = false; // Flag per errore caricamento immagine

  final String _bucketName = 'una-bucket'; // SOSTITUISCI CON IL TUO BUCKET
  final String _baseFolderPath = 'personale/foto';

  @override
  void initState() {
    print('_PersonaleProfileState: initState()');
    super.initState();
    _initializeControllers();
    _initializeDynamicLists();
    _addListeners();
    _fetchDisplayImageUrl(); // Carica l'immagine iniziale
  }

  void _initializeControllers() {
    print('_PersonaleProfileState: _initializeControllers()');
    _enteController = TextEditingController(text: widget.initialPersonale.ente);
    _strutturaController = TextEditingController(text: widget.initialPersonale.struttura);
    _emailPrincipaleController = TextEditingController(text: widget.initialPersonale.emailPrincipale);
    _nomeController = TextEditingController(text: widget.initialPersonale.nome);
    _cognomeController = TextEditingController(text: widget.initialPersonale.cognome);
    _photoUrlController = TextEditingController(text: widget.initialPersonale.photoUrl);
    _cvController = TextEditingController(text: widget.initialPersonale.cv);
    _noteBiograficheController = TextEditingController(text: widget.initialPersonale.noteBiografiche);
    _rssController = TextEditingController(text: widget.initialPersonale.rss);
    _webController = TextEditingController(text: widget.initialPersonale.web);
  }

  void _initializeDynamicLists() {
    print('_PersonaleProfileState: _initializeDynamicLists()');
    if (widget.initialPersonale.ruoli != null) {
      for (var ruoloText in widget.initialPersonale.ruoli!) {
        _ruoliEntries.add(RuoloEntryItem(testo: ruoloText));
      }
    }
    if (widget.initialPersonale.altreEmails != null) {
      for (var emailMap in widget.initialPersonale.altreEmails!) {
        _altreEmailEntries.add(ContactEntryItem(t: emailMap['t'] ?? '', v: emailMap['v'] ?? ''));
      }
    }
    if (widget.initialPersonale.telefoni != null) {
      for (var phoneMap in widget.initialPersonale.telefoni!) {
        _phoneEntries.add(ContactEntryItem(t: phoneMap['t'] ?? '', v: phoneMap['v'] ?? ''));
      }
    }
  }

  void _addListeners() {
    print('_PersonaleProfileState: _addListeners()');
    final controllers = [_enteController, _strutturaController, _emailPrincipaleController, _nomeController, _cognomeController, _photoUrlController, _cvController, _noteBiograficheController, _rssController, _webController];
    for (var controller in controllers) {
      controller.addListener(_markDirty);
    }
    for (var entry in _ruoliEntries) {
      entry.controller.addListener(_markDirty);
    }
    for (var entry in _altreEmailEntries) {
      entry.tagController.addListener(_markDirty);
      entry.valueController.addListener(_markDirty);
    }
    for (var entry in _phoneEntries) {
      entry.tagController.addListener(_markDirty);
      entry.valueController.addListener(_markDirty);
    }
  }

  @override
  void dispose() {
    print('_PersonaleProfileState: dispose()');
    final controllers = [_enteController, _strutturaController, _emailPrincipaleController, _nomeController, _cognomeController, _photoUrlController, _cvController, _noteBiograficheController, _rssController, _webController];
    for (var controller in controllers) {
      controller.removeListener(_markDirty);
      controller.dispose();
    }
    for (var entry in _ruoliEntries) {
      entry.dispose();
    }
    for (var entry in _altreEmailEntries) {
      entry.dispose();
    }
    for (var entry in _phoneEntries) {
      entry.dispose();
    }
    super.dispose();
  }

  void _markDirty() {
    print('_PersonaleProfileState: _markDirty()');
    if (!_isDirty && mounted) {
      setState(() => _isDirty = true);
    }
  }

  Future<void> _fetchDisplayImageUrl() async {
    print('_PersonaleProfileState: _fetchDisplayImageUrl()');
    if (!mounted) return;
    setState(() {
      _isLoadingDisplayImageUrl = true;
      _displayImageFailedToLoad = false; // Resetta prima di un nuovo tentativo
    });

    String? urlToTry = _photoUrlController.text.trim();

    // Se photoUrl è vuoto o non è un URL assoluto, prova a generare un signed URL
    if (urlToTry.isEmpty || Uri.tryParse(urlToTry)?.hasAbsolutePath != true) {
      final ente = widget.initialPersonale.ente;
      final id = widget.initialPersonale.id;
      // final uuid = widget.initialPersonale.uuid; // Per nome file basato su UUID

      if (ente.isNotEmpty && id > 0) {
        // final String objectPath = '$_baseFolderPath/${uuid}.jpg'; // Opzione UUID
        final String objectPath = '$_baseFolderPath/${ente}_$id.jpg';
        try {
          urlToTry = await _supabase.storage.from(_bucketName).createSignedUrl(objectPath, 3600);
        } catch (e) {
          print('Errore nel generare Signed URL per $objectPath: $e');
          if (mounted) {
            setState(() {
              _isLoadingDisplayImageUrl = false;
              _displayImageFailedToLoad = true; // Fallito il recupero del signed URL
              _currentDisplayImageUrl = null;
            });
          }
          return;
        }
      } else {
        // Non ci sono abbastanza info per un signed URL, e photoUrlController non è un URL valido
        if (mounted) {
          setState(() {
            _isLoadingDisplayImageUrl = false;
            _currentDisplayImageUrl = null; // Nessun URL da mostrare
          });
        }
        return;
      }
    }

    // A questo punto, urlToTry dovrebbe essere un URL valido (dal controller o signed)
    if (mounted) {
      setState(() {
        _currentDisplayImageUrl = urlToTry;
        _isLoadingDisplayImageUrl = false; // Abbiamo un URL da provare (anche se potrebbe fallire il caricamento dell'immagine stessa)
        // _displayImageFailedToLoad è già false o sarà gestito da onBackgroundImageError
      });
    }
  }

  // --- Gestione Ruoli ---
  void _addRuoloEntry() {
    print('_PersonaleProfileState: _addRuoloEntry()');
    setState(() {
      final newEntry = RuoloEntryItem();
      newEntry.controller.addListener(_markDirty);
      _ruoliEntries.add(newEntry);
      _markDirty();
    });
  }

  void _removeRuoloEntry(RuoloEntryItem entry) {
    print('_PersonaleProfileState: _removeRuoloEntry()');
    setState(() {
      entry.controller.removeListener(_markDirty);
      entry.dispose();
      _ruoliEntries.remove(entry);
      _markDirty();
    });
  }

  // --- Gestione Altre Email ---
  void _addAltraEmailEntry() {
    print('_PersonaleProfileState: _addAltraEmailEntry()');
    setState(() {
      final newEntry = ContactEntryItem(t: '', v: '');
      newEntry.tagController.addListener(_markDirty);
      newEntry.valueController.addListener(_markDirty);
      _altreEmailEntries.add(newEntry);
      _markDirty();
    });
  }

  void _removeAltraEmailEntry(ContactEntryItem entry) {
    print('_PersonaleProfileState: _removeAltraEmailEntry()');
    setState(() {
      entry.tagController.removeListener(_markDirty);
      entry.valueController.removeListener(_markDirty);
      entry.dispose();
      _altreEmailEntries.remove(entry);
      _markDirty();
    });
  }

  // --- Gestione Telefoni ---
  void _addPhoneEntry() {
    print('_PersonaleProfileState: _addPhoneEntry()');
    setState(() {
      final newEntry = ContactEntryItem(t: '', v: '');
      newEntry.tagController.addListener(_markDirty);
      newEntry.valueController.addListener(_markDirty);
      _phoneEntries.add(newEntry);
      _markDirty();
    });
  }

  void _removePhoneEntry(ContactEntryItem entry) {
    print('_PersonaleProfileState: _removePhoneEntry()');
    setState(() {
      entry.tagController.removeListener(_markDirty);
      entry.valueController.removeListener(_markDirty);
      entry.dispose();
      _phoneEntries.remove(entry);
      _markDirty();
    });
  }

  Future<void> _pickAndUploadImage() async {
    print('_PersonaleProfileState: _pickAndUploadImage()');
    if (_isLoading) return; // Evita upload multipli se _isLoading è per _updateProfile
    setState(() => _isLoading = true); // Usiamo _isLoading generale per l'upload
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

      // final String fileName = '${widget.initialPersonale.uuid}.jpg'; // Opzione UUID
      final String fileName = '${widget.initialPersonale.ente}_${widget.initialPersonale.id}.jpg';
      final String filePath = '$_baseFolderPath/$fileName';

      await _supabase.storage.from(_bucketName).uploadBinary(
            filePath,
            imageBytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
          );

      final String publicUrl = _supabase.storage.from(_bucketName).getPublicUrl(filePath);
      final String urlWithTimestamp = "$publicUrl?t=${DateTime.now().millisecondsSinceEpoch}";

      if (mounted) {
        _photoUrlController.text = urlWithTimestamp; // Aggiorna il controller
        _markDirty();
        // Dopo aver caricato, aggiorna l'URL di visualizzazione
        setState(() {
          _currentDisplayImageUrl = urlWithTimestamp;
          _displayImageFailedToLoad = false; // Resetta il flag d'errore per il nuovo URL
          _isLoadingDisplayImageUrl = false; // Non stiamo più "caricando" il signed URL
        });
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
    print('_PersonaleProfileState: _updateProfile()');
    if (!_isDirty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nessuna modifica rilevata.'), backgroundColor: Colors.orange),
      );
      return;
    }
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final List<String> updatedRuoli = _ruoliEntries.map((e) => e.text).where((text) => text.isNotEmpty).toList();
    final List<Map<String, String>> updatedAltreEmails = _altreEmailEntries.map((e) => e.toMap()).where((map) => map['valore']!.isNotEmpty).toList();
    final List<Map<String, String>> updatedPhones = _phoneEntries.map((e) => e.toMap()).where((map) => map['valore']!.isNotEmpty).toList();

    final Map<String, dynamic> updateData = {
      'ente': _enteController.text.trim(),
      'struttura': _strutturaController.text.trim(),
      'email_principale': _emailPrincipaleController.text.trim(),
      'nome': _nomeController.text.trim(),
      'cognome': _cognomeController.text.trim(),
      'photo_url': _photoUrlController.text.trim().isEmpty ? null : _photoUrlController.text.trim(),
      'cv': _cvController.text.trim().isEmpty ? null : _cvController.text.trim(),
      'note_biografiche': _noteBiograficheController.text.trim().isEmpty ? null : _noteBiograficheController.text.trim(),
      'rss': _rssController.text.trim().isEmpty ? null : _rssController.text.trim(),
      'web': _webController.text.trim().isEmpty ? null : _webController.text.trim(),
      'ruoli': updatedRuoli.isNotEmpty ? updatedRuoli : null,
      'altre_emails': updatedAltreEmails.isNotEmpty ? updatedAltreEmails : null,
      'telefoni': updatedPhones.isNotEmpty ? updatedPhones : null,
    };

    try {
      await _supabase.from('personale').update(updateData).eq('uuid', widget.initialPersonale.uuid);
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

  Widget _buildRuoloEntryRow(RuoloEntryItem entry) {
    print('_PersonaleProfileState: _buildRuoloEntryRow()');
    return Padding(
      key: entry.uniqueKey,
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: entry.controller,
              decoration: const InputDecoration(
                labelText: 'Ruolo',
                hintText: 'Es. Ricercatore, Docente',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
            onPressed: () => _removeRuoloEntry(entry),
            tooltip: 'Rimuovi Ruolo',
          ),
        ],
      ),
    );
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
    print('_PersonaleProfileState: _buildContactEntryRow()');
    return Padding(
      key: entry.uniqueKey,
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: TextFormField(
              controller: entry.tagController,
              decoration: InputDecoration(
                labelText: 'Etichetta',
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
    print('_PersonaleProfileState: build(): $_phoneEntries, $_altreEmailEntries, $_ruoliEntries');

    Widget photoDisplayWidget;
    if (_isLoadingDisplayImageUrl) {
      photoDisplayWidget = const Center(child: CircularProgressIndicator(strokeWidth: 2));
    } else if (_displayImageFailedToLoad || _currentDisplayImageUrl == null || _currentDisplayImageUrl!.isEmpty) {
      photoDisplayWidget = const CircleAvatar(radius: 50, child: Icon(Icons.broken_image, size: 50));
      if (_currentDisplayImageUrl == null || _currentDisplayImageUrl!.isEmpty && !_displayImageFailedToLoad) {
        photoDisplayWidget = const CircleAvatar(radius: 50, child: Icon(Icons.person, size: 50)); // Nessuna immagine, icona persona
      }
    } else {
      photoDisplayWidget = CircleAvatar(
        key: ValueKey(_currentDisplayImageUrl), // Chiave basata sull'URL corrente
        radius: 50,
        backgroundImage: NetworkImage(_currentDisplayImageUrl!),
        onBackgroundImageError: (exception, stackTrace) {
          print("Errore caricamento NetworkImage per $_currentDisplayImageUrl: $exception");
          if (mounted && !_displayImageFailedToLoad) {
            setState(() {
              _displayImageFailedToLoad = true;
            });
          }
        },
      );
    }

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
                SizedBox(height: 100, width: 100, child: Center(child: photoDisplayWidget)),
                const SizedBox(height: 10),
                Center(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Carica Nuova Foto'),
                    onPressed: (_isLoading) ? null : _pickAndUploadImage,
                  ),
                ),
                const SizedBox(height: 15),
                TextFormField(
                  controller: _photoUrlController,
                  decoration: const InputDecoration(labelText: 'Photo URL', hintText: 'URL immagine (opzionale)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.link)),
                  keyboardType: TextInputType.url,
                  onChanged: (value) {
                    // Se l'utente modifica manualmente l'URL, prova a ricaricare l'immagine
                    _markDirty();
                    if (Uri.tryParse(value)?.hasAbsolutePath == true) {
                      setState(() {
                        _currentDisplayImageUrl = value;
                        _displayImageFailedToLoad = false;
                        _isLoadingDisplayImageUrl = false; // Non è un fetch, ma un cambio diretto
                      });
                    } else if (value.trim().isEmpty) {
                      _fetchDisplayImageUrl(); // Se l'URL viene cancellato, prova a ricaricare il signedURL originale
                    }
                  },
                  validator: (value) {
                    if (value != null && value.trim().isNotEmpty && Uri.tryParse(value.trim())?.hasAbsolutePath != true) {
                      return 'Inserisci un URL valido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Campi Obbligatori
                TextFormField(
                  controller: _enteController,
                  decoration: const InputDecoration(labelText: 'Ente *', border: OutlineInputBorder()),
                  validator: (value) => (value == null || value.trim().isEmpty) ? 'L\'ente è obbligatorio' : null,
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _nomeController,
                        decoration: const InputDecoration(labelText: 'Nome *', border: OutlineInputBorder()),
                        validator: (value) => (value == null || value.trim().isEmpty) ? 'Il nome è obbligatorio' : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _cognomeController,
                        decoration: const InputDecoration(labelText: 'Cognome *', border: OutlineInputBorder()),
                        validator: (value) => (value == null || value.trim().isEmpty) ? 'Il cognome è obbligatorio' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                TextFormField(
                  controller: _strutturaController,
                  decoration: const InputDecoration(labelText: 'Struttura *', border: OutlineInputBorder()),
                  validator: (value) => (value == null || value.trim().isEmpty) ? 'La struttura è obbligatoria' : null,
                ),
                const SizedBox(height: 15),
                TextFormField(
                  controller: _emailPrincipaleController,
                  decoration: const InputDecoration(labelText: 'Email Principale *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.email)),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'L\'email principale è obbligatoria';
                    if (!GetUtils.isEmail(value.trim())) return 'Formato email non valido';
                    return null;
                  },
                ),
                const SizedBox(height: 25),

                // --- Sezione Ruoli ---
                Text('Ruoli', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (_ruoliEntries.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 8.0), child: Text('Nessun ruolo aggiunto.', style: TextStyle(color: Colors.grey[600]))),
                ..._ruoliEntries.map((entry) => _buildRuoloEntryRow(entry)),
                Align(alignment: Alignment.centerRight, child: TextButton.icon(icon: const Icon(Icons.add_circle_outline), label: const Text('Aggiungi Ruolo'), onPressed: _addRuoloEntry)),
                const SizedBox(height: 20),

                // --- Sezione Altre Emails ---
                Text('Altre Emails', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (_altreEmailEntries.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 8.0), child: Text('Nessuna email aggiuntiva.', style: TextStyle(color: Colors.grey[600]))),
                ..._altreEmailEntries.map((entry) => _buildContactEntryRow(
                      entry: entry,
                      valueLabel: 'Email',
                      tagHint: 'Es. Lavoro, Personale',
                      valueHint: 'indirizzo@email.com',
                      onRemove: () => _removeAltraEmailEntry(entry),
                      valueInputType: TextInputType.emailAddress,
                      valueIcon: Icons.alternate_email,
                      valueValidator: (value) {
                        if (entry.tagController.text.trim().isNotEmpty && (value == null || value.trim().isEmpty)) return 'L\'email è richiesta se l\'etichetta è specificata';
                        if (value != null && value.trim().isNotEmpty && !GetUtils.isEmail(value.trim())) return 'Formato email non valido';
                        return null;
                      },
                    )),
                Align(alignment: Alignment.centerRight, child: TextButton.icon(icon: const Icon(Icons.add_circle_outline), label: const Text('Aggiungi Email'), onPressed: _addAltraEmailEntry)),
                const SizedBox(height: 20),

                // --- Sezione Telefoni ---
                Text('Telefoni', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (_phoneEntries.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 8.0), child: Text('Nessun telefono aggiunto.', style: TextStyle(color: Colors.grey[600]))),
                ..._phoneEntries.map((entry) => _buildContactEntryRow(
                      entry: entry,
                      valueLabel: 'Numero Telefono',
                      tagHint: 'Es. Cellulare, Ufficio',
                      valueHint: 'Numero di telefono',
                      onRemove: () => _removePhoneEntry(entry),
                      valueInputType: TextInputType.phone,
                      valueIcon: Icons.phone,
                      valueValidator: (value) {
                        if (entry.tagController.text.trim().isNotEmpty && (value == null || value.trim().isEmpty)) return 'Il numero è richiesto se l\'etichetta è specificata';
                        return null;
                      },
                    )),
                Align(alignment: Alignment.centerRight, child: TextButton.icon(icon: const Icon(Icons.add_circle_outline), label: const Text('Aggiungi Telefono'), onPressed: _addPhoneEntry)),
                const SizedBox(height: 20),

                // --- Altri Campi Opzionali ---
                TextFormField(controller: _cvController, decoration: const InputDecoration(labelText: 'CV (URL o testo)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.description)), maxLines: 3),
                const SizedBox(height: 15),
                TextFormField(controller: _noteBiograficheController, decoration: const InputDecoration(labelText: 'Note Biografiche', border: OutlineInputBorder(), prefixIcon: Icon(Icons.notes)), maxLines: 5),
                const SizedBox(height: 15),
                TextFormField(
                  controller: _rssController,
                  decoration: const InputDecoration(labelText: 'RSS Feed URL', border: OutlineInputBorder(), prefixIcon: Icon(Icons.rss_feed)),
                  keyboardType: TextInputType.url,
                  validator: (value) => (value != null && value.trim().isNotEmpty && Uri.tryParse(value.trim())?.hasAbsolutePath != true) ? 'Inserisci un URL valido' : null,
                ),
                const SizedBox(height: 15),
                TextFormField(
                  controller: _webController,
                  decoration: const InputDecoration(labelText: 'Sito Web URL', border: OutlineInputBorder(), prefixIcon: Icon(Icons.web)),
                  keyboardType: TextInputType.url,
                  validator: (value) => (value != null && value.trim().isNotEmpty && Uri.tryParse(value.trim())?.hasAbsolutePath != true) ? 'Inserisci un URL valido' : null,
                ),
                const SizedBox(height: 25),

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: _isLoading ? null : () => Navigator.of(context).pop(), child: const Text('Annulla')),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      icon: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save),
                      label: const Text('Aggiorna'),
                      onPressed: (_isDirty && !_isLoading) ? _updateProfile : null,
                      style: ElevatedButton.styleFrom(disabledForegroundColor: Colors.grey.withOpacity(0.38), disabledBackgroundColor: Colors.grey.withOpacity(0.12)),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
        if (_isLoading && ModalRoute.of(context)?.isCurrent != true)
          Positioned.fill(
            child: Container(color: Colors.black.withOpacity(0.5), child: const Center(child: CircularProgressIndicator(color: Colors.white))),
          ),
      ],
    );
  }
}
