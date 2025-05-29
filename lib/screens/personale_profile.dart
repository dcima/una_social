// lib/personale_profile.dart
// ignore_for_file: avoid_print, deprecated_member_use, non_constant_identifier_names

import 'dart:typed_data'; // Required for Uint8List
import 'package:flutter/material.dart';
import 'package:get/get.dart'; // Per GetUtils.isEmail
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:una_social/controllers/personale_controller.dart';
import 'package:una_social/models/personale.dart';

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
    controller.dispose();
  }
}

// Helper per le Strutture
class StrutturaItem {
  final String universita;
  final String id;
  final String nome;

  StrutturaItem({
    required this.universita,
    required this.id,
    required this.nome,
  });

  @override
  String toString() => nome;

  factory StrutturaItem.fromJson(Map<String, dynamic> json) {
    return StrutturaItem(
      universita: json['universita'] as String? ?? '', // Più robusto a null
      id: json['id']?.toString() ?? '', // Converti a String e gestisci null
      nome: json['nome'] as String? ?? '', // Più robusto a null
    );
  }

  @override
  bool operator ==(Object other) => identical(this, other) || other is StrutturaItem && runtimeType == other.runtimeType && id == other.id && universita == other.universita;

  @override
  int get hashCode => id.hashCode ^ universita.hashCode;
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

  XFile? _pickedImageFile;
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
    _addListenersToStaticControllers(); // Chiamare prima di _addListenersToDynamicEntries se le liste dinamiche dipendono da controller statici (non in questo caso)
    _addListenersToDynamicEntries();
    _fetchDisplayImageUrl();

    final String initialEnte = (widget.initialPersonale.ente).trim();
    final String initialStrutturaCodice = (widget.initialPersonale.struttura).trim();

    if (initialStrutturaCodice.isNotEmpty && initialEnte.isNotEmpty) {
      _loadInitialStruttura(initialStrutturaCodice, initialEnte);
    } else {
      print('_PersonaleProfileState.initState: Skipping _loadInitialStruttura. Ente: "$initialEnte", StrutturaCodice: "$initialStrutturaCodice"');
    }
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

  Future<void> _loadInitialStruttura(String strutturaCodiceInput, String enteCodiceInput) async {
    final String strutturaCodice = strutturaCodiceInput.trim();
    final String enteCodice = enteCodiceInput.trim();

    print('_loadInitialStruttura: Attempting to load struttura "$strutturaCodice" for ente "$enteCodice"');

    if (strutturaCodice.isEmpty || enteCodice.isEmpty) {
      print('_loadInitialStruttura: Aborted. Ente or StrutturaCodice is empty after trim.');
      return;
    }

    if (!mounted) return;
    setState(() => _isLoadingStrutture = true);

    try {
      final response = await _supabase
          .from('strutture')
          .select('universita, id, nome') // Nomi campi corretti e senza spazi extra
          .eq('universita', enteCodice)
          .eq('id', strutturaCodice)
          .maybeSingle();

      print('_loadInitialStruttura: Response from Supabase: $response');

      if (response != null && mounted) {
        final struttura = StrutturaItem.fromJson(response);
        setState(() {
          _selectedStrutturaItem = struttura;
          _strutturaInputController.text = struttura.nome;
          print('_loadInitialStruttura: Successfully loaded: ${struttura.nome} (ID: ${struttura.id}, Ente: ${struttura.universita})');
        });
      } else {
        print('_loadInitialStruttura: Struttura NOT FOUND for codice "$strutturaCodice" / ente "$enteCodice". Response was null.');
        if (mounted) {
          _strutturaInputController.text = widget.initialPersonale.struttura.trim();
          _selectedStrutturaItem = null;
          if (ScaffoldMessenger.maybeOf(context) != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Struttura "$strutturaCodice" non trovata per l\'ente "$enteCodice".'),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 5),
              ),
            );
          }
        }
      }
    } catch (e, s) {
      print('_loadInitialStruttura: ERROR fetching initial struttura: $e');
      print('_loadInitialStruttura: STACKTRACE: $s');
      if (mounted) {
        _strutturaInputController.text = widget.initialPersonale.struttura.trim();
        _selectedStrutturaItem = null;
        if (ScaffoldMessenger.maybeOf(context) != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Errore caricamento dati struttura: $e'), backgroundColor: Colors.red),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isLoadingStrutture = false);
    }
  }

  void _initializeDynamicLists() {
    _ruoliEntries.clear();
    for (var ruoloText in (widget.initialPersonale.ruoli ?? [])) {
      _ruoliEntries.add(RuoloEntryItem(testo: ruoloText));
    }

    _altreEmailEntries.clear();
    for (var emailMap in (widget.initialPersonale.altreEmails ?? [])) {
      _altreEmailEntries.add(ContactEntryItem(t: emailMap['t'] ?? '', v: emailMap['v'] ?? ''));
    }

    _phoneEntries.clear();
    for (var phoneMap in (widget.initialPersonale.telefoni ?? [])) {
      _phoneEntries.add(ContactEntryItem(t: phoneMap['t'] ?? '', v: phoneMap['v'] ?? ''));
    }
  }

  void _addListenersToStaticControllers() {
    final List<TextEditingController> staticControllers = [_emailPrincipaleController, _nomeController, _cognomeController, _photoUrlController, _cvController, _noteBiograficheController, _rssController, _webController];
    for (var controller in staticControllers) {
      controller.addListener(_markDirty);
    }

    _enteController.addListener(_handleEnteChange);
    _strutturaInputController.addListener(_handleStrutturaInputChange);
  }

  void _handleEnteChange() {
    _markDirty();
    if (mounted) {
      final String oldEnte = (widget.initialPersonale.ente).trim();
      final String newEnte = _enteController.text.trim();
      if (oldEnte != newEnte) {
        print('Ente changed from "$oldEnte" to "$newEnte". Resetting struttura field.');
        setState(() {
          _strutturaInputController.clear();
          _selectedStrutturaItem = null;
        });
        // Non è necessario validare il form qui, lo farà l'utente o il salvataggio
      }
    }
  }

  void _handleStrutturaInputChange() {
    final String currentInputText = _strutturaInputController.text.trim();
    if (currentInputText.isEmpty && _selectedStrutturaItem != null) {
      // Utente ha cancellato il testo, deseleziona
      setState(() => _selectedStrutturaItem = null);
      _markDirty();
    } else if (_selectedStrutturaItem != null && currentInputText != _selectedStrutturaItem!.nome) {
      // Utente ha modificato il testo di una struttura selezionata, invalidala
      setState(() => _selectedStrutturaItem = null);
      _markDirty();
    } else if (currentInputText.isNotEmpty && _selectedStrutturaItem == null) {
      // Utente sta scrivendo, non c'è ancora una selezione valida
      _markDirty();
    }
    // Se il testo corrisponde alla selezione, non fare nulla di speciale qui per _markDirty
    // _markDirty è già chiamato se il testo cambia
  }

  void _addListenersToDynamicEntries() {
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
    // Rimuovi prima i listener specifici
    _enteController.removeListener(_handleEnteChange);
    _strutturaInputController.removeListener(_handleStrutturaInputChange);

    // Lista di tutti i controller statici per dispose e rimozione _markDirty
    final List<TextEditingController> allStaticControllers = [
      _enteController, _emailPrincipaleController, _nomeController,
      _cognomeController, _photoUrlController, _cvController,
      _noteBiograficheController, _rssController, _webController,
      _strutturaInputController // Anche questo è un controller da disporre
    ];

    for (var controller in allStaticControllers) {
      // _markDirty potrebbe essere stato aggiunto più volte se non gestito attentamente,
      // ma removeListener lo rimuove solo una volta se presente.
      // Se hai aggiunto _markDirty specificamente a _enteController e _strutturaInputController,
      // assicurati che sia rimosso. Dato che _markDirty è generico, potrebbe essere sufficiente
      // la rimozione automatica con dispose se aggiunto come unico listener.
      // Per sicurezza, rimuovi esplicitamente:
      controller.removeListener(_markDirty); // Se _markDirty era un listener diretto
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
      // print("Marking dirty");
      setState(() => _isDirty = true);
    }
  }

  Future<void> _fetchDisplayImageUrl() async {
    if (!mounted) return;
    String photoUrl = widget.initialPersonale.photoUrl ?? '';
    String urlInController = _photoUrlController.text.trim();
    bool isControllerUrlValid = Uri.tryParse(urlInController)?.hasAbsolutePath == true;

    if (photoUrl.isNotEmpty) {
      if (mounted) {
        setState(() {
          _currentDisplayImageUrl = photoUrl;
          _isLoadingDisplayImageUrl = false;
          _displayImageFailedToLoad = false;
        });
      }
    } else if (isControllerUrlValid) {
      if (_currentDisplayImageUrl != urlInController || _displayImageFailedToLoad) {
        if (mounted) {
          setState(() {
            _currentDisplayImageUrl = urlInController;
            _isLoadingDisplayImageUrl = false;
            _displayImageFailedToLoad = false;
          });
        }
      } else {
        if (mounted && _isLoadingDisplayImageUrl) {
          setState(() => _isLoadingDisplayImageUrl = false);
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _currentDisplayImageUrl = null;
          _isLoadingDisplayImageUrl = false;
          _displayImageFailedToLoad = false;
        });
      }
    }
  }

  Future<Iterable<StrutturaItem>> _fetchStruttureSuggestions(TextEditingValue textEditingValue) async {
    final String inputText = textEditingValue.text.trim();
    final String currentEnte = _enteController.text.trim();

    if (inputText.length < 3 || currentEnte.isEmpty) {
      return const Iterable<StrutturaItem>.empty();
    }
    if (!mounted) return const Iterable<StrutturaItem>.empty();

    // setState(() => _isLoadingStrutture = true); // Potrebbe essere utile per feedback visivo
    try {
      final isNumeric = RegExp(r'^[0-9]+$').hasMatch(inputText);
      var query = _supabase.from('strutture').select('universita, id, nome').eq('universita', currentEnte);

      if (isNumeric) {
        query = query.like('id', '%$inputText%');
      } else {
        query = query.ilike('nome', '%$inputText%');
      }

      final response = await query.limit(15);

      // Supabase restituisce List<dynamic>, quindi castiamo esplicitamente
      final List<Map<String, dynamic>> dataList = List<Map<String, dynamic>>.from(response);
      final suggestions = dataList.map((data) => StrutturaItem.fromJson(data)).toList();
      return suggestions;
    } catch (e, s) {
      print('_fetchStruttureSuggestions: ERROR: $e');
      print('_fetchStruttureSuggestions: STACKTRACE: $s');
      if (mounted && ScaffoldMessenger.maybeOf(context) != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore ricerca strutture: $e'), backgroundColor: Colors.red),
        );
      }
      return const Iterable<StrutturaItem>.empty();
    } finally {
      // if (mounted) setState(() => _isLoadingStrutture = false);
    }
  }

  void _addRuoloEntry() {
    /* ... codice invariato ... */
    setState(() {
      final newEntry = RuoloEntryItem();
      newEntry.controller.addListener(_markDirty);
      _ruoliEntries.add(newEntry);
      _markDirty();
    });
  }

  void _removeRuoloEntry(RuoloEntryItem entry) {
    /* ... codice invariato ... */
    setState(() {
      entry.controller.removeListener(_markDirty);
      entry.dispose();
      _ruoliEntries.remove(entry);
      _markDirty();
    });
  }

  void _addAltraEmailEntry() {
    /* ... codice invariato ... */
    setState(() {
      final newEntry = ContactEntryItem(t: '', v: '');
      newEntry.tagController.addListener(_markDirty);
      newEntry.valueController.addListener(_markDirty);
      _altreEmailEntries.add(newEntry);
      _markDirty();
    });
  }

  void _removeAltraEmailEntry(ContactEntryItem entry) {
    /* ... codice invariato ... */
    setState(() {
      entry.tagController.removeListener(_markDirty);
      entry.valueController.removeListener(_markDirty);
      entry.dispose();
      _altreEmailEntries.remove(entry);
      _markDirty();
    });
  }

  void _addPhoneEntry() {
    /* ... codice invariato ... */
    setState(() {
      final newEntry = ContactEntryItem(t: '', v: '');
      newEntry.tagController.addListener(_markDirty);
      newEntry.valueController.addListener(_markDirty);
      _phoneEntries.add(newEntry);
      _markDirty();
    });
  }

  void _removePhoneEntry(ContactEntryItem entry) {
    /* ... codice invariato ... */
    setState(() {
      entry.tagController.removeListener(_markDirty);
      entry.valueController.removeListener(_markDirty);
      entry.dispose();
      _phoneEntries.remove(entry);
      _markDirty();
    });
  }

  Future<void> _pickAndUploadImage() async {
    /* ... codice invariato con aggiunta ScaffoldMessenger.maybeOf(context) ... */
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
      final String fileName = '${_enteController.text.trim().replaceAll(' ', '_')}_${widget.initialPersonale.id}.jpg'; // Usa l'ente dal controller
      final String filePath = '$_baseFolderPath/$fileName';

      await _supabase.storage.from(_bucketName).uploadBinary(
            filePath,
            imageBytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
          );

      final String publicUrl = _supabase.storage.from(_bucketName).getPublicUrl(filePath);
      final String urlWithTimestamp = "$publicUrl?t=${DateTime.now().millisecondsSinceEpoch}";

      if (mounted) {
        _photoUrlController.text = urlWithTimestamp;
        _markDirty();
        setState(() {
          _currentDisplayImageUrl = urlWithTimestamp;
          _displayImageFailedToLoad = false;
          _isLoadingDisplayImageUrl = false;
        });
        if (ScaffoldMessenger.maybeOf(context) != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Immagine caricata con successo.'), backgroundColor: Colors.green),
          );
        }
      }
      _pickedImageFile = null;
    } catch (e, s) {
      print('_pickAndUploadImage Error: $e, Stack: $s');
      if (mounted && ScaffoldMessenger.maybeOf(context) != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore caricamento immagine: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateProfile() async {
    /* ... codice invariato con aggiunta ScaffoldMessenger.maybeOf(context) e null check per struttura ... */
    if (!(_formKey.currentState?.validate() ?? false)) {
      if (mounted && ScaffoldMessenger.maybeOf(context) != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Per favore, correggi gli errori nel modulo.'), backgroundColor: Colors.orange),
        );
      }
      return;
    }
    if (!_isDirty) {
      if (mounted && ScaffoldMessenger.maybeOf(context) != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nessuna modifica rilevata.'), backgroundColor: Colors.blueGrey),
        );
      }
      return;
    }
    if (_isLoading) return;

    setState(() => _isLoading = true);

    final List<String> updatedRuoli = _ruoliEntries.map((e) => e.text).where((text) => text.isNotEmpty).toList();
    final List<Map<String, String>> updatedAltreEmails = _altreEmailEntries.map((e) => e.toMapForDb()).where((map) => map['v']!.isNotEmpty).toList();
    final List<Map<String, String>> updatedPhones = _phoneEntries.map((e) => e.toMapForDb()).where((map) => map['v']!.isNotEmpty).toList();

    final Map<String, dynamic> updateData = {
      'ente': _enteController.text.trim(),
      'struttura': _selectedStrutturaItem?.id, // Salva l'ID della struttura, sarà null se non selezionata
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
        if (ScaffoldMessenger.maybeOf(context) != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profilo aggiornato!'), backgroundColor: Colors.green),
          );
        }
        // Aggiorna initialPersonale.ente e initialPersonale.struttura per il listener di _enteController
        widget.initialPersonale.ente = _enteController.text.trim();
        widget.initialPersonale.struttura = _selectedStrutturaItem!.id; // Può essere null

        await _personaleController.reload();
        if (!mounted) return;
        setState(() => _isDirty = false);
        // Navigator.of(context).pop();
      }
    } catch (e, s) {
      print('_updateProfile Error: $e, Stack: $s');
      if (mounted && ScaffoldMessenger.maybeOf(context) != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore aggiornamento: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildRuoloEntryRow(RuoloEntryItem entry) {
    /* ... codice invariato ... */
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
    /* ... codice invariato ... */
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
    Widget photoDisplayWidget;
    const double avatarDisplaySize = 100.0;

    if (_isLoadingDisplayImageUrl) {
      /* ... codice invariato ... */
      photoDisplayWidget = SizedBox(
        width: avatarDisplaySize,
        height: avatarDisplaySize,
        child: Center(child: Tooltip(message: "Caricamento URL immagine...", child: CircularProgressIndicator(strokeWidth: 2))),
      );
    } else if (_displayImageFailedToLoad || _currentDisplayImageUrl == null || _currentDisplayImageUrl!.trim().isEmpty) {
      /* ... codice invariato ... */
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
      /* ... codice invariato ... */
      photoDisplayWidget = SizedBox(
        width: avatarDisplaySize,
        height: avatarDisplaySize,
        child: ClipOval(
          child: FittedBox(
            fit: BoxFit.contain,
            child: Image.network(
              _currentDisplayImageUrl!,
              key: ValueKey(_currentDisplayImageUrl!),
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
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && !_displayImageFailedToLoad) {
                    setState(() {
                      _displayImageFailedToLoad = true;
                    });
                  }
                });
                return Container(
                  width: avatarDisplaySize,
                  height: avatarDisplaySize,
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
                  // onChanged è gestito da _handleEnteChange
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

                // --- CAMPO STRUTTURA CON AUTOCOMPLETE ---
                Autocomplete<StrutturaItem>(
                  optionsBuilder: _fetchStruttureSuggestions,
                  displayStringForOption: (StrutturaItem option) => option.nome,
                  fieldViewBuilder: (BuildContext context, TextEditingController fieldTextEditingController, FocusNode fieldFocusNode, VoidCallback onFieldSubmitted) {
                    // Sincronizza il controller di Autocomplete con il nostro _strutturaInputController
                    // Questo è importante per il caricamento iniziale e se il nostro controller viene modificato programmaticamente
                    if (_strutturaInputController.text != fieldTextEditingController.text) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted && _strutturaInputController.text != fieldTextEditingController.text) {
                          fieldTextEditingController.text = _strutturaInputController.text;
                          // Muovi il cursore alla fine dopo aver impostato il testo programmaticamente
                          fieldTextEditingController.selection = TextSelection.fromPosition(TextPosition(offset: fieldTextEditingController.text.length));
                        }
                      });
                    }
                    return TextFormField(
                      controller: fieldTextEditingController,
                      focusNode: fieldFocusNode,
                      decoration: InputDecoration(
                        labelText: 'Struttura *',
                        hintText: _enteController.text.trim().isEmpty ? 'Seleziona prima un Ente' : 'Digita min. 3 caratteri...',
                        border: const OutlineInputBorder(),
                        suffixIcon: (_isLoadingStrutture)
                            ? const Padding(padding: EdgeInsets.all(8.0), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                            : (fieldTextEditingController.text.isNotEmpty && _selectedStrutturaItem == null
                                ? IconButton(
                                    tooltip: 'Cancella testo struttura',
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      fieldTextEditingController.clear(); // Cancella il testo nel campo di Autocomplete
                                      _strutturaInputController.clear(); // Sincronizza il nostro controller
                                      setState(() => _selectedStrutturaItem = null);
                                      _markDirty();
                                      // _formKey.currentState?.validate(); // Opzionale: rivalida subito
                                    })
                                : null),
                      ),
                      validator: (value) {
                        final String val = value?.trim() ?? '';
                        if (val.isEmpty) {
                          return 'La struttura è obbligatoria.';
                        }
                        // Se l'utente ha scritto qualcosa ma non ha selezionato un item dalla lista
                        if (_selectedStrutturaItem == null && val.isNotEmpty) {
                          return 'Seleziona una struttura valida dall\'elenco o cancella il testo.';
                        }
                        // Se l'item selezionato non corrisponde più al testo nel campo (es. utente ha modificato dopo selezione)
                        if (_selectedStrutturaItem != null && _selectedStrutturaItem!.nome.trim() != val) {
                          // Questo caso dovrebbe essere gestito da _handleStrutturaInputChange deselezionando _selectedStrutturaItem,
                          // quindi ricadrebbe nel caso precedente.
                          return 'Il testo non corrisponde alla struttura selezionata. Riscegli dall\'elenco.';
                        }
                        return null;
                      },
                      onChanged: (text) {
                        // Aggiorna il nostro _strutturaInputController per mantenere la sincronia.
                        // La logica di _markDirty e deselezione è in _handleStrutturaInputChange.
                        _strutturaInputController.text = text;
                      },
                    );
                  },
                  onSelected: (StrutturaItem selection) {
                    print('Struttura selezionata: ${selection.nome} (ID: ${selection.id})');
                    setState(() {
                      _selectedStrutturaItem = selection;
                      _strutturaInputController.text = selection.nome; // Sincronizza il nostro controller
                      _markDirty();
                    });
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      // Per evitare problemi di validazione durante build
                      _formKey.currentState?.validate();
                    });
                  },
                  optionsViewBuilder: (BuildContext context, AutocompleteOnSelected<StrutturaItem> onSelected, Iterable<StrutturaItem> options) {
                    return Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        elevation: 4.0,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxHeight: 250, maxWidth: MediaQuery.of(context).size.width - 40),
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                            itemCount: options.length,
                            itemBuilder: (BuildContext context, int index) {
                              final StrutturaItem option = options.elementAt(index);
                              return InkWell(
                                onTap: () => onSelected(option),
                                child: ListTile(
                                  title: Text(option.nome),
                                  subtitle: Text('Codice: ${option.id} (${option.universita})'),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 15),
                // --- FINE CAMPO STRUTTURA ---

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
                const SizedBox(height: 20), // Spazio extra in fondo per scrolling
              ],
            ),
          ),
        ),
        if (_isLoading && ModalRoute.of(context)?.isCurrent == true)
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
