// lib/screens/colleghi_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Enum per il tipo di ruolo selezionato dai chip
enum RoleType { all, docente, tecnico }

// Modello di dati per un collega, basato sulla tabella 'personale'
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
    List<String> ruoliList = [];
    if (json['ruoli'] != null && json['ruoli'] is List) {
      ruoliList = (json['ruoli'] as List).map((item) => item.toString()).toList();
    }

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

// Modello per la struttura (invariato)
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
  bool operator ==(Object other) => identical(this, other) || other is Struttura && runtimeType == other.runtimeType && ente == other.ente && id == other.id;

  @override
  int get hashCode => ente.hashCode ^ id.hashCode;
}

class ColleghiScreen extends StatefulWidget {
  const ColleghiScreen({super.key});

  @override
  State<ColleghiScreen> createState() => _ColleghiScreenState();
}

class _ColleghiScreenState extends State<ColleghiScreen> {
  final _supabase = Supabase.instance.client;

  // Stato Dati
  List<Struttura> _strutture = [];
  Struttura? _strutturaSelezionata;
  List<Collega> _allColleaguesForStructure = [];
  List<Collega> _filteredColleghi = [];
  Future<void>? _dataLoadingFuture;
  int? _currentUserId; // Aggiornato a int per corrispondere al modello Collega

  // Stato Filtri
  RoleType _selectedRoleType = RoleType.all;
  String? _selectedRole;

  // Stato Tabella
  bool _selectAll = false;
  int _rowsPerPage = 10;
  int _sortColumnIndex = 1;
  bool _sortAscending = true;

  @override
  void initState() {
    super.initState();
    _dataLoadingFuture = _initializeData();
  }

  Future<void> _initializeData() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null || user.email == null) throw 'Utente o email non trovati.';

      final personaleUtenteCorrente = await _supabase.from('personale').select('id, ente, struttura, indirizzo').eq('email_principale', user.email!).single();
      _currentUserId = personaleUtenteCorrente['id'] as int;
      final userEnte = personaleUtenteCorrente['ente'] as String;
      final userStrutturaId = personaleUtenteCorrente['struttura'] as int;

      final struttureData = await _supabase.from('strutture').select('ente, id, nome, indirizzo').eq('ente', userEnte).order('nome');
      _strutture = struttureData.map((json) => Struttura.fromJson(json)).toList();

      _strutturaSelezionata = _strutture.firstWhere((s) => s.id == userStrutturaId);

      await _fetchColleagues(_strutturaSelezionata!);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _fetchColleagues(Struttura struttura) async {
    final response = await _supabase.rpc('get_colleagues_by_struttura', params: {'p_ente': struttura.ente, 'p_struttura_id': struttura.id});

    _allColleaguesForStructure = (response as List).map((json) => Collega.fromJson(json)).toList();

    if (!mounted) return;
    setState(() {
      _resetFiltersAndApply();
    });
  }

  void _resetFiltersAndApply() {
    _selectedRoleType = RoleType.all;
    _selectedRole = null;
    _applyFilters();
  }

  // --- LOGICA DI FILTRAGGIO CORRETTA ---
  bool _isTecnico(Collega c) => c.ruoli.any((r) => r.toLowerCase().startsWith('area'));
  bool _isDocente(Collega c) => c.ruoli.isNotEmpty && !_isTecnico(c);

  void _applyFilters() {
    List<Collega> tempFilteredList = List.from(_allColleaguesForStructure);

    // 1. Filtro per tipo di ruolo (Docente / Tecnico) usando la logica corretta
    if (_selectedRoleType == RoleType.docente) {
      tempFilteredList.retainWhere(_isDocente);
    } else if (_selectedRoleType == RoleType.tecnico) {
      tempFilteredList.retainWhere(_isTecnico);
    }

    // 2. Filtro per ruolo specifico dal dropdown
    if (_selectedRole != null && _selectedRole != 'Tutti') {
      tempFilteredList.retainWhere((c) => c.ruoli.contains(_selectedRole));
    }

    setState(() {
      _filteredColleghi = tempFilteredList;
      _selectAll = false;
    });
  }

  // --- POPOLAMENTO CORRETTO DEL DROPDOWN DEI RUOLI ---
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
    final sortedRoles = rolesToShow.toList()..sort((a, b) => a.compareTo(b));
    return ['Tutti', ...sortedRoles];
  }

  void _onSort(int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
      _filteredColleghi.sort((a, b) {
        final valueA = columnIndex == 1 ? a.cognome : a.nome;
        final valueB = columnIndex == 1 ? b.cognome : b.nome;
        return ascending ? Comparable.compare(valueA, valueB) : Comparable.compare(valueB, valueA);
      });
    });
  }

  // ... (funzione di salvataggio invariata) ...

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: _dataLoadingFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text('Errore: ${snapshot.error}'));
          return _buildMainContent();
        });
  }

  Widget _buildMainContent() {
    return Column(
      children: [
        // Selettore Struttura
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: DropdownButtonFormField<Struttura>(
            value: _strutturaSelezionata,
            items: _strutture
                .map((s) => DropdownMenuItem<Struttura>(
                      value: s,
                      child: Text(
                        s.nome + (s.indirizzo != null ? ' (${s.indirizzo})' : ''),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ))
                .toList(),
            onChanged: (newValue) {
              if (newValue != null) {
                setState(() => _strutturaSelezionata = newValue);
                _fetchColleagues(newValue);
              }
            },
            decoration: const InputDecoration(labelText: 'Struttura di Appartenenza', border: OutlineInputBorder()),
            isExpanded: true,
          ),
        ),

        // --- PANNELLO FILTRI CORRETTO CON CHOICECHIP ---
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              /**
              Wrap(
                spacing: 8.0,
                children: [
                  ChoiceChip(
                    label: const Text('Tutti'),
                    selected: _selectedRoleType == RoleType.all,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedRoleType = RoleType.all;
                          _selectedRole = null;
                          _applyFilters();
                        });
                      }
                    },
                  ),
                  ChoiceChip(
                    label: const Text('Docente'),
                    selected: _selectedRoleType == RoleType.docente,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedRoleType = RoleType.docente;
                          _selectedRole = null;
                          _applyFilters();
                        });
                      }
                    },
                  ),
                  ChoiceChip(
                    label: const Text('Amm./Tecnico'),
                    selected: _selectedRoleType == RoleType.tecnico,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedRoleType = RoleType.tecnico;
                          _selectedRole = null;
                          _applyFilters();
                        });
                      }
                    },
                  ),
                ],
              ),
              **/
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedRole ?? 'Tutti',
                  items: _dropdownRoles.map((role) => DropdownMenuItem(value: role, child: Text(role, overflow: TextOverflow.ellipsis))).toList(),
                  onChanged: (newValue) => setState(() {
                    _selectedRole = newValue;
                    _applyFilters();
                  }),
                  decoration: const InputDecoration(labelText: 'Ruolo', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                ),
              ),
            ],
          ),
        ),

        // Tabella Dati
        Expanded(
          child: SingleChildScrollView(
            child: PaginatedDataTable(
              header: const Text('Elenco Colleghi'),
              rowsPerPage: _rowsPerPage,
              onRowsPerPageChanged: (value) => setState(() => _rowsPerPage = value ?? 10),
              dataRowMinHeight: 40.0,
              dataRowMaxHeight: 40.0,
              sortColumnIndex: _sortColumnIndex,
              sortAscending: _sortAscending,
              columns: [
                DataColumn(
                    label: Checkbox(
                        value: _selectAll,
                        onChanged: (v) => setState(() {
                              _selectAll = v!;
                              for (var c in _filteredColleghi) {
                                if (c.id != _currentUserId) c.isSelected = _selectAll;
                              }
                            }))),
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
        // ... (pulsante Salva in Rubrica invariato) ...
      ],
    );
  }
}

class _ColleghiDataSource extends DataTableSource {
  final List<Collega> colleghi;
  final int? currentUserId; // Aggiornato a int
  final Function(Collega) onSelect;

  _ColleghiDataSource({required this.colleghi, required this.currentUserId, required this.onSelect});

  @override
  DataRow? getRow(int index) {
    if (index >= colleghi.length) return null;
    final collega = colleghi[index];
    final isCurrentUser = collega.id == currentUserId;

    return DataRow.byIndex(
      index: index,
      selected: collega.isSelected,
      onSelectChanged: isCurrentUser ? null : (isSelected) => onSelect(collega),
      color: isCurrentUser ? WidgetStateProperty.all(Colors.grey[200]) : null,
      cells: [
        DataCell(Checkbox(
          value: collega.isSelected,
          onChanged: isCurrentUser ? null : (v) => onSelect(collega),
        )),
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
