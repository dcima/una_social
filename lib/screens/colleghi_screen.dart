// lib/screens/colleghi_screen.dart

// ignore_for_file: avoid_print

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

// --- MODELLI (INVARIATI) ---
enum RoleType { all, docente, tecnico }

class Collega {
  final String ente;
  final int id;
  final String nome;
  final String cognome;
  final String email;
  final List<String> ruoli;
  bool isSelected;

  Collega({
    required this.ente,
    required this.id,
    required this.nome,
    required this.cognome,
    required this.email,
    required this.ruoli,
    this.isSelected = false,
  });

  factory Collega.fromJson(Map<String, dynamic> json) {
    List<String> ruoliList = (json['ruoli'] as List? ?? []).map((item) => item.toString()).toList();
    return Collega(
      ente: json['ente'] as String,
      id: json['id'] as int,
      nome: json['nome'] as String? ?? '',
      cognome: json['cognome'] as String? ?? '',
      email: json['email_principale'] as String? ?? '',
      ruoli: ruoliList,
    );
  }
}

class Struttura {
  final String ente;
  final int id;
  final String nome;
  final String? indirizzo;

  Struttura({required this.ente, required this.id, required this.nome, this.indirizzo});

  factory Struttura.fromJson(Map<String, dynamic> json) {
    return Struttura(
      ente: json['ente'] as String,
      id: json['id'] as int,
      nome: json['nome'] as String? ?? 'Senza nome',
      indirizzo: json['indirizzo'] as String? ?? 'Nessun indirizzo',
    );
  }

  @override
  bool operator ==(Object other) => other is Struttura && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

// --- WIDGET ---
class ColleghiScreen extends StatefulWidget {
  const ColleghiScreen({super.key});

  @override
  State<ColleghiScreen> createState() => _ColleghiScreenState();
}

class _ColleghiScreenState extends State<ColleghiScreen> {
  final _supabase = Supabase.instance.client;

  List<Struttura> _strutture = [];
  Struttura? _strutturaSelezionata;
  List<Collega> _allColleaguesForStructure = [];
  List<Collega> _filteredColleghi = [];
  Future<void>? _dataLoadingFuture;
  int? _currentUserId;

  RoleType _selectedRoleType = RoleType.all;
  String? _selectedRole;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isFilterVisible = false;

  bool _selectAll = false;
  int _rowsPerPage = 10;
  int _sortColumnIndex = 1;
  bool _sortAscending = true;

  Future<void> _launchMaps(String? address) async {
    if (address == null || address.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Indirizzo non disponibile')));
      return;
    }
    final Uri googleMapsUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}');
    if (await canLaunchUrl(googleMapsUrl)) {
      await launchUrl(googleMapsUrl);
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Impossibile aprire Google Maps')));
    }
  }

  @override
  void initState() {
    super.initState();
    print('ColleghiScreen: Inizio initState');
    _dataLoadingFuture = _initializeData();
    _searchController.addListener(() {
      if (_searchController.text != _searchQuery) {
        setState(() {
          _searchQuery = _searchController.text;
          _applyFilters();
        });
      }
    });
    print('ColleghiScreen: Fine initState');
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    print('ColleghiScreen: Inizio _initializeData');
    try {
      final user = _supabase.auth.currentUser;
      if (user == null || user.email == null) throw 'Utente o email non trovati.';

      final stopwatchPersonale = Stopwatch()..start();
      final personaleUtenteCorrente = await _supabase.from('personale').select('id, ente, struttura').eq('email_principale', user.email!).single();
      stopwatchPersonale.stop();
      print('ColleghiScreen: Caricamento personale utente: ${stopwatchPersonale.elapsedMilliseconds} ms');

      _currentUserId = personaleUtenteCorrente['id'] as int;
      final userEnte = personaleUtenteCorrente['ente'] as String;
      final userStrutturaId = personaleUtenteCorrente['struttura'] as int;

      final stopwatchStrutture = Stopwatch()..start();
      final struttureData = await _supabase.from('strutture').select('ente, id, nome, indirizzo').eq('ente', userEnte).order('nome', ascending: true);
      stopwatchStrutture.stop();
      print('ColleghiScreen: Caricamento strutture: ${stopwatchStrutture.elapsedMilliseconds} ms. Numero strutture: ${struttureData.length}');

      _strutture = struttureData.map((json) => Struttura.fromJson(json)).toList();

      if (_strutture.isNotEmpty) {
        _strutturaSelezionata = _strutture.firstWhere((s) => s.id == userStrutturaId, orElse: () => _strutture.first);
        await _fetchColleagues(_strutturaSelezionata!);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore durante l\'inizializzazione: $e')),
        );
      }
      rethrow;
    } finally {
      print('ColleghiScreen: Fine _initializeData');
    }
  }

  Future<void> _fetchColleagues(Struttura struttura) async {
    print('ColleghiScreen: Inizio _fetchColleagues per ${struttura.nome}');
    try {
      final stopwatchColleagues = Stopwatch()..start();
      final response = await _supabase.rpc('get_colleagues_by_struttura', params: {'p_ente': struttura.ente, 'p_struttura_id': struttura.id});
      stopwatchColleagues.stop();
      print('ColleghiScreen: Caricamento colleghi per struttura: ${stopwatchColleagues.elapsedMilliseconds} ms. Numero colleghi: ${(response as List).length}');

      _allColleaguesForStructure = response.map((json) => Collega.fromJson(json)).toList();
      if (mounted) setState(() => _resetFiltersAndApply());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore nel caricamento dei colleghi: $e')),
        );
      }
    } finally {
      print('ColleghiScreen: Fine _fetchColleagues');
    }
  }

  void _resetFiltersAndApply() {
    _selectedRoleType = RoleType.all;
    _selectedRole = null;
    _searchController.clear();
    _applyFilters();
  }

  bool _isTecnico(Collega c) => c.ruoli.any((r) => r.toLowerCase().startsWith('area'));
  bool _isDocente(Collega c) => c.ruoli.isNotEmpty && !_isTecnico(c);

  void _applyFilters() {
    print('ColleghiScreen: Applicazione filtri...');
    setState(() {
      List<Collega> tempFilteredList = List.from(_allColleaguesForStructure);
      if (_selectedRoleType == RoleType.docente) tempFilteredList.retainWhere(_isDocente);
      if (_selectedRoleType == RoleType.tecnico) tempFilteredList.retainWhere(_isTecnico);
      if (_selectedRole != null) tempFilteredList.retainWhere((c) => c.ruoli.contains(_selectedRole!));

      if (_searchQuery.isNotEmpty) {
        tempFilteredList.retainWhere((collega) {
          final query = _searchQuery.toLowerCase();
          final nomeCompleto = '${collega.nome} ${collega.cognome}'.toLowerCase();
          final email = collega.email.toLowerCase();
          return nomeCompleto.contains(query) || email.contains(query);
        });
      }

      _filteredColleghi = tempFilteredList;
      _sortFilteredList();
      _selectAll = false;
    });
    print('ColleghiScreen: Filtri applicati. Colleghi filtrati: ${_filteredColleghi.length}');
  }

  List<String> get _dropdownRoles {
    Iterable<Collega> sourceList;
    if (_selectedRoleType == RoleType.docente) {
      sourceList = _allColleaguesForStructure.where(_isDocente);
    } else if (_selectedRoleType == RoleType.tecnico) {
      sourceList = _allColleaguesForStructure.where(_isTecnico);
    } else {
      sourceList = _allColleaguesForStructure;
    }
    final rolesToShow = sourceList.expand((c) => c.ruoli).toSet();
    final sortedRoles = rolesToShow.toList()..sort();
    return ['Tutti', ...sortedRoles];
  }

  void _sortFilteredList() {
    _filteredColleghi.sort((a, b) {
      int result;
      switch (_sortColumnIndex) {
        case 1: // Cognome
          result = a.cognome.compareTo(b.cognome);
          break;
        case 2: // Nome
          result = a.nome.compareTo(b.nome);
          break;
        default:
          result = a.cognome.compareTo(b.cognome);
      }
      return _sortAscending ? result : -result;
    });
  }

  void _onSort(int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
      _sortFilteredList();
    });
  }

  @override
  Widget build(BuildContext context) {
    print('ColleghiScreen: build');

    return FutureBuilder(
      future: _dataLoadingFuture,
      builder: (context, snapshot) {
        print('ColleghiScreen: Build avviato. ConnectionState: ${snapshot.connectionState}');

        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Text('Errore critico nel caricamento dati: ${snapshot.error}'));
        print('ColleghiScreen: Dati caricati, costruzione MainContent.');
        return _buildMainContent();
      },
    );
  }

  Widget _buildMainContent() {
    return Column(
      children: [
        _buildCustomSearchableDropdown<Struttura>(
          label: 'Struttura di Appartenenza',
          selectedValue: _strutturaSelezionata,
          displayValue: (struttura) => '${struttura.nome} - ${struttura.indirizzo ?? 'N/D'}',
          allItems: _strutture,
          initialSearchQuery: _searchQuery,
          onItemSelected: (newValue) {
            if (newValue != null && newValue != _strutturaSelezionata) {
              setState(() => _strutturaSelezionata = newValue);
              _fetchColleagues(newValue);
            }
          },
        ),
        _buildCustomSearchableDropdown<String>(
          label: 'Ruolo',
          selectedValue: _selectedRole ?? 'Tutti',
          displayValue: (role) => role,
          allItems: _dropdownRoles,
          initialSearchQuery: '',
          onItemSelected: (newValue) {
            setState(() {
              _selectedRole = (newValue == 'Tutti') ? null : newValue;
              _applyFilters();
            });
          },
        ),
        Expanded(
          child: SingleChildScrollView(
            child: PaginatedDataTable(
              header: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Elenco Colleghi'),
                      IconButton(
                        icon: Icon(_isFilterVisible ? Icons.filter_list_off : Icons.filter_list),
                        tooltip: 'Filtra elenco',
                        onPressed: () {
                          setState(() {
                            _isFilterVisible = !_isFilterVisible;
                            if (!_isFilterVisible) _searchController.clear();
                          });
                        },
                      ),
                    ],
                  ),
                  if (_isFilterVisible)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Cerca per nome, cognome o email...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 20),
                                  onPressed: () => _searchController.clear(),
                                )
                              : null,
                        ),
                      ),
                    ),
                ],
              ),
              rowsPerPage: _rowsPerPage,
              onRowsPerPageChanged: (value) => setState(() => _rowsPerPage = value ?? 10),
              sortColumnIndex: _sortColumnIndex,
              sortAscending: _sortAscending,
              columns: [
                DataColumn(
                  label: Checkbox(
                    value: _selectAll,
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() {
                        _selectAll = v;
                        for (var c in _filteredColleghi) {
                          if (c.id != _currentUserId) c.isSelected = _selectAll;
                        }
                      });
                    },
                  ),
                ),
                DataColumn(label: const Text('Cognome'), onSort: _onSort),
                DataColumn(label: const Text('Nome'), onSort: _onSort),
                DataColumn(label: const Text('Email')),
              ],
              source: _ColleghiDataSource(
                colleghi: _filteredColleghi,
                currentUserId: _currentUserId,
                onSelect: (c) => setState(() => c.isSelected = !c.isSelected),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCustomSearchableDropdown<T>({
    required String label,
    required T? selectedValue,
    required String Function(T) displayValue,
    required List<T> allItems,
    required ValueChanged<T?> onItemSelected,
    String initialSearchQuery = '',
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: GestureDetector(
        onTap: () async {
          print('ColleghiScreen: Tap su dropdown "$label". Apertura _SearchDialog.');
          final stopwatchDialog = Stopwatch()..start();
          final result = await showDialog<T>(
            context: context,
            builder: (context) => _SearchDialog<T>(
              label: label,
              allItems: allItems,
              selectedValue: selectedValue,
              initialSearchQuery: initialSearchQuery,
              itemBuilder: (item, isSelected, key) {
                if (item is Struttura) {
                  return Card(
                    key: key,
                    color: isSelected ? Theme.of(context).primaryColorLight.withAlpha(128) : null,
                    child: ListTile(
                      title: Text(item.nome, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(item.indirizzo ?? 'N/D'),
                      trailing: IconButton(
                        icon: Icon(Icons.location_on_outlined, color: Colors.blue.shade700),
                        onPressed: () => _launchMaps(item.indirizzo),
                      ),
                      onTap: () => Navigator.of(context).pop(item),
                    ),
                  );
                }
                return ListTile(
                  key: key,
                  title: Text(displayValue(item)),
                  tileColor: isSelected ? Theme.of(context).primaryColorLight.withAlpha(128) : null,
                  onTap: () => Navigator.of(context).pop(item),
                );
              },
              filterFn: (item, query) {
                if (item is Struttura) {
                  return '${item.nome} ${item.indirizzo ?? ''}'.toLowerCase().contains(query);
                }
                return displayValue(item).toLowerCase().contains(query);
              },
            ),
          );
          stopwatchDialog.stop();
          print('ColleghiScreen: _SearchDialog per "$label" chiuso. Tempo totale apertura/interazione: ${stopwatchDialog.elapsedMilliseconds} ms');

          if (result != null) {
            onItemSelected(result);
          }
        },
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            suffixIcon: const Icon(Icons.arrow_drop_down),
          ),
          child: Text(
            selectedValue != null ? displayValue(selectedValue) : 'Seleziona...',
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }
}

// --- WIDGET DIALOGO PERSONALIZZATO (MODIFICATO) ---
class _SearchDialog<T> extends StatefulWidget {
  final String label;
  final List<T> allItems;
  final T? selectedValue;
  final String initialSearchQuery;
  final Widget Function(T item, bool isSelected, Key? key) itemBuilder;
  final bool Function(T item, String query) filterFn;

  const _SearchDialog({
    super.key,
    required this.label,
    required this.allItems,
    required this.selectedValue,
    this.initialSearchQuery = '',
    required this.itemBuilder,
    required this.filterFn,
  });

  @override
  State<_SearchDialog<T>> createState() => _SearchDialogState<T>();
}

class _SearchDialogState<T> extends State<_SearchDialog<T>> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<T> _filteredItems = [];
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    print('_SearchDialog: Inizio initState per "${widget.label}"');
    final stopwatchInit = Stopwatch()..start();

    _searchController.text = widget.initialSearchQuery;
    _searchController.addListener(_onSearchChanged);

    // Applica subito il filtro iniziale
    final stopwatchFilter = Stopwatch()..start();
    _filterItems();
    stopwatchFilter.stop();
    print('_SearchDialog: Tempo filtro iniziale: ${stopwatchFilter.elapsedMilliseconds} ms. Elementi filtrati: ${_filteredItems.length}');

    // Scorrimento iniziale dopo che il layout è stabile
    WidgetsBinding.instance.addPostFrameCallback((_) {
      print('_SearchDialog: addPostFrameCallback eseguito. Scheduling scroll.');
      // Aggiungo un piccolo ritardo per permettere al ListView di stabilizzarsi
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollToSelectedItem();
      });
    });

    stopwatchInit.stop();
    print('_SearchDialog: Fine initState per "${widget.label}". Tempo totale initState: ${stopwatchInit.elapsedMilliseconds} ms');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      print('_SearchDialog: Ricerca cambiata: "${_searchController.text}"');
      final stopwatchFilter = Stopwatch()..start();
      _filterItems();
      stopwatchFilter.stop();
      print('_SearchDialog: Tempo filtro onSearchChanged: ${stopwatchFilter.elapsedMilliseconds} ms. Elementi filtrati: ${_filteredItems.length}');

      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Aggiungo un piccolo ritardo anche qui per la stabilità dopo il filtro
        Future.delayed(const Duration(milliseconds: 100), () {
          _scrollToSelectedItem();
        });
      });
    });
  }

  void _filterItems() {
    final query = _searchController.text.toLowerCase();
    if (mounted) {
      setState(() {
        _filteredItems = widget.allItems.where((item) => widget.filterFn(item, query)).toList();
      });
    }
  }

  void _scrollToSelectedItem() {
    if (widget.selectedValue == null || !_scrollController.hasClients) return;

    final int selectedIndex = widget.selectedValue != null ? _filteredItems.indexOf(widget.selectedValue as T) : -1;
    if (selectedIndex != -1) {
      const double avgItemHeight = 72.0;

      final double viewportHeight = _scrollController.position.viewportDimension;
      final double maxScrollExtent = _scrollController.position.maxScrollExtent;

      double targetOffset = (selectedIndex * avgItemHeight) - (viewportHeight / 2) + (avgItemHeight / 2);

      targetOffset = targetOffset.clamp(0.0, maxScrollExtent);

      final stopwatchScroll = Stopwatch()..start();
      _scrollController.jumpTo(targetOffset);
      stopwatchScroll.stop();
      print('_SearchDialog: Scorrimento a indice $selectedIndex. Tempo jumpTo: ${stopwatchScroll.elapsedMilliseconds} ms');
    } else {
      print('_SearchDialog: Elemento selezionato non trovato nella lista filtrata per scorrimento.');
    }
  }

  @override
  Widget build(BuildContext context) {
    print('_SearchDialog: Build avviato per "${widget.label}"');
    return AlertDialog(
      title: Text('Seleziona ${widget.label}'),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Cerca...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => _searchController.clear(),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _filteredItems.isEmpty
                  ? const Center(child: Text('Nessun risultato'))
                  : ListView.builder(
                      controller: _scrollController,
                      itemCount: _filteredItems.length,
                      itemBuilder: (context, index) {
                        final item = _filteredItems[index];
                        final isSelected = (item == widget.selectedValue);

                        Key? itemKey;
                        if (item is Struttura) {
                          itemKey = ValueKey(item.id);
                        } else {
                          itemKey = ValueKey(item);
                        }
                        return widget.itemBuilder(item, isSelected, itemKey);
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annulla'),
        ),
      ],
    );
  }
}

// --- DATASOURCE (INVARIATO) ---
class _ColleghiDataSource extends DataTableSource {
  final List<Collega> colleghi;
  final int? currentUserId;
  final Function(Collega) onSelect;

  _ColleghiDataSource({required this.colleghi, required this.currentUserId, required this.onSelect});

  @override
  DataRow getRow(int index) {
    final collega = colleghi[index];
    final isCurrentUser = collega.id == currentUserId;
    return DataRow.byIndex(
      index: index,
      selected: collega.isSelected,
      onSelectChanged: isCurrentUser ? null : (isSelected) => onSelect(collega),
      cells: [
        DataCell(Checkbox(value: collega.isSelected, onChanged: isCurrentUser ? null : (v) => onSelect(collega))),
        DataCell(Text(collega.cognome)),
        DataCell(Text(collega.nome)),
        DataCell(Text(collega.email)),
      ],
    );
  }

  @override
  bool get isRowCountApproximate => false;
  @override
  int get rowCount => colleghi.length;
  @override
  int get selectedRowCount => colleghi.where((c) => c.isSelected).length;
}
