// lib/personale_profile.dart
// ignore_for_file: avoid_print, deprecated_member_use

import 'dart:typed_data'; // Required for Uint8List
import 'package:flutter/material.dart';
import 'package:get/get.dart'; // Per GetUtils.isEmail
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:una_social_app/controllers/personale_controller.dart';
import 'package:una_social_app/models/personale.dart';

// Helper per email e telefoni (tag/valore, ma le chiavi sono 't' e 'v')
class ContactEntryItem {
  final TextEditingController tagController; // Controller per 't'
  final TextEditingController valueController; // Controller per 'v'
  final UniqueKey uniqueKey = UniqueKey();

  ContactEntryItem({required String t, required String v})
      : tagController = TextEditingController(text: t),
        valueController = TextEditingController(text: v);

  Map<String, String> toMapForDb() {
    return {
      't': tagController.text.trim(),
      'v': valueController.text.trim(),
    };
  }

  void dispose() {
    // //print('ContactEntryItem.dispose(): key ${uniqueKey.toString()}');
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
    // //print('RuoloEntryItem.dispose(): key ${uniqueKey.toString()}');
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

  late TextEditingController _enteController;
  late TextEditingController _strutturaController;
  late TextEditingController _emailPrincipaleController;
  late TextEditingController _nomeController;
  late TextEditingController _cognomeController;
  late TextEditingController _photoUrlController;
  late TextEditingController _cvController;
  late TextEditingController _noteBiograficheController;
  late TextEditingController _rssController;
  late TextEditingController _webController;

  final List<RuoloEntryItem> _ruoliEntries = [];
  final List<ContactEntryItem> _altreEmailEntries = [];
  final List<ContactEntryItem> _phoneEntries = [];

  XFile? _pickedImageFile;
  bool _isDirty = false;
  bool _isLoading = false; // Loading generale per salvataggio/upload

  String? _currentDisplayImageUrl; // URL attualmente usato per visualizzare l'immagine
  bool _isLoadingDisplayImageUrl = true; // Loading per fetch signed URL o per Image.network
  bool _displayImageFailedToLoad = false; // Flag per errore caricamento immagine

  final String _bucketName = 'una-bucket';
  final String _baseFolderPath = 'personale/foto';

  @override
  void initState() {
    //print('_PersonaleProfileState.initState: Loading profile for ${widget.initialPersonale.fullName} (ID: ${widget.initialPersonale.id})');
    super.initState();
    _initializeControllers();
    _initializeDynamicLists();
    _addListenersToDynamicEntries(); // Chiama questo DOPO _initializeDynamicLists
    _addListenersToStaticControllers();
    _fetchDisplayImageUrl();
  }

  void _initializeControllers() {
    //print('_PersonaleProfileState._initializeControllers');
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
    //print('_PersonaleProfileState._initializeDynamicLists');
    _ruoliEntries.clear();
    if (widget.initialPersonale.ruoli != null) {
      for (var ruoloText in widget.initialPersonale.ruoli!) {
        _ruoliEntries.add(RuoloEntryItem(testo: ruoloText));
      }
    }
    //print('  Ruoli init: ${_ruoliEntries.length}');

    _altreEmailEntries.clear();
    if (widget.initialPersonale.altreEmails != null) {
      for (var emailMap in widget.initialPersonale.altreEmails!) {
        _altreEmailEntries.add(ContactEntryItem(t: emailMap['t'] ?? '', v: emailMap['v'] ?? ''));
      }
    }
    //print('  AltreEmailEntries init: ${_altreEmailEntries.length}');

    _phoneEntries.clear();
    if (widget.initialPersonale.telefoni != null) {
      for (var phoneMap in widget.initialPersonale.telefoni!) {
        _phoneEntries.add(ContactEntryItem(t: phoneMap['t'] ?? '', v: phoneMap['v'] ?? ''));
      }
    }
    //print('  PhoneEntries init: ${_phoneEntries.length}');
  }

  void _addListenersToStaticControllers() {
    final staticControllers = [_enteController, _strutturaController, _emailPrincipaleController, _nomeController, _cognomeController, _photoUrlController, _cvController, _noteBiograficheController, _rssController, _webController];
    for (var controller in staticControllers) {
      controller.addListener(_markDirty);
    }
  }

  // Aggiunge listener alle entry già presenti nelle liste
  void _addListenersToDynamicEntries() {
    //print('_PersonaleProfileState._addListenersToDynamicEntries');
    for (var entry in _ruoliEntries) {
      entry.controller.removeListener(_markDirty); // Rimuovi vecchio se presente
      entry.controller.addListener(_markDirty);
    }
    for (var entry in _altreEmailEntries) {
      entry.tagController.removeListener(_markDirty);
      entry.valueController.removeListener(_markDirty);
      entry.tagController.addListener(_markDirty);
      entry.valueController.addListener(_markDirty);
    }
    for (var entry in _phoneEntries) {
      entry.tagController.removeListener(_markDirty);
      entry.valueController.removeListener(_markDirty);
      entry.tagController.addListener(_markDirty);
      entry.valueController.addListener(_markDirty);
    }
  }

  @override
  void dispose() {
    //print('_PersonaleProfileState.dispose: Disposing controllers for ${widget.initialPersonale.fullName}');
    final staticControllers = [_enteController, _strutturaController, _emailPrincipaleController, _nomeController, _cognomeController, _photoUrlController, _cvController, _noteBiograficheController, _rssController, _webController];
    for (var controller in staticControllers) {
      controller.removeListener(_markDirty);
      controller.dispose();
    }
    for (var entry in _ruoliEntries) {
      entry.controller.removeListener(_markDirty);
      entry.dispose();
    }
    _ruoliEntries.clear();
    for (var entry in _altreEmailEntries) {
      entry.tagController.removeListener(_markDirty);
      entry.valueController.removeListener(_markDirty);
      entry.dispose();
    }
    _altreEmailEntries.clear();
    for (var entry in _phoneEntries) {
      entry.tagController.removeListener(_markDirty);
      entry.valueController.removeListener(_markDirty);
      entry.dispose();
    }
    _phoneEntries.clear();
    super.dispose();
  }

  void _markDirty() {
    if (!_isDirty && mounted) {
      setState(() => _isDirty = true);
    }
  }

  Future<void> _fetchDisplayImageUrl() async {
    //print('_PersonaleProfileState._fetchDisplayImageUrl');

    if (!mounted) {
      return;
    }

    String photoUrl = widget.initialPersonale.photoUrl ?? '';
    String urlInController = _photoUrlController.text.trim();
    bool isControllerUrlValid = Uri.tryParse(urlInController)?.hasAbsolutePath == true;

    if (photoUrl != '') {
      //print('Using signedPhotoUrl: $photoUrl');
      if (mounted) {
        setState(() {
          _currentDisplayImageUrl = photoUrl;
          _isLoadingDisplayImageUrl = false; // Finito il loading dell'URL, ora tocca a Image.network
          _displayImageFailedToLoad = false; // Resetta il flag di errore per il nuovo URL
        });
      }
    } else if (isControllerUrlValid) {
      // L'URL nel controller è già un URL assoluto, usiamolo direttamente.
      // Image.network gestirà il suo loading.
      if (_currentDisplayImageUrl != urlInController || _displayImageFailedToLoad) {
        //print('  Using direct URL from controller: $urlInController');
        if (mounted) {
          setState(() {
            _currentDisplayImageUrl = urlInController;
            _isLoadingDisplayImageUrl = false; // Finito il loading dell'URL, ora tocca a Image.network
            _displayImageFailedToLoad = false; // Resetta il flag di errore per il nuovo URL
          });
        }
      } else {
        // URL non cambiato e non in errore, non serve setState se non per _isLoadingDisplayImageUrl
        if (mounted && _isLoadingDisplayImageUrl) {
          setState(() => _isLoadingDisplayImageUrl = false);
        }
      }
      return;
    }
  }

  void _addRuoloEntry() {
    //print('_PersonaleProfileState._addRuoloEntry');
    setState(() {
      final newEntry = RuoloEntryItem();
      newEntry.controller.addListener(_markDirty);
      _ruoliEntries.add(newEntry);
      _markDirty();
    });
  }

  void _removeRuoloEntry(RuoloEntryItem entry) {
    //print('_PersonaleProfileState._removeRuoloEntry: key ${entry.uniqueKey}');
    setState(() {
      entry.controller.removeListener(_markDirty);
      entry.dispose();
      _ruoliEntries.remove(entry);
      _markDirty();
    });
  }

  void _addAltraEmailEntry() {
    //print('_PersonaleProfileState._addAltraEmailEntry');
    setState(() {
      final newEntry = ContactEntryItem(t: '', v: '');
      newEntry.tagController.addListener(_markDirty);
      newEntry.valueController.addListener(_markDirty);
      _altreEmailEntries.add(newEntry);
      _markDirty();
    });
  }

  void _removeAltraEmailEntry(ContactEntryItem entry) {
    //print('_PersonaleProfileState._removeAltraEmailEntry: key ${entry.uniqueKey}');
    setState(() {
      entry.tagController.removeListener(_markDirty);
      entry.valueController.removeListener(_markDirty);
      entry.dispose();
      _altreEmailEntries.remove(entry);
      _markDirty();
    });
  }

  void _addPhoneEntry() {
    //print('_PersonaleProfileState._addPhoneEntry');
    setState(() {
      final newEntry = ContactEntryItem(t: '', v: '');
      newEntry.tagController.addListener(_markDirty);
      newEntry.valueController.addListener(_markDirty);
      _phoneEntries.add(newEntry);
      _markDirty();
    });
  }

  void _removePhoneEntry(ContactEntryItem entry) {
    //print('_PersonaleProfileState._removePhoneEntry: key ${entry.uniqueKey}');
    setState(() {
      entry.tagController.removeListener(_markDirty);
      entry.valueController.removeListener(_markDirty);
      entry.dispose();
      _phoneEntries.remove(entry);
      _markDirty();
    });
  }

  Future<void> _pickAndUploadImage() async {
    //print('_PersonaleProfileState._pickAndUploadImage');
    if (_isLoading) return;
    setState(() => _isLoading = true);
    _pickedImageFile = null;

    try {
      final picker = ImagePicker();
      final XFile? picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 800, maxHeight: 800);
      if (picked == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      _pickedImageFile = picked;
      final Uint8List imageBytes = await _pickedImageFile!.readAsBytes();
      final String fileName = '${widget.initialPersonale.ente}_${widget.initialPersonale.id}.jpg';
      final String filePath = '$_baseFolderPath/$fileName';

      //print('  Uploading image to: $filePath');
      await _supabase.storage.from(_bucketName).uploadBinary(
            filePath,
            imageBytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
          );

      // Ottieni un URL pubblico con timestamp per forzare l'aggiornamento della cache
      final String publicUrl = _supabase.storage.from(_bucketName).getPublicUrl(filePath);
      final String urlWithTimestamp = "$publicUrl?t=${DateTime.now().millisecondsSinceEpoch}";
      //print('  Image uploaded, new URL with timestamp: $urlWithTimestamp');

      if (mounted) {
        _photoUrlController.text = urlWithTimestamp; // Aggiorna il controller del TextFormField
        _markDirty(); // Segna che ci sono modifiche da salvare
        // Aggiorna l'URL di visualizzazione e resetta i flag
        setState(() {
          _currentDisplayImageUrl = urlWithTimestamp;
          _displayImageFailedToLoad = false;
          _isLoadingDisplayImageUrl = false; // Abbiamo un URL, Image.network gestirà il suo loading
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Immagine caricata con successo.'), backgroundColor: Colors.green),
        );
      }
      _pickedImageFile = null;
    } catch (e) {
      //print('  Error uploading image: $e');
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
    //print('_PersonaleProfileState._updateProfile');
    if (!_formKey.currentState!.validate()) {
      //print('  Form validation failed.');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Per favore, correggi gli errori nel modulo.'), backgroundColor: Colors.orange),
      );
      return;
    }
    if (!_isDirty) {
      // Controllo _isDirty dopo la validazione
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nessuna modifica rilevata.'), backgroundColor: Colors.blueGrey),
      );
      return;
    }
    if (_isLoading) return;

    setState(() => _isLoading = true);

    final List<String> updatedRuoli = _ruoliEntries.map((e) => e.text).where((text) => text.isNotEmpty).toList();
    final List<Map<String, String>> updatedAltreEmails = _altreEmailEntries.map((e) => e.toMapForDb()).where((map) => map['v']!.isNotEmpty).toList();
    final List<Map<String, String>> updatedPhones = _phoneEntries.map((e) => e.toMapForDb()).where((map) => map['v']!.isNotEmpty).toList();

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

    //print('  Data to update (altre_emails): $updatedAltreEmails');
    //print('  Data to update (telefoni): $updatedPhones');

    try {
      await _supabase.from('personale').update(updateData).eq('uuid', widget.initialPersonale.uuid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profilo aggiornato!'), backgroundColor: Colors.green),
        );
        await _personaleController.reload(); // Ricarica i dati nel controller GetX
        if (!mounted) return;
        setState(() => _isDirty = false); // Resetta lo stato dirty dopo il salvataggio
        // Navigator.of(context).pop(); // Togli il commento se vuoi chiudere il dialogo automaticamente
      }
    } catch (e) {
      //print('  Error updating profile: $e');
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
    //print('_PersonaleProfileState.build: AltreEmail count: ${_altreEmailEntries.length}, Phone count: ${_phoneEntries.length}');

    Widget photoDisplayWidget;
    const double avatarDisplaySize = 100.0;

    if (_isLoadingDisplayImageUrl) {
      photoDisplayWidget = SizedBox(
        width: avatarDisplaySize,
        height: avatarDisplaySize,
        child: Center(child: Tooltip(message: "Caricamento URL immagine...", child: CircularProgressIndicator(strokeWidth: 2))),
      );
    } else if (_displayImageFailedToLoad || _currentDisplayImageUrl == null || _currentDisplayImageUrl!.trim().isEmpty) {
      IconData iconData = Icons.person_outline;
      Color iconColor = Colors.grey.shade400;
      Color backgroundColor = Colors.grey.shade200;
      String tooltipMessage = "Nessuna immagine del profilo.";

      if (_displayImageFailedToLoad) {
        iconData = Icons.broken_image_outlined;
        iconColor = Colors.red.shade400;
        backgroundColor = Colors.red.shade100;
        tooltipMessage = "Errore caricamento immagine.";
      }

      photoDisplayWidget = Tooltip(
        message: tooltipMessage,
        child: Container(
          width: avatarDisplaySize,
          height: avatarDisplaySize,
          decoration: BoxDecoration(
            color: backgroundColor,
            shape: BoxShape.circle,
          ),
          child: Center(child: Icon(iconData, size: avatarDisplaySize * 0.6, color: iconColor)),
        ),
      );
    } else {
      photoDisplayWidget = SizedBox(
        width: avatarDisplaySize,
        height: avatarDisplaySize,
        child: ClipOval(
          child: FittedBox(
            fit: BoxFit.contain,
            child: Image.network(
              _currentDisplayImageUrl!,
              key: ValueKey(_currentDisplayImageUrl!), // Semplificata la chiave, Image.network gestisce la cache
              loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
                if (loadingProgress == null) return child;
                return Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    value: loadingProgress.expectedTotalBytes != null ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes! : null,
                  ),
                );
              },
              errorBuilder: (BuildContext context, Object exception, StackTrace? stackTrace) {
                //print("  Image.network errorBuilder for $_currentDisplayImageUrl: $exception");
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && !_displayImageFailedToLoad) {
                    // Evita loop di setState
                    setState(() {
                      _displayImageFailedToLoad = true;
                      // _currentDisplayImageUrl = null; // Opzionale: pulire l'URL fallito
                    });
                  }
                });
                return Container(
                  // Placeholder mostrato immediatamente durante l'errore
                  width: avatarDisplaySize, height: avatarDisplaySize,
                  color: Colors.red.shade50,
                  child: Icon(Icons.error_outline, color: Colors.red.shade300, size: avatarDisplaySize * 0.5),
                );
              },
            ),
          ),
        ),
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
                Align(
                  alignment: Alignment.center,
                  child: photoDisplayWidget,
                ),
                const SizedBox(height: 10),
                Center(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Carica/Cambia Foto'),
                    onPressed: (_isLoading) ? null : _pickAndUploadImage,
                  ),
                ),
                const SizedBox(height: 15),
                TextFormField(
                  controller: _photoUrlController,
                  decoration: const InputDecoration(labelText: 'Photo URL', hintText: 'URL immagine (opzionale)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.link)),
                  keyboardType: TextInputType.url,
                  onChanged: (value) {
                    _markDirty();
                    // Se l'utente cambia l'URL, tentiamo di ricaricare l'immagine.
                    // _fetchDisplayImageUrl gestirà la logica per usare questo URL
                    // o generare un signed URL se questo è vuoto/invalido.
                    _fetchDisplayImageUrl();
                  },
                  validator: (value) {
                    if (value != null && value.trim().isNotEmpty && Uri.tryParse(value.trim())?.hasAbsolutePath != true) {
                      return 'Inserisci un URL valido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _enteController,
                  decoration: const InputDecoration(labelText: 'Ente *', border: OutlineInputBorder()),
                  validator: (value) => (value == null || value.trim().isEmpty) ? 'L\'ente è obbligatorio' : null,
                  onChanged: (_) => _markDirty(),
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _nomeController,
                        decoration: const InputDecoration(labelText: 'Nome *', border: OutlineInputBorder()),
                        validator: (value) => (value == null || value.trim().isEmpty) ? 'Il nome è obbligatorio' : null,
                        onChanged: (_) => _markDirty(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _cognomeController,
                        decoration: const InputDecoration(labelText: 'Cognome *', border: OutlineInputBorder()),
                        validator: (value) => (value == null || value.trim().isEmpty) ? 'Il cognome è obbligatorio' : null,
                        onChanged: (_) => _markDirty(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                TextFormField(
                  controller: _strutturaController,
                  decoration: const InputDecoration(labelText: 'Struttura *', border: OutlineInputBorder()),
                  validator: (value) => (value == null || value.trim().isEmpty) ? 'La struttura è obbligatoria' : null,
                  onChanged: (_) => _markDirty(),
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
                  onChanged: (_) => _markDirty(),
                ),
                const SizedBox(height: 25),
                Text('Ruoli', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (_ruoliEntries.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 8.0), child: Text('Nessun ruolo aggiunto.', style: TextStyle(color: Colors.grey[600]))),
                ..._ruoliEntries.map((entry) => _buildRuoloEntryRow(entry)),
                Align(alignment: Alignment.centerRight, child: TextButton.icon(icon: const Icon(Icons.add_circle_outline), label: const Text('Aggiungi Ruolo'), onPressed: _addRuoloEntry)),
                const SizedBox(height: 20),
                Text('Altre Emails', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (_altreEmailEntries.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 8.0), child: Text('Nessuna email aggiuntiva.', style: TextStyle(color: Colors.grey[600]))),
                ..._altreEmailEntries.map((entry) => _buildContactEntryRow(
                      entry: entry,
                      valueLabel: 'Email (v)',
                      tagHint: 'Es. Lavoro, Personale (t)',
                      valueHint: 'indirizzo@email.com (v)',
                      onRemove: () => _removeAltraEmailEntry(entry),
                      valueInputType: TextInputType.emailAddress,
                      valueIcon: Icons.alternate_email,
                      valueValidator: (value) {
                        if (entry.tagController.text.trim().isNotEmpty && (value == null || value.trim().isEmpty)) {
                          return 'L\'email (v) è richiesta se l\'etichetta (t) è specificata';
                        }
                        if (value != null && value.trim().isNotEmpty && !GetUtils.isEmail(value.trim())) {
                          return 'Formato email (v) non valido';
                        }
                        return null;
                      },
                    )),
                Align(alignment: Alignment.centerRight, child: TextButton.icon(icon: const Icon(Icons.add_circle_outline), label: const Text('Aggiungi Email'), onPressed: _addAltraEmailEntry)),
                const SizedBox(height: 20),
                Text('Telefoni', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (_phoneEntries.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 8.0), child: Text('Nessun telefono aggiunto.', style: TextStyle(color: Colors.grey[600]))),
                ..._phoneEntries.map((entry) => _buildContactEntryRow(
                      entry: entry,
                      valueLabel: 'Numero Telefono (v)',
                      tagHint: 'Es. Cellulare, Ufficio (t)',
                      valueHint: 'Numero di telefono (v)',
                      onRemove: () => _removePhoneEntry(entry),
                      valueInputType: TextInputType.phone,
                      valueIcon: Icons.phone,
                      valueValidator: (value) {
                        if (entry.tagController.text.trim().isNotEmpty && (value == null || value.trim().isEmpty)) {
                          return 'Il numero (v) è richiesto se l\'etichetta (t) è specificata';
                        }
                        return null;
                      },
                    )),
                Align(alignment: Alignment.centerRight, child: TextButton.icon(icon: const Icon(Icons.add_circle_outline), label: const Text('Aggiungi Telefono'), onPressed: _addPhoneEntry)),
                const SizedBox(height: 20),
                TextFormField(controller: _cvController, decoration: const InputDecoration(labelText: 'CV (URL o testo)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.description)), maxLines: 3, onChanged: (_) => _markDirty()),
                const SizedBox(height: 15),
                TextFormField(controller: _noteBiograficheController, decoration: const InputDecoration(labelText: 'Note Biografiche', border: OutlineInputBorder(), prefixIcon: Icon(Icons.notes)), maxLines: 5, onChanged: (_) => _markDirty()),
                const SizedBox(height: 15),
                TextFormField(
                  controller: _rssController,
                  decoration: const InputDecoration(labelText: 'RSS Feed URL', border: OutlineInputBorder(), prefixIcon: Icon(Icons.rss_feed)),
                  keyboardType: TextInputType.url,
                  validator: (value) => (value != null && value.trim().isNotEmpty && Uri.tryParse(value.trim())?.hasAbsolutePath != true) ? 'Inserisci un URL valido' : null,
                  onChanged: (_) => _markDirty(),
                ),
                const SizedBox(height: 15),
                TextFormField(
                  controller: _webController,
                  decoration: const InputDecoration(labelText: 'Sito Web URL', border: OutlineInputBorder(), prefixIcon: Icon(Icons.web)),
                  keyboardType: TextInputType.url,
                  validator: (value) => (value != null && value.trim().isNotEmpty && Uri.tryParse(value.trim())?.hasAbsolutePath != true) ? 'Inserisci un URL valido' : null,
                  onChanged: (_) => _markDirty(),
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
                      style: ElevatedButton.styleFrom(
                        disabledForegroundColor: Colors.grey.withOpacity(0.38),
                        disabledBackgroundColor: Colors.grey.withOpacity(0.12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
        if (_isLoading && ModalRoute.of(context)?.isCurrent == true) // Mostra solo se questo modale è quello corrente
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
