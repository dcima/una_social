import 'package:flutter/material.dart';

// Modello di dati per un collega (da adattare con i dati reali)
class Collega {
  final String id;
  final String nome;
  final String cognome;
  final String email;
  bool isSelected;

  Collega({
    required this.id,
    required this.nome,
    required this.cognome,
    required this.email,
    this.isSelected = false,
  });
}

// Modello per la struttura (da adattare)
class Struttura {
  final String id;
  final String nome;
  Struttura({required this.id, required this.nome});
}

class ColleghiScreen extends StatefulWidget {
  const ColleghiScreen({super.key});

  @override
  State<ColleghiScreen> createState() => _ColleghiScreenState();
}

class _ColleghiScreenState extends State<ColleghiScreen> {
  // --- Dati di Esempio (da sostituire con chiamate reali) ---
  List<Collega> _colleghi = [];
  List<Struttura> _strutture = [];
  Struttura? _strutturaSelezionata;
  bool _isLoading = true;

  // Stato per la selezione
  bool _selectAll = false;
  int _rowsPerPage = 10;
  int _sortColumnIndex = 1; // Ordina per cognome di default
  bool _sortAscending = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  // PUNTO 2: Funzione per recuperare i dati
  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    // Simula una chiamata di rete per 'get-colleagues' e strutture
    await Future.delayed(const Duration(seconds: 1));

    // Qui andrebbe la vera chiamata API per ottenere le strutture
    // es. final struttureFromApi = await api.getStrutture();
    final struttureFromApi = [
      Struttura(id: 'DSI', nome: 'Dipartimento di Scienze Informatiche'),
      Struttura(id: 'DSG', nome: 'Dipartimento di Scienze Giuridiche'),
    ];

    // Qui andrebbe la vera chiamata API per 'get-colleagues'
    // basata sulla struttura dell'utente loggato.
    // es. final colleghiFromApi = await api.getColleagues('DSI');
    final colleghiFromApi = List.generate(
      30,
      (index) => Collega(
        id: 'user_${index + 1}',
        nome: 'Nome${index + 1}',
        cognome: 'Cognome${index + 1}',
        email: 'collega${index + 1}@unibo.it',
      ),
    );

    setState(() {
      _strutture = struttureFromApi;
      // PUNTO 4: Imposta la struttura dell'utente loggato
      // (qui simuliamo che sia la prima della lista)
      _strutturaSelezionata = _strutture.first;
      _colleghi = colleghiFromApi;
      _isLoading = false;
    });
  }

  void _onSort(int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
      _colleghi.sort((a, b) {
        final Comparable valueA = columnIndex == 1 ? a.cognome : a.nome;
        final Comparable valueB = columnIndex == 1 ? b.cognome : b.nome;
        return ascending ? Comparable.compare(valueA, valueB) : Comparable.compare(valueB, valueA);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Importa Colleghi'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // PUNTO 4: Combobox Struttura
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: DropdownButtonFormField<Struttura>(
                    value: _strutturaSelezionata,
                    items: _strutture.map((struttura) {
                      return DropdownMenuItem<Struttura>(
                        value: struttura,
                        child: Text(struttura.nome),
                      );
                    }).toList(),
                    onChanged: (Struttura? newValue) {
                      setState(() {
                        _strutturaSelezionata = newValue;
                        // Qui dovresti ricaricare i colleghi per la nuova struttura
                        _fetchData();
                      });
                    },
                    decoration: const InputDecoration(
                      labelText: 'Struttura di Appartenenza',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                // PUNTO 5: Elenco colleghi con selezione
                Expanded(
                  child: SingleChildScrollView(
                    child: PaginatedDataTable(
                      header: const Text('Elenco Colleghi'),
                      rowsPerPage: _rowsPerPage,
                      onRowsPerPageChanged: (value) {
                        setState(() {
                          _rowsPerPage = value ?? 10;
                        });
                      },
                      sortColumnIndex: _sortColumnIndex,
                      sortAscending: _sortAscending,
                      columns: [
                        // Colonna per la selezione
                        DataColumn(
                          label: Checkbox(
                            value: _selectAll,
                            onChanged: (bool? value) {
                              setState(() {
                                _selectAll = value ?? false;
                                for (var collega in _colleghi) {
                                  collega.isSelected = _selectAll;
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
                        colleghi: _colleghi,
                        onSelect: (collega) {
                          setState(() {
                            collega.isSelected = !collega.isSelected;
                          });
                        },
                      ),
                    ),
                  ),
                ),
                // PUNTO 6: Pulsante "Salva in rubrica"
                _buildBottomBar(),
              ],
            ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // I pulsanti di navigazione della PaginatedDataTable sono già presenti
          // Aggiungiamo solo il pulsante di salvataggio
          ElevatedButton.icon(
            icon: const Icon(Icons.save_alt_outlined),
            label: const Text('Salva in Rubrica'),
            onPressed: () {
              final selezionati = _colleghi.where((c) => c.isSelected).toList();
              if (selezionati.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Nessun collega selezionato.')),
                );
                return;
              }
              // Qui va la logica per salvare i 'selezionati'
              print('Salvataggio di ${selezionati.length} contatti...');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Salvati ${selezionati.length} colleghi nella rubrica.')),
              );
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}

// DataSource per la PaginatedDataTable
class _ColleghiDataSource extends DataTableSource {
  final List<Collega> colleghi;
  final Function(Collega) onSelect;

  _ColleghiDataSource({required this.colleghi, required this.onSelect});

  @override
  DataRow? getRow(int index) {
    if (index >= colleghi.length) {
      return null;
    }
    final collega = colleghi[index];
    return DataRow.byIndex(
      index: index,
      selected: collega.isSelected,
      onSelectChanged: (isSelected) {
        if (isSelected != null) {
          onSelect(collega);
        }
      },
      cells: [
        DataCell(Checkbox(value: collega.isSelected, onChanged: (v) => onSelect(collega))),
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
