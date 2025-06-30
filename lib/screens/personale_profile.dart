// lib/screens/personale_profile.dart
// ignore_for_file: avoid_print, deprecated_member_use, non_constant_identifier_names

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:una_social/controllers/personale_controller.dart';
import 'package:una_social/helpers/avatar_helper.dart'; // Assicurati che il percorso sia corretto
import 'package:una_social/models/personale.dart';

// --- Classi Helper (invariate) ---

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

class RuoloEntryItem {
  final TextEditingController controller;
  final UniqueKey uniqueKey = UniqueKey();
  RuoloEntryItem({String testo = ''}) : controller = TextEditingController(text: testo);
  String get text => controller.text.trim();
  void dispose() => controller.dispose();
}

class StrutturaItem {
  final String universita, id, nome;
  StrutturaItem({required this.universita, required this.id, required this.nome});
  @override
  String toString() => nome;
  factory StrutturaItem.fromJson(Map<String, dynamic> json) => StrutturaItem(
        universita: json['universita'] as String? ?? '',
        id: json['id']?.toString() ?? '',
        nome: json['nome'] as String? ?? '',
      );
  @override
  bool operator ==(Object other) => other is StrutturaItem && id == other.id && universita == other.universita;
  @override
  int get hashCode => id.hashCode ^ universita.hashCode;
}

// --- Widget Principale ---

class PersonaleProfile extends StatefulWidget {
  final Personale initialPersonale;
  const PersonaleProfile({super.key, required this.initialPersonale});

  @override
  State<PersonaleProfile> createState() => _PersonaleProfileState();
}

class _PersonaleProfileState extends State<PersonaleProfile> {
  final _formKey = GlobalKey<FormState>();
  final _personaleController = Get.find<PersonaleController>();
  final _supabase = Supabase.instance.client;

  late TextEditingController _enteController;
  late TextEditingController _emailPrincipaleController;
  late TextEditingController _nomeController;
  late TextEditingController _cognomeController;
  late TextEditingController _photoUrlController;
  late TextEditingController _cvController;
  late TextEditingController _noteBiograficheController;
  late TextEditingController _rssController;
  late TextEditingController _webController;
  late TextEditingController _strutturaInputController;

  StrutturaItem? _selectedStrutturaItem;
  bool _isLoadingStrutture = false;
  final List<RuoloEntryItem> _ruoliEntries = [];
  final List<ContactEntryItem> _altreEmailEntries = [];
  final List<ContactEntryItem> _phoneEntries = [];

  bool _isDirty = false;
  bool _isLoading = false;
  String? _currentDisplayImageUrl;
  bool _isLoadingDisplayImageUrl = true;
  bool _displayImageFailedToLoad = false;

  final String _bucketName = 'una-bucket';
  final String _baseFolderPath = 'personale/foto';

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _initializeDynamicLists();
    _addListeners();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _updateAvatarDisplay();
        _loadInitialStrutturaIfNeeded();
      }
    });
  }

  @override
  void dispose() {
    _enteController.removeListener(_handleEnteChange);
    _strutturaInputController.removeListener(_handleStrutturaInputChange);
    final allControllers = [_enteController, _emailPrincipaleController, _nomeController, _cognomeController, _photoUrlController, _cvController, _noteBiograficheController, _rssController, _webController, _strutturaInputController];
    for (final controller in allControllers) {
      controller.removeListener(_markDirty);
      controller.dispose();
    }
    for (final entry in _ruoliEntries) {
      entry.dispose();
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
    _enteController = TextEditingController(text: widget.initialPersonale.ente);
    _emailPrincipaleController = TextEditingController(text: widget.initialPersonale.emailPrincipale);
    _nomeController = TextEditingController(text: widget.initialPersonale.nome);
    _cognomeController = TextEditingController(text: widget.initialPersonale.cognome);
    _photoUrlController = TextEditingController(text: widget.initialPersonale.photoUrl);
    _cvController = TextEditingController(text: widget.initialPersonale.cv);
    _noteBiograficheController = TextEditingController(text: widget.initialPersonale.noteBiografiche);
    _rssController = TextEditingController(text: widget.initialPersonale.rss);
    _webController = TextEditingController(text: widget.initialPersonale.web);
    _strutturaInputController = TextEditingController();
  }

  void _initializeDynamicLists() {
    _ruoliEntries.clear();
    widget.initialPersonale.ruoli?.forEach((ruolo) {
      _ruoliEntries.add(RuoloEntryItem(testo: ruolo));
    });
    _altreEmailEntries.clear();
    widget.initialPersonale.altreEmails?.forEach((email) {
      _altreEmailEntries.add(ContactEntryItem(t: email['t'] ?? '', v: email['v'] ?? ''));
    });
    _phoneEntries.clear();
    widget.initialPersonale.telefoni?.forEach((phone) {
      _phoneEntries.add(ContactEntryItem(t: phone['t'] ?? '', v: phone['v'] ?? ''));
    });
  }

  void _addListeners() {
    final staticControllers = [_emailPrincipaleController, _nomeController, _cognomeController, _photoUrlController, _cvController, _noteBiograficheController, _rssController, _webController];
    for (final controller in staticControllers) {
      controller.addListener(_markDirty);
    }
    _enteController.addListener(_handleEnteChange);
    _strutturaInputController.addListener(_handleStrutturaInputChange);
    for (final entry in _ruoliEntries) {
      entry.controller.addListener(_markDirty);
    }
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

  void _handleEnteChange() {
    _markDirty();
    if (mounted && widget.initialPersonale.ente.trim() != _enteController.text.trim()) {
      setState(() {
        _strutturaInputController.clear();
        _selectedStrutturaItem = null;
      });
    }
  }

  void _handleStrutturaInputChange() {
    if (_selectedStrutturaItem != null && _strutturaInputController.text.trim() != _selectedStrutturaItem!.nome) {
      setState(() => _selectedStrutturaItem = null);
    }
    _markDirty();
  }

  void _loadInitialStrutturaIfNeeded() {
    final ente = widget.initialPersonale.ente.trim();
    final codice = widget.initialPersonale.struttura;
    if (ente.isNotEmpty) {
      _loadInitialStruttura(codice.toString(), ente);
    }
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
        user: widget.initialPersonale,
        email: widget.initialPersonale.emailPrincipale,
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

  Future<void> _loadInitialStruttura(String codice, String ente) async {
    if (!mounted) return;
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    setState(() => _isLoadingStrutture = true);
    try {
      final response = await _supabase.from('strutture').select('universita,id,nome').eq('universita', ente).eq('id', codice).maybeSingle();
      if (!mounted) return;
      if (response != null) {
        final struttura = StrutturaItem.fromJson(response);
        setState(() {
          _selectedStrutturaItem = struttura;
          _strutturaInputController.text = struttura.nome;
        });
      } else {
        scaffoldMessenger.showSnackBar(SnackBar(content: Text('Struttura "$codice" non trovata.'), backgroundColor: Colors.orange));
      }
    } catch (e) {
      if (mounted) scaffoldMessenger.showSnackBar(SnackBar(content: Text('Errore caricamento struttura: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoadingStrutture = false);
    }
  }

  // *** METODO RIPRISTINATO ***
  Future<Iterable<StrutturaItem>> _fetchStruttureSuggestions(TextEditingValue textEditingValue) async {
    final inputText = textEditingValue.text.trim();
    final currentEnte = _enteController.text.trim();
    if (inputText.length < 3 || currentEnte.isEmpty || !mounted) {
      return const Iterable.empty();
    }
    try {
      final isNumeric = RegExp(r'^[0-9]+$').hasMatch(inputText);
      var query = _supabase.from('strutture').select('universita, id, nome').eq('universita', currentEnte);
      query = isNumeric ? query.like('id', '%$inputText%') : query.ilike('nome', '%$inputText%');
      final response = await query.limit(15);
      return List<Map<String, dynamic>>.from(response).map((data) => StrutturaItem.fromJson(data));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore ricerca strutture: $e'), backgroundColor: Colors.red),
        );
      }
      return const Iterable.empty();
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
      final fileName = '${_enteController.text.trim().replaceAll(' ', '_')}_${widget.initialPersonale.id}.jpg';
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
      'ente': _enteController.text.trim(),
      'struttura': _selectedStrutturaItem?.id,
      'email_principale': _emailPrincipaleController.text.trim(),
      'nome': _nomeController.text.trim(),
      'cognome': _cognomeController.text.trim(),
      'photo_url': _photoUrlController.text.trim().isEmpty ? null : _photoUrlController.text.trim(),
      'cv': _cvController.text.trim().isEmpty ? null : _cvController.text.trim(),
      'note_biografiche': _noteBiograficheController.text.trim().isEmpty ? null : _noteBiograficheController.text.trim(),
      'rss': _rssController.text.trim().isEmpty ? null : _rssController.text.trim(),
      'web': _webController.text.trim().isEmpty ? null : _webController.text.trim(),
      'ruoli': _ruoliEntries.map((e) => e.text).where((t) => t.isNotEmpty).toList(),
      'altre_emails': _altreEmailEntries.map((e) => e.toMapForDb()).where((m) => m['v']!.isNotEmpty).toList(),
      'telefoni': _phoneEntries.map((e) => e.toMapForDb()).where((m) => m['v']!.isNotEmpty).toList(),
    };
    try {
      await _supabase.from('personale').update(updateData).eq('id', widget.initialPersonale.id);
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Profilo aggiornato!'), backgroundColor: Colors.green));
      await _personaleController.reload();
      if (!mounted) return;
      setState(() => _isDirty = false);
    } catch (e) {
      if (mounted) scaffoldMessenger.showSnackBar(SnackBar(content: Text('Errore durante l\'aggiornamento: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _addRuoloEntry() => setState(() {
        final e = RuoloEntryItem();
        e.controller.addListener(_markDirty);
        _ruoliEntries.add(e);
        _markDirty();
      });
  void _removeRuoloEntry(RuoloEntryItem entry) => setState(() {
        entry.dispose();
        _ruoliEntries.remove(entry);
        _markDirty();
      });
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
                TextFormField(
                    controller: _photoUrlController,
                    decoration: const InputDecoration(labelText: 'Photo Path/URL', border: OutlineInputBorder(), prefixIcon: Icon(Icons.link)),
                    onChanged: (v) {
                      _markDirty();
                      _updateAvatarDisplay();
                    }),
                const SizedBox(height: 20),
                TextFormField(controller: _enteController, decoration: const InputDecoration(labelText: 'Ente *', border: OutlineInputBorder()), validator: (v) => (v == null || v.trim().isEmpty) ? 'L\'ente è obbligatorio' : null),
                const SizedBox(height: 15),
                Row(children: [
                  Expanded(child: TextFormField(controller: _nomeController, decoration: const InputDecoration(labelText: 'Nome *', border: OutlineInputBorder()), validator: (v) => (v == null || v.trim().isEmpty) ? 'Il nome è obbligatorio' : null)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: TextFormField(controller: _cognomeController, decoration: const InputDecoration(labelText: 'Cognome *', border: OutlineInputBorder()), validator: (v) => (v == null || v.trim().isEmpty) ? 'Il cognome è obbligatorio' : null)),
                ]),
                const SizedBox(height: 15),
                _buildStrutturaAutocomplete(),
                const SizedBox(height: 15),
                TextFormField(
                    controller: _emailPrincipaleController,
                    decoration: const InputDecoration(labelText: 'Email Principale *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.email)),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'L\'email è obbligatoria';
                      if (!GetUtils.isEmail(v.trim())) return 'Formato non valido';
                      return null;
                    }),
                const SizedBox(height: 25),
                _buildDynamicSection('Ruoli', _ruoliEntries, _addRuoloEntry, _buildRuoloEntryRow),
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
                TextFormField(controller: _cvController, decoration: const InputDecoration(labelText: 'CV (URL o testo)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.description)), maxLines: 3),
                const SizedBox(height: 15),
                TextFormField(controller: _noteBiograficheController, decoration: const InputDecoration(labelText: 'Note Biografiche', border: OutlineInputBorder(), prefixIcon: Icon(Icons.notes)), maxLines: 5),
                const SizedBox(height: 15),
                TextFormField(
                    controller: _rssController,
                    decoration: const InputDecoration(labelText: 'RSS Feed URL', border: OutlineInputBorder(), prefixIcon: Icon(Icons.rss_feed)),
                    keyboardType: TextInputType.url,
                    validator: (v) => (v != null && v.isNotEmpty && Uri.tryParse(v)?.hasAbsolutePath != true) ? 'URL non valido' : null),
                const SizedBox(height: 15),
                TextFormField(
                    controller: _webController,
                    decoration: const InputDecoration(labelText: 'Sito Web URL', border: OutlineInputBorder(), prefixIcon: Icon(Icons.web)),
                    keyboardType: TextInputType.url,
                    validator: (v) => (v != null && v.isNotEmpty && Uri.tryParse(v)?.hasAbsolutePath != true) ? 'URL non valido' : null),
                const SizedBox(height: 25),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  TextButton(onPressed: _isLoading ? null : () => Navigator.of(context).pop(), child: const Text('Annulla')),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                      icon: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save),
                      label: const Text('Aggiorna'),
                      onPressed: (_isDirty && !_isLoading) ? _updateProfile : null),
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

  Widget _buildStrutturaAutocomplete() {
    return Autocomplete<StrutturaItem>(
      optionsBuilder: _fetchStruttureSuggestions, // <-- Usa il metodo ripristinato
      displayStringForOption: (option) => option.nome,
      onSelected: (selection) {
        setState(() {
          _selectedStrutturaItem = selection;
          _strutturaInputController.text = selection.nome;
          _markDirty();
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _formKey.currentState?.validate();
        });
      },
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
        if (_strutturaInputController.text != controller.text) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) controller.text = _strutturaInputController.text;
          });
        }
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
              labelText: 'Struttura *',
              hintText: _enteController.text.trim().isEmpty ? 'Seleziona prima un Ente' : 'Digita per cercare...',
              border: const OutlineInputBorder(),
              suffixIcon: _isLoadingStrutture ? const Padding(padding: EdgeInsets.all(12.0), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))) : null),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'La struttura è obbligatoria.';
            if (_selectedStrutturaItem == null) return 'Seleziona una struttura valida.';
            return null;
          },
          onChanged: (text) => _strutturaInputController.text = text,
        );
      },
    );
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

  Widget _buildRuoloEntryRow(RuoloEntryItem entry) {
    return Padding(
        key: entry.uniqueKey,
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(children: [
          Expanded(child: TextFormField(controller: entry.controller, decoration: const InputDecoration(labelText: 'Ruolo', border: OutlineInputBorder(), isDense: true))),
          IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.red), onPressed: () => _removeRuoloEntry(entry))
        ]));
  }

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
}
