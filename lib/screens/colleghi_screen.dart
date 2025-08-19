// lib/screens/colleghi_screen.dart

// ignore_for_file: avoid_print, null_check_on_nullable_type_parameter

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart'; // Aggiunto import per SfDataGrid
import 'package:collection/collection.dart'; // Per firstWhereOrNull

// --- MODELLI ---
enum RoleType { all, docente, tecnico }

class Collega {
  final String ente;
  final String id;
  final String nome;
  final String cognome;
  final String email;
  final List<String> ruoli;
  final String? photoUrl;
  final List<String> telefoni; // Aggiunto campo telefoni
  bool isSelected;

  Collega({
    required this.ente,
    required this.id,
    required this.nome,
    required this.cognome,
    required this.email,
    required this.ruoli,
    this.photoUrl,
    this.telefoni = const [], // Inizializza con lista vuota di default
    this.isSelected = false,
  });

  factory Collega.fromJson(Map<String, dynamic> json) {
    List<String> ruoliList = (json['ruoli'] as List? ?? []).map((item) => item.toString()).toList();
    // Gestione del campo telefoni, che può essere un array JSON o null
    List<String> telefoniList = (json['telefoni'] as List? ?? []).map((item) => item.toString()).toList();

    return Collega(
      ente: json['ente'] as String,
      id: json['id'].toString(), // Ensure id is always String
      nome: json['nome'] as String? ?? '',
      cognome: json['cognome'] as String? ?? '',
      email: json['email_principale'] as String? ?? '',
      ruoli: ruoliList,
      photoUrl: json['photo_url'] as String?,
      telefoni: telefoniList, // Assegna i telefoni parsati
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
  List<Collega> _allColleaguesForStructure = []; // Colleagues for the currently selected structure
  List<Collega> _filteredColleghi = []; // Colleagues filtered by local search/role/etc. or global search results
  Future<void>? _dataLoadingFuture;
  String? _currentUserId;

  RoleType _selectedRoleType = RoleType.all;
  String? _selectedRole;

  final TextEditingController _searchController = TextEditingController(); // For local filter within structure
  String _searchQuery = ''; // For local filter
  bool _isFilterVisible = false; // Controls visibility of local filter

  final TextEditingController _globalSearchController = TextEditingController(); // For global search across personnel and externals
  String _globalSearchQuery = ''; // For global search
  List<Collega> _globalSearchResults = []; // Results from global search RPC
  bool _isGlobalSearchActive = false; // True if global search query is not empty and >= 3 chars
  Timer? _globalSearchDebounce; // Debounce timer for global search

  bool _selectAll = false;
  int _rowsPerPage = 100;
  // Adjusted for new columns: Checkbox(0), Foto(1), Ente(2), ID(3), Cognome(4), Nome(5), Email(6), Telefoni(7)
  int _sortColumnIndex = 4; // Default sort by Cognome
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

    _globalSearchController.addListener(_onGlobalSearchChanged);

    print('ColleghiScreen: Fine initState');
  }

  @override
  void dispose() {
    _searchController.dispose();
    _globalSearchController.dispose();
    _globalSearchDebounce?.cancel();
    super.dispose();
  }

  void _onGlobalSearchChanged() {
    if (_globalSearchDebounce?.isActive ?? false) _globalSearchDebounce!.cancel();
    _globalSearchDebounce = Timer(const Duration(milliseconds: 500), () async {
      final query = _globalSearchController.text.trim();
      setState(() {
        _globalSearchQuery = query;
        // _isGlobalSearchActive becomes true only if query is not empty and >= 3 chars
        _isGlobalSearchActive = query.isNotEmpty && query.length >= 3;
        // When global search is active or cleared, hide local filter and clear its text
        if (_isGlobalSearchActive || query.isEmpty) {
          _isFilterVisible = false;
          _searchController.clear();
        }
      });

      if (_isGlobalSearchActive) {
        await _performGlobalSearch(query);
      } else {
        // If global search is cleared or not active (e.g., < 3 chars), revert to structure/local filters
        _applyFilters();
      }
    });
  }

  Future<void> _performGlobalSearch(String query) async {
    print('ColleghiScreen: Performing global search for: "$query"');
    try {
      final stopwatchGlobalSearch = Stopwatch()..start();
      final response = await _supabase.rpc('search_personnel_and_externals', params: {'p_query': query});
      stopwatchGlobalSearch.stop();
      print('ColleghiScreen: Global search completed in ${stopwatchGlobalSearch.elapsedMilliseconds} ms. Results: ${(response as List).length}');

      setState(() {
        _globalSearchResults = response.map((json) => Collega.fromJson(json)).toList();
        _applyFilters(); // Apply sort/pagination on global results
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore durante la ricerca globale: $e')),
        );
      }
      setState(() {
        _globalSearchResults = []; // Clear results on error
        _applyFilters();
      });
    }
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

      _currentUserId = (personaleUtenteCorrente['id'] as int).toString();
      final userEnte = personaleUtenteCorrente['ente'] as String;
      final userStrutturaId = personaleUtenteCorrente['struttura'] as int;

      final stopwatchStrutture = Stopwatch()..start();
      final struttureData = await _supabase.from('strutture').select('ente, id, nome, indirizzo').eq('ente', userEnte).order('id', ascending: true).limit(2000);
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
      // Assumiamo che 'get_colleagues_by_struttura' recuperi tutti i campi necessari per Collega
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
    _searchController.clear(); // Clear local search input
    _globalSearchController.clear(); // Clear global search input, which will trigger _onGlobalSearchChanged and reset _isGlobalSearchActive
    // _isGlobalSearchActive will be set to false by _onGlobalSearchChanged when _globalSearchController is cleared.
    _applyFilters(); // Reapply filters based on the reset state
  }

  bool _isTecnico(Collega c) => c.ruoli.any((r) => r.toLowerCase().startsWith('area'));
  bool _isDocente(Collega c) => c.ruoli.isNotEmpty && !_isTecnico(c);

  void _applyFilters() {
    print('ColleghiScreen: Applicazione filtri...');
    print('ColleghiScreen: _isGlobalSearchActive: $_isGlobalSearchActive'); // Debugging print
    setState(() {
      List<Collega> tempFilteredList;

      if (_isGlobalSearchActive) {
        tempFilteredList = List.from(_globalSearchResults);
      } else {
        tempFilteredList = List.from(_allColleaguesForStructure);
        if (_selectedRoleType == RoleType.docente) tempFilteredList.retainWhere(_isDocente);
        if (_selectedRoleType == RoleType.tecnico) tempFilteredList.retainWhere(_isTecnico);
        if (_selectedRole != null) tempFilteredList.retainWhere((c) => c.ruoli.contains(_selectedRole!));

        if (_searchQuery.isNotEmpty) {
          tempFilteredList.retainWhere((collega) {
            final query = _searchQuery.toLowerCase();
            final nomeCompleto = '${collega.nome} ${collega.cognome}'.toLowerCase();
            final email = collega.email.toLowerCase();
            final telefoniConcatenated = collega.telefoni.join(' ').toLowerCase();
            return nomeCompleto.contains(query) || email.contains(query) || telefoniConcatenated.contains(query);
          });
        }
      }

      _filteredColleghi = tempFilteredList;
      _sortFilteredList();
      _selectAll = false;
    });
    print('ColleghiScreen: Filtri applicati. Colleghi filtrati: ${_filteredColleghi.length}');
  }

  List<String> get _dropdownRoles {
    if (_isGlobalSearchActive) {
      return ['Tutti']; // Roles not applicable when global search is active
    }
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
      // Column indices (0-based for DataColumn):
      // Checkbox (0, not sortable)
      // Foto (1, not sortable)
      // Ente (2)
      // ID (3)
      // Cognome (4)
      // Nome (5)
      // Email (6)
      // Telefoni (7)
      switch (_sortColumnIndex) {
        case 2: // Ente
          result = a.ente.compareTo(b.ente);
          break;
        case 3: // ID
          result = a.id.compareTo(b.id);
          break;
        case 4: // Cognome
          result = a.cognome.compareTo(b.cognome);
          break;
        case 5: // Nome
          result = a.nome.compareTo(b.nome);
          break;
        case 6: // Email
          result = a.email.compareTo(b.email);
          break;
        case 7: // Telefoni
          result = a.telefoni.join(', ').compareTo(b.telefoni.join(', '));
          break;
        default:
          result = a.cognome.compareTo(b.cognome); // Default to cognome if index is out of bounds
      }
      return _sortAscending ? result : -result;
    });
  }

  void _onSort(int columnIndex, bool ascending) {
    setState(() {
      // Adjust column index for non-sortable leading columns (Checkbox, Foto)
      // If checkbox is 0, Foto is 1, then Ente (visual 2) is sortable index 2.
      // So, visual index directly maps to _sortColumnIndex if columns are contiguous.
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
    print('ColleghiScreen: build main content');

    // Determine if the structure/role/local search filters should be enabled
    final bool enableDropdownsAndLocalFilter = !_isGlobalSearchActive;

    return Column(
      children: [
        // Global Search Field (new)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: _globalSearchController,
            decoration: InputDecoration(
              hintText: 'Es. Mario Rossi / bianc / mario.rossi@gmail.com / carlo.bianchi@unibo.it / @unibo / @gmail',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              suffixIcon: _globalSearchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _globalSearchController.clear();
                      },
                    )
                  : null,
            ),
          ),
        ),
        // Existing Structure and Role dropdowns, conditionally rendered
        if (enableDropdownsAndLocalFilter)
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
        if (enableDropdownsAndLocalFilter)
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
        // Local Filter Section (title, filter icon, local search bar), conditionally rendered
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Elenco Colleghi', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  if (enableDropdownsAndLocalFilter) // Local filter icon only if global search is off
                    IconButton(
                      icon: Icon(_isFilterVisible ? Icons.filter_list_off : Icons.filter_list),
                      tooltip: 'Filtra elenco',
                      onPressed: () {
                        setState(() {
                          _isFilterVisible = !_isFilterVisible;
                          if (!_isFilterVisible) _searchController.clear(); // Clear local search if hiding
                        });
                      },
                    ),
                ],
              ),
              if (_isFilterVisible && enableDropdownsAndLocalFilter) // Local filter text field only if visible AND global search is off
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Cerca per nome, cognome o email...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () => _searchController.clear(),
                            )
                          : null,
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal, // Enable horizontal scrolling for many columns
            child: PaginatedDataTable(
              availableRowsPerPage: [10, 20, 50, 100, 500, 1000, 2000],
              headingRowHeight: 64,
              onRowsPerPageChanged: (value) => setState(() => _rowsPerPage = value ?? 10),
              rowsPerPage: _rowsPerPage,
              sortAscending: _sortAscending,
              sortColumnIndex: _sortColumnIndex,
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
                const DataColumn(label: Text('Foto')),
                DataColumn(label: const Text('Ente'), onSort: _onSort),
                DataColumn(label: const Text('ID'), onSort: _onSort),
                DataColumn(label: const Text('Cognome'), onSort: _onSort),
                DataColumn(label: const Text('Nome'), onSort: _onSort),
                DataColumn(label: const Text('Email'), onSort: _onSort),
                DataColumn(label: const Text('Telefoni'), onSort: _onSort),
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
    String initialSearchQuery = '',
    required ValueChanged<T?> onItemSelected,
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
              onLaunchMaps: _launchMaps, // Passa la funzione _launchMaps
              itemBuilder: (item, isSelected, key) {
                // Questo itemBuilder è ora usato solo per i ruoli (String),
                // la logica per Struttura è gestita internamente da _SearchDialog con SfDataGrid.
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

// --- WIDGET DIALOGO PERSONALIZZATO (MODIFICATO PER USARE SfDataGrid) ---
class _SearchDialog<T> extends StatefulWidget {
  final String label;
  final List<T> allItems;
  final T? selectedValue;
  final String initialSearchQuery;
  final Widget Function(T item, bool isSelected, Key? key) itemBuilder; // Usato solo se T non è Struttura
  final bool Function(T item, String query) filterFn;
  final Function(String?) onLaunchMaps; // Nuova callback per Google Maps

  const _SearchDialog({
    super.key,
    required this.label,
    required this.allItems,
    required this.selectedValue,
    this.initialSearchQuery = '',
    required this.itemBuilder,
    required this.filterFn,
    required this.onLaunchMaps, // Richiesto
  });

  @override
  State<_SearchDialog<T>> createState() => _SearchDialogState<T>();
}

class _SearchDialogState<T> extends State<_SearchDialog<T>> {
  final TextEditingController _searchController = TextEditingController();
  final DataGridController _dataGridController = DataGridController(); // Controller per SfDataGrid
  late DataGridSource _dataSource; // Data source generico
  List<T> _filteredItems = [];
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    print('_SearchDialog: Inizio initState per "${widget.label}"');
    final stopwatchInit = Stopwatch()..start();

    _searchController.text = widget.initialSearchQuery;
    _searchController.addListener(_onSearchChanged);

    _filterItems(); // Popola _filteredItems

    // Inizializza il dataSource in base al tipo T
    if (T == Struttura) {
      _dataSource = _StrutturaSearchDataSource(
        _filteredItems.cast<Struttura>(),
        widget.selectedValue as Struttura?,
        (s1, s2) => s1.id == s2.id, // Usa l'uguaglianza di Struttura
        widget.onLaunchMaps, // Passa la callback
      );
    } else {
      // Fallback per altri tipi (es. String per i ruoli)
      _dataSource = _GenericSearchDataSource(
        _filteredItems,
        widget.selectedValue,
        widget.itemBuilder,
      );
    }

    // Scorrimento iniziale dopo che il layout è stabile
    WidgetsBinding.instance.addPostFrameCallback((_) {
      print('_SearchDialog: addPostFrameCallback eseguito. Scheduling scroll.');
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
    _dataGridController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      print('_SearchDialog: Ricerca cambiata: "${_searchController.text}"');
      final stopwatchFilter = Stopwatch()..start();
      _filterItems(); // Aggiorna _filteredItems

      if (T == Struttura) {
        (_dataSource as _StrutturaSearchDataSource).updateData(_filteredItems.cast<Struttura>());
      } else {
        (_dataSource as _GenericSearchDataSource).updateData(_filteredItems);
      }

      stopwatchFilter.stop();
      print('_SearchDialog: Tempo filtro onSearchChanged: ${stopwatchFilter.elapsedMilliseconds} ms. Elementi filtrati: ${_filteredItems.length}');

      WidgetsBinding.instance.addPostFrameCallback((_) {
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
    if (widget.selectedValue == null || !_filteredItems.contains(widget.selectedValue)) return;

    final int selectedIndex = _filteredItems.indexOf(widget.selectedValue!);
    if (selectedIndex != -1) {
      _dataGridController.scrollToRow(selectedIndex.toDouble());
      print('_SearchDialog: Scorrimento a indice $selectedIndex.');
    } else {
      print('_SearchDialog: Elemento selezionato non trovato nella lista filtrata per scorrimento.');
    }
  }

  List<GridColumn> _buildGridColumnsForStruttura() {
    return [
      GridColumn(
        columnName: 'id',
        width: 60, // Larghezza fissa per l'ID
        label: Container(
          padding: const EdgeInsets.all(8.0),
          alignment: Alignment.centerLeft,
          child: const Text('ID', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ),
      GridColumn(
        columnName: 'ente',
        width: 100, // Larghezza fissa per l'ente
        label: Container(
          padding: const EdgeInsets.all(8.0),
          alignment: Alignment.centerLeft,
          child: const Text('Ente', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ),
      GridColumn(
        columnName: 'nome',
        label: Container(
          padding: const EdgeInsets.all(8.0),
          alignment: Alignment.centerLeft,
          child: const Text('Nome', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ),
      GridColumn(
        columnName: 'indirizzo',
        label: Container(
          padding: const EdgeInsets.all(8.0),
          alignment: Alignment.centerLeft,
          child: const Text('Indirizzo', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ),
      GridColumn(
        columnName: 'mappa',
        width: 60, // Larghezza fissa per il pulsante
        label: Container(
          padding: const EdgeInsets.all(8.0),
          alignment: Alignment.center,
          child: const Text('Mappa', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ),
    ];
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
                  : (T == Struttura
                      ? SfDataGrid(
                          controller: _dataGridController,
                          source: _dataSource,
                          columns: _buildGridColumnsForStruttura(),
                          selectionMode: SelectionMode.single, // Solo selezione singola per un dropdown
                          headerGridLinesVisibility: GridLinesVisibility.both,
                          gridLinesVisibility: GridLinesVisibility.both,
                          columnWidthMode: ColumnWidthMode.fill,
                          frozenColumnsCount: 1, // La prima colonna (ID) è fissa
                          navigationMode: GridNavigationMode.cell, // Abilita la navigazione cella per cella con tastiera
                          onCellTap: (DataGridCellTapDetails details) {
                            if (details.rowColumnIndex.rowIndex > 0) {
                              // Exclude header row
                              final int dataRowIndex = details.rowColumnIndex.rowIndex - 1;
                              if (dataRowIndex >= 0 && dataRowIndex < _filteredItems.length) {
                                final Struttura selectedStruttura = _filteredItems[dataRowIndex] as Struttura;
                                // If the tapped cell is the map icon, launch map, otherwise pop with selection
                                if (details.column.columnName == 'mappa') {
                                  widget.onLaunchMaps(selectedStruttura.indirizzo);
                                } else {
                                  Navigator.of(context).pop(selectedStruttura);
                                }
                              }
                            }
                          },
                        )
                      : ListView.builder(
                          // Fallback for other types (e.g. String for roles)
                          itemCount: _filteredItems.length,
                          itemBuilder: (context, index) {
                            final item = _filteredItems[index];
                            final isSelected = (item == widget.selectedValue);
                            return widget.itemBuilder(item, isSelected, ValueKey(item.hashCode));
                          },
                        )),
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

// --- Custom DataGridSource per oggetti Struttura in _SearchDialog ---
class _StrutturaSearchDataSource extends DataGridSource {
  List<Struttura> _structures;
  final Struttura? _selectedValue;
  final bool Function(Struttura s1, Struttura s2) _areStructuresEqualCallback;
  final Function(String?) _onLaunchMaps;
  List<DataGridRow> _dataGridRows = [];

  _StrutturaSearchDataSource(
    this._structures,
    this._selectedValue,
    this._areStructuresEqualCallback,
    this._onLaunchMaps,
  ) {
    _buildDataGridRows();
  }

  void _buildDataGridRows() {
    _dataGridRows = _structures.map<DataGridRow>((s) {
      return DataGridRow(cells: [
        DataGridCell<int>(columnName: 'id', value: s.id), // Aggiunto ID
        DataGridCell<String>(columnName: 'ente', value: s.ente), // Aggiunto Ente
        DataGridCell<String>(columnName: 'nome', value: s.nome),
        DataGridCell<String>(columnName: 'indirizzo', value: s.indirizzo),
        DataGridCell<Struttura>(columnName: 'mappa', value: s), // Passa l'oggetto completo per il pulsante
      ]);
    }).toList();
  }

  @override
  List<DataGridRow> get rows => _dataGridRows;

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    final Struttura? originalStruttura = row.getCells().firstWhereOrNull((cell) => cell.columnName == 'mappa')?.value as Struttura?;

    final bool isSelected = originalStruttura != null && _selectedValue != null && _areStructuresEqualCallback(originalStruttura, _selectedValue);

    print('Struttura ID: ${originalStruttura?.id}, Nome: ${originalStruttura?.nome}, isSelected: $isSelected'); // Debugging

    Color? rowColor;
    if (isSelected) {
      final BuildContext? currentContext = NavigationService.navigatorKey.currentContext;
      if (currentContext != null) {
        rowColor = Colors.amber[300];
      } else {
        print("Warning: NavigationService.navigatorKey.currentContext is null in _StrutturaSearchDataSource.buildRow. Cannot apply theme highlight.");
        rowColor = Colors.amber[300];
      }
    }

    return DataGridRowAdapter(
      color: rowColor,
      cells: row.getCells().map<Widget>((dataGridCell) {
        if (dataGridCell.columnName == 'mappa') {
          final Struttura s = dataGridCell.value as Struttura;
          return IconButton(
            icon: Icon(Icons.location_on_outlined, color: Colors.blue.shade700),
            onPressed: () => _onLaunchMaps(s.indirizzo),
          );
        }
        return Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.all(8.0),
          child: Text(dataGridCell.value?.toString() ?? '', overflow: TextOverflow.ellipsis),
        );
      }).toList(),
    );
  }

  void updateData(List<Struttura> newStructures) {
    _structures = newStructures;
    _buildDataGridRows();
    notifyListeners();
  }
}

// --- Custom DataGridSource per tipi generici (fallback per ruoli) ---
class _GenericSearchDataSource<T> extends DataGridSource {
  List<T> _items;
  final T? _selectedValue;
  final Widget Function(T item, bool isSelected, Key? key) _itemBuilder;
  List<DataGridRow> _dataGridRows = [];

  _GenericSearchDataSource(
    this._items,
    this._selectedValue,
    this._itemBuilder,
  ) {
    _buildDataGridRows();
  }

  void _buildDataGridRows() {
    _dataGridRows = _items.map<DataGridRow>((item) {
      return DataGridRow(cells: [
        DataGridCell<T>(columnName: 'item', value: item), // Contiene l'intero oggetto
      ]);
    }).toList();
  }

  @override
  List<DataGridRow> get rows => _dataGridRows;

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    final T item = row.getCells()[0].value as T;
    final bool isSelected = (item == _selectedValue);
    return DataGridRowAdapter(
      cells: [
        _itemBuilder(item, isSelected, ValueKey(item.hashCode)), // Riutilizza l'itemBuilder originale
      ],
    );
  }

  void updateData(List<T> newItems) {
    _items = newItems;
    _buildDataGridRows();
    notifyListeners();
  }
}

// --- DATASOURCE (CORRETTO) ---
class _ColleghiDataSource extends DataTableSource {
  final List<Collega> colleghi;
  final String? currentUserId;
  final Function(Collega) onSelect;

  _ColleghiDataSource({required this.colleghi, required this.currentUserId, required this.onSelect});

  @override
  DataRow getRow(int index) {
    final collega = colleghi[index];
    final isCurrentUser = collega.id == currentUserId;

    print('ColleghiDataSource: Collega: ${collega.cognome}, Photo URL: ${collega.photoUrl}'); // Debugging Photo URL

    return DataRow.byIndex(
      index: index,
      selected: collega.isSelected,
      onSelectChanged: isCurrentUser ? null : (isSelected) => onSelect(collega),
      cells: [
        DataCell(
          Checkbox(
            value: collega.isSelected,
            onChanged: isCurrentUser ? null : (v) => onSelect(collega),
          ),
        ),
        DataCell(
          CircleAvatar(
            backgroundColor: Colors.grey[200], // Light grey background for placeholder
            backgroundImage: (collega.photoUrl != null && Uri.tryParse(collega.photoUrl!)?.isAbsolute == true)
                ? NetworkImage(collega.photoUrl!) // Load network image if URL is valid and absolute
                : null, // No background image if URL is invalid or null/empty
            child: (collega.photoUrl == null || collega.photoUrl!.isEmpty || Uri.tryParse(collega.photoUrl!)?.isAbsolute != true)
                ? Icon(Icons.person, color: Colors.grey[600], size: 28) // Placeholder icon if no valid photo URL
                : null, // No child if image is loaded
          ),
        ),
        DataCell(Text(collega.ente)),
        DataCell(Text(collega.id)),
        DataCell(Text(collega.cognome)),
        DataCell(Text(collega.nome)),
        DataCell(Text(collega.email)),
        DataCell(Text(collega.telefoni.join(', '))), // Display telephones, joined by comma
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

// Assicurati che NavigationService sia definito nel tuo progetto,
// ad esempio in un file separato o qui se è un singleton semplice.
class NavigationService {
  static GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
}
