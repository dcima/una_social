// lib/screens/esterni_profile.dart
// ignore_for_file: avoid_print, deprecated_member_use, non_constant_identifier_names

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:una_social/controllers/esterni_controller.dart';
import 'package:una_social/helpers/avatar_helper.dart';
import 'package:una_social/models/esterni.dart';
import 'package:una_social/models/i_user_profile.dart';

// --- CLASSE HELPER PER GESTIRE I CAMPI DI CONTATTO ---
// Esattamente come quella usata nel profilo Personale
class ContactEntryItem {
  final TextEditingController tagController;
  final TextEditingController valueController;
  final UniqueKey uniqueKey = UniqueKey();

  ContactEntryItem({required String t, required String v})
      : tagController = TextEditingController(text: t),
        valueController = TextEditingController(text: v);

  Map<String, String> toMapForDb() => {'t': tagController.text.trim(), 'v': valueController.text.trim()};

  void dispose() {
    tagController.dispose();
    valueController.dispose();
  }
}

class EsterniProfile extends StatefulWidget {
  final Esterni initialEsterni;
  const EsterniProfile({super.key, required this.initialEsterni});

  @override
  State<EsterniProfile> createState() => _EsterniProfileState();
}

class _EsterniProfileState extends State<EsterniProfile> {
  final _formKey = GlobalKey<FormState>();
  final _esterniController = Get.find<EsterniController>();
  final _supabase = Supabase.instance.client;

  late TextEditingController _emailPrincipaleController;
  late TextEditingController _nomeController;
  late TextEditingController _cognomeController;
  late TextEditingController _photoUrlController;

  // Le liste ora usano ContactEntryItem per gestire i due campi
  final List<ContactEntryItem> _altreEmailEntries = [];
  final List<ContactEntryItem> _phoneEntries = [];

  bool _isDirty = false;
  bool _isLoading = false;
  String? _currentDisplayImageUrl;
  bool _isLoadingDisplayImageUrl = true;
  bool _displayImageFailedToLoad = false;

  final String _bucketName = 'una-bucket';
  final String _baseFolderPath = 'esterni/foto';

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _initializeDynamicLists();
    _addListeners();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updateAvatarDisplay();
    });
  }

  @override
  void dispose() {
    final allControllers = [_emailPrincipaleController, _nomeController, _cognomeController, _photoUrlController];
    for (final controller in allControllers) {
      controller.removeListener(_markDirty);
      controller.dispose();
    }
    for (final entry in _altreEmailEntries) {
      entry.dispose();
    }
    for (final entry in _phoneEntries) {
      entry.dispose();
    }
    super.dispose();
  }

  void _initializeControllers() {
    _emailPrincipaleController = TextEditingController(text: widget.initialEsterni.emailPrincipale);
    _nomeController = TextEditingController(text: widget.initialEsterni.nome);
    _cognomeController = TextEditingController(text: widget.initialEsterni.cognome);
    _photoUrlController = TextEditingController(text: widget.initialEsterni.photoUrl);
  }

  void _initializeDynamicLists() {
    _altreEmailEntries.clear();
    // Inizializza leggendo i valori 't' e 'v' dalla mappa
    widget.initialEsterni.altreEmails?.forEach((emailMap) {
      _altreEmailEntries.add(ContactEntryItem(t: emailMap['t'] ?? '', v: emailMap['v'] ?? ''));
    });
    _phoneEntries.clear();
    widget.initialEsterni.telefoni?.forEach((phoneMap) {
      _phoneEntries.add(ContactEntryItem(t: phoneMap['t'] ?? '', v: phoneMap['v'] ?? ''));
    });
  }

  void _addListeners() {
    final staticControllers = [_emailPrincipaleController, _nomeController, _cognomeController, _photoUrlController];
    for (final controller in staticControllers) {
      controller.addListener(_markDirty);
    }
    // Aggiunge i listener per entrambi i controller di ogni riga
    for (final entry in _altreEmailEntries) {
      entry.tagController.addListener(_markDirty);
      entry.valueController.addListener(_markDirty);
    }
    for (final entry in _phoneEntries) {
      entry.tagController.addListener(_markDirty);
      entry.valueController.addListener(_markDirty);
    }
  }

  void _markDirty() {
    if (!_isDirty && mounted) setState(() => _isDirty = true);
  }

  Future<void> _updateAvatarDisplay() async {
    if (!mounted) return;
    setState(() => _isLoadingDisplayImageUrl = true);
    final textInField = _photoUrlController.text.trim();
    String? finalUrl;
    if (textInField.isNotEmpty && textInField.startsWith('http')) {
      finalUrl = textInField;
    } else {
      finalUrl = await AvatarHelper.getDisplayAvatarUrl(
        user: widget.initialEsterni as IUserProfile?,
        email: widget.initialEsterni.emailPrincipale,
      );
    }
    if (mounted) {
      setState(() {
        _currentDisplayImageUrl = finalUrl;
        _isLoadingDisplayImageUrl = false;
        _displayImageFailedToLoad = false;
      });
    }
  }

  Future<void> _pickAndUploadImage() async {
    if (!mounted) return;
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    setState(() => _isLoading = true);
    try {
      final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 800, maxHeight: 800);
      if (pickedFile == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      final imageBytes = await pickedFile.readAsBytes();
      final fileName = '${widget.initialEsterni.emailPrincipale}.jpg';
      final filePath = '$_baseFolderPath/$fileName';
      await _supabase.storage.from(_bucketName).uploadBinary(filePath, imageBytes, fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true));
      if (!mounted) return;
      _photoUrlController.text = filePath;
      _markDirty();
      await _updateAvatarDisplay();
      scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Immagine caricata con successo.'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) scaffoldMessenger.showSnackBar(SnackBar(content: Text('Errore durante il caricamento: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateProfile() async {
    if (!mounted) return;
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    if (!(_formKey.currentState?.validate() ?? false)) {
      scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Per favore, correggi gli errori.'), backgroundColor: Colors.orange));
      return;
    }
    if (!_isDirty) {
      scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Nessuna modifica rilevata.'), backgroundColor: Colors.blueGrey));
      return;
    }
    setState(() => _isLoading = true);

    final updateData = {
      // 'auth_uuid' non viene aggiornato, è gestito dal trigger o al momento della creazione
      'email_principale': _emailPrincipaleController.text.trim(),
      'nome': _nomeController.text.trim(),
      'cognome': _cognomeController.text.trim(),
      'photo_url': _photoUrlController.text.trim().isEmpty ? null : _photoUrlController.text.trim(),
      // Usa toMapForDb() per creare la struttura dati corretta
      'altre_emails': _altreEmailEntries.map((e) => e.toMapForDb()).where((m) => m['v']!.isNotEmpty).toList(),
      'telefoni': _phoneEntries.map((e) => e.toMapForDb()).where((m) => m['v']!.isNotEmpty).toList(),
    };

    try {
      if (widget.initialEsterni.id.isEmpty) {
        // Logica per inserire un nuovo profilo
        updateData['auth_uuid'] = widget.initialEsterni.authUuid; // Aggiungi l'auth_uuid solo alla creazione
        await _supabase.from('esterni').insert(updateData);
        scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Profilo creato con successo!'), backgroundColor: Colors.green));
      } else {
        // Logica per aggiornare un profilo esistente
        await _supabase.from('esterni').update(updateData).eq('id', widget.initialEsterni.id);
        scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Profilo aggiornato!'), backgroundColor: Colors.green));
      }
      await _esterniController.reload();
      if (!mounted) return;
      setState(() => _isDirty = false);
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) scaffoldMessenger.showSnackBar(SnackBar(content: Text('Errore durante il salvataggio: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _addAltraEmailEntry() => setState(() {
        final e = ContactEntryItem(t: '', v: '');
        e.tagController.addListener(_markDirty);
        e.valueController.addListener(_markDirty);
        _altreEmailEntries.add(e);
        _markDirty();
      });
  void _removeAltraEmailEntry(ContactEntryItem entry) => setState(() {
        entry.dispose();
        _altreEmailEntries.remove(entry);
        _markDirty();
      });
  void _addPhoneEntry() => setState(() {
        final e = ContactEntryItem(t: '', v: '');
        e.tagController.addListener(_markDirty);
        e.valueController.addListener(_markDirty);
        _phoneEntries.add(e);
        _markDirty();
      });
  void _removePhoneEntry(ContactEntryItem entry) => setState(() {
        entry.dispose();
        _phoneEntries.remove(entry);
        _markDirty();
      });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildPhotoDisplay(),
                const SizedBox(height: 10),
                Center(child: ElevatedButton.icon(icon: const Icon(Icons.upload_file), label: const Text('Carica/Cambia Foto'), onPressed: _isLoading ? null : _pickAndUploadImage)),
                const SizedBox(height: 15),
                TextFormField(controller: _photoUrlController, decoration: const InputDecoration(labelText: 'Photo Path/URL', border: OutlineInputBorder(), prefixIcon: Icon(Icons.link)), onChanged: (v) => _markDirty()),
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(child: TextFormField(controller: _nomeController, decoration: const InputDecoration(labelText: 'Nome *', border: OutlineInputBorder()), validator: (v) => (v == null || v.trim().isEmpty) ? 'Il nome è obbligatorio' : null)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: TextFormField(controller: _cognomeController, decoration: const InputDecoration(labelText: 'Cognome *', border: OutlineInputBorder()), validator: (v) => (v == null || v.trim().isEmpty) ? 'Il cognome è obbligatorio' : null)),
                ]),
                const SizedBox(height: 15),
                TextFormField(
                    controller: _emailPrincipaleController,
                    readOnly: true,
                    decoration: InputDecoration(labelText: 'Email Principale', border: const OutlineInputBorder(), prefixIcon: Icon(Icons.email), fillColor: Colors.grey.shade200),
                    style: TextStyle(color: Colors.grey.shade700)),
                const SizedBox(height: 25),
                // --- SEZIONI DINAMICHE AGGIORNATE CON LA UI CORRETTA ---
                _buildDynamicSection(
                    'Altre Emails',
                    _altreEmailEntries,
                    _addAltraEmailEntry,
                    (entry) => _buildContactEntryRow(
                        entry: entry,
                        onRemove: () => _removeAltraEmailEntry(entry),
                        valueLabel: 'Email',
                        tagHint: 'Es. Lavoro',
                        valueHint: 'indirizzo@email.com',
                        valueInputType: TextInputType.emailAddress,
                        valueIcon: Icons.alternate_email,
                        valueValidator: (v) => (v != null && v.isNotEmpty && !GetUtils.isEmail(v)) ? 'Formato email non valido' : null)),
                _buildDynamicSection(
                    'Telefoni',
                    _phoneEntries,
                    _addPhoneEntry,
                    (entry) =>
                        _buildContactEntryRow(entry: entry, onRemove: () => _removePhoneEntry(entry), valueLabel: 'Telefono', tagHint: 'Es. Ufficio', valueHint: 'Numero', valueInputType: TextInputType.phone, valueIcon: Icons.phone, valueValidator: null)),
                const SizedBox(height: 25),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  TextButton(onPressed: _isLoading ? null : () => Navigator.of(context).pop(), child: const Text('Annulla')),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                      icon: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save),
                      label: Text(widget.initialEsterni.id.isEmpty ? 'Crea Profilo' : 'Aggiorna'),
                      onPressed: _isLoading ? null : _updateProfile),
                ]),
              ],
            ),
          ),
        ),
        if (_isLoading) Positioned.fill(child: Container(color: Colors.black.withOpacity(0.5), child: const Center(child: CircularProgressIndicator()))),
      ],
    );
  }

  Widget _buildPhotoDisplay() {
    const double avatarSize = 100.0;
    Widget content;
    if (_isLoadingDisplayImageUrl) {
      content = const Center(child: CircularProgressIndicator());
    } else if (_displayImageFailedToLoad || _currentDisplayImageUrl == null || _currentDisplayImageUrl!.isEmpty) {
      content = Tooltip(
        message: _displayImageFailedToLoad ? "Errore caricamento immagine" : "Nessuna immagine",
        child: Container(
          decoration: BoxDecoration(color: _displayImageFailedToLoad ? Colors.red.shade100 : Colors.grey.shade200, shape: BoxShape.circle),
          child: Icon(_displayImageFailedToLoad ? Icons.broken_image_outlined : Icons.person_outline, size: avatarSize * 0.6, color: _displayImageFailedToLoad ? Colors.red.shade400 : Colors.grey.shade400),
        ),
      );
    } else {
      content = ClipOval(
        child: Image.network(
          _currentDisplayImageUrl!,
          key: ValueKey(_currentDisplayImageUrl!),
          width: avatarSize,
          height: avatarSize,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) => progress == null ? child : const Center(child: CircularProgressIndicator()),
          errorBuilder: (context, error, stackTrace) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && !_displayImageFailedToLoad) setState(() => _displayImageFailedToLoad = true);
            });
            return const SizedBox.shrink();
          },
        ),
      );
    }
    return Center(child: SizedBox(width: avatarSize, height: avatarSize, child: content));
  }

  // --- WIDGET PER LA RIGA DI CONTATTO CON ETICHETTA E VALORE ---
  Widget _buildContactEntryRow(
      {required ContactEntryItem entry,
      required VoidCallback onRemove,
      required String valueLabel,
      required String tagHint,
      required String valueHint,
      required TextInputType valueInputType,
      required IconData valueIcon,
      String? Function(String?)? valueValidator}) {
    return Padding(
        key: entry.uniqueKey,
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 2, child: TextFormField(controller: entry.tagController, decoration: InputDecoration(labelText: 'Etichetta', hintText: tagHint, border: const OutlineInputBorder(), isDense: true))),
          const SizedBox(width: 8),
          Expanded(
              flex: 3,
              child: TextFormField(
                  controller: entry.valueController,
                  decoration: InputDecoration(labelText: valueLabel, hintText: valueHint, border: const OutlineInputBorder(), prefixIcon: Icon(valueIcon), isDense: true),
                  keyboardType: valueInputType,
                  validator: valueValidator)),
          IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.red), onPressed: onRemove)
        ]));
  }

  Widget _buildDynamicSection<T>(String title, List<T> entries, VoidCallback onAdd, Widget Function(T) itemBuilder) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      if (entries.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 8.0), child: Text('Nessun elemento.', style: TextStyle(color: Colors.grey[600]))),
      ...entries.map(itemBuilder),
      Align(alignment: Alignment.centerRight, child: TextButton.icon(icon: const Icon(Icons.add_circle_outline), label: Text('Aggiungi'), onPressed: onAdd)),
      const SizedBox(height: 20),
    ]);
  }
}
