// lib/screens/contatti/colleghi_screen.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:una_social/controllers/auth_controller.dart';
import 'package:una_social/controllers/personale_controller.dart';
import 'package:una_social/helpers/db_grid.dart';
import 'package:una_social/helpers/logger_helper.dart';
import 'package:una_social/helpers/snackbar_helper.dart';

class ColleghiScreen extends StatefulWidget {
  const ColleghiScreen({super.key});

  @override
  State<ColleghiScreen> createState() => _ColleghiScreenState();
}

class _ColleghiScreenState extends State<ColleghiScreen> {
  // State for loading indicators
  bool isLoading = true; // General loading state for initial setup
  bool _isLoadingDropdowns = false; // Loading state for dropdowns

  // State for Ente and Struttura dropdowns
  String? _selectedEnte;
  int? _selectedStrutturaId;
  String? _selectedStrutturaNome;

  List<Map<String, dynamic>> _entiList = [];
  List<Map<String, dynamic>> _struttureList = []; // Will hold structures for the selected Ente, including "Tutte le strutture"

  final AuthController authController = Get.find<AuthController>();
  // Rimosso l'istanza di UiController da qui, non è più necessaria per initState.
  // La gestione dei breadcrumbs è centralizzata in AppRouter.
  final PersonaleController personaleController = Get.find<PersonaleController>();

  // Controllers for text fields (for display purposes)
  final TextEditingController _enteController = TextEditingController();
  final TextEditingController _strutturaController = TextEditingController();

  // State for pagination
  int _currentPage = 0; // Current page index (0-based)
  final int _pageSize = 25; // Initial page length as requested
  int _totalRecords = 0; // Total records, updated by DBGridWidget

  // State for filtering (UI elements for these should be added)
  String? _currentFilterColumn; // e.g., 'cognome', 'nome', 'email_principale'
  String? _currentFilterValue;

  // State for sorting
  final String _currentSortColumn = 'cognome';
  final String _currentSortDirection = 'asc';

  // Grid columns definition
  final List<GridColumn> columns = [
    GridColumn(columnName: 'photo_url', columnWidthMode: ColumnWidthMode.fitByColumnName, label: const Text('Foto')),
    GridColumn(columnName: 'cognome', columnWidthMode: ColumnWidthMode.fill, label: const Text('Cognome')),
    GridColumn(columnName: 'nome', columnWidthMode: ColumnWidthMode.fill, label: const Text('Nome')),
    GridColumn(columnName: 'email_principale', columnWidthMode: ColumnWidthMode.fill, label: const Text('Email')),
  ];

  @override
  void initState() {
    super.initState();
    _initializeDropdowns();
    // Rimosso: uiController.updateBreadcrumbs(UiController.buildBreadcrumbsFromPath('/app/colleghi'));
    // L'aggiornamento dei breadcrumbs è gestito centralmente dal ShellRoute in app_router.dart
  }

  @override
  void dispose() {
    _enteController.dispose();
    _strutturaController.dispose();
    super.dispose();
  }

  // Initializes dropdowns based on user's profile or defaults
  Future<void> _initializeDropdowns() async {
    if (!mounted) return;

    // Set initial loading state and title
    setState(() {
      isLoading = true;
      _isLoadingDropdowns = true;
    });

    await _fetchEnti();
    _entiList.insert(0, {'ente': 'Tutti gli enti'});

    String? userProfileEnte;
    int? userProfileStrutturaId;

    if (personaleController.personale.value != null) {
      userProfileEnte = personaleController.personale.value!.ente as String?;
      userProfileStrutturaId = personaleController.personale.value!.struttura as int?;
    }

    _selectedEnte = userProfileEnte ?? 'Tutti gli enti';
    _enteController.text = _selectedEnte!;

    _struttureList.clear();
    if (_selectedEnte != 'Tutti gli enti') {
      await _fetchStrutture(_selectedEnte!);
    } else {
      await _fetchStrutture(null); // Fetch all structures if "Tutti gli enti" is selected
    }

    // Ensure "Tutte le strutture" is always the first option and unique
    if (_struttureList.where((s) => s['id'] == -1).isEmpty) {
      _struttureList.insert(0, {'id': -1, 'nome': 'Tutte le strutture'});
    }

    if (userProfileStrutturaId != null && userProfileStrutturaId != -1) {
      final structure = _struttureList.firstWhereOrNull((s) => s['id'] == userProfileStrutturaId);
      if (structure != null) {
        _selectedStrutturaId = userProfileStrutturaId;
        _selectedStrutturaNome = structure['nome'] as String?;
        _strutturaController.text = "$userProfileStrutturaId - $_selectedStrutturaNome";
      } else {
        _selectedStrutturaId = -1;
        _selectedStrutturaNome = 'Tutte le strutture';
        _strutturaController.text = "Tutte le strutture";
      }
    } else {
      _selectedStrutturaId = -1;
      _selectedStrutturaNome = 'Tutte le strutture';
      _strutturaController.text = "Tutte le strutture";
    }

    // _updateScreenTitle() è stato rimosso in quanto il titolo della AppBar
    // è ora gestito dai breadcrumbs di HomeScreen tramite UiController.
    // Se la logica del titolo dinamico fosse necessaria per un display interno
    // al ColleghiScreen, andrebbe utilizzata qui per una variabile di stato locale.

    // Update the UI controller with the final title and set loading to false in one go.
    setState(() {
      isLoading = false;
      _isLoadingDropdowns = false;
    });
  }

  // Fetches the list of entities (Enti)
  Future<void> _fetchEnti() async {
    try {
      final response = await Supabase.instance.client.from('enti').select('ente');
      if (mounted) {
        setState(() {
          _entiList = (response as List<dynamic>).cast<Map<String, dynamic>>();
        });
      }
    } catch (e) {
      appLogger.error('Errore nel recupero degli enti: $e');
      if (mounted) SnackbarHelper.showErrorSnackbar(context, 'Errore nel caricamento degli enti.');
    }
  }

  // Fetches structures for a given entity (Ente)
  Future<void> _fetchStrutture(String? ente) async {
    List<Map<String, dynamic>> fetchedStructures = [];
    try {
      if (ente != null) {
        final response = await Supabase.instance.client.from('strutture').select('id, nome').eq('ente', ente).order('nome');
        fetchedStructures = (response as List<dynamic>).cast<Map<String, dynamic>>();
      } else {
        final response = await Supabase.instance.client.from('strutture').select('id, nome').order('nome');
        fetchedStructures = (response as List<dynamic>).cast<Map<String, dynamic>>();
      }

      if (mounted) {
        setState(() {
          _struttureList = fetchedStructures;
          if (_struttureList.where((s) => s['id'] == -1).isEmpty) {
            _struttureList.insert(0, {'id': -1, 'nome': 'Tutte le strutture'});
          }
        });
      }
    } catch (e) {
      appLogger.error('Errore nel recupero delle strutture per ente $ente: $e');
      if (mounted) SnackbarHelper.showErrorSnackbar(context, 'Errore nel caricamento delle strutture.');
      if (mounted) {
        setState(() {
          _struttureList = [];
          _struttureList.insert(0, {'id': -1, 'nome': 'Tutte le strutture'});
        });
      }
    }
  }

  // _updateScreenTitle() è stato rimosso, in quanto il titolo della AppBar
  // è ora gestito dai breadcrumbs di HomeScreen tramite UiController.
  // Se la logica del titolo dinamico fosse necessaria per un display interno
  // al ColleghiScreen, andrebbe utilizzata qui per una variabile di stato locale.

  // Resets to the first page and triggers state update.
  void _refreshData() {
    setState(() {
      _currentPage = 0; // Reset to the first page
    });
    // Rimosso: _updateScreenTitle(); // Non più necessario qui per l'AppBar
  }

  // Handler for Ente dropdown changes
  void _onEnteChanged(String? newValue) async {
    if (newValue == null) return;

    setState(() {
      _selectedEnte = newValue;
      _selectedStrutturaId = null; // Reset structure selection
      _selectedStrutturaNome = null;
      _struttureList = []; // Clear current structures (will be refetched by _fetchStrutture)
      _strutturaController.clear();
      _currentPage = 0; // Reset page to 0
    });

    _enteController.text = newValue;

    if (newValue == 'Tutti gli enti') {
      await _fetchStrutture(null); // Fetch all structures
      _selectedStrutturaId = -1;
      _selectedStrutturaNome = 'Tutte le strutture';
      _strutturaController.text = "Tutte le strutture";
    } else {
      await _fetchStrutture(newValue); // Fetch structures for the selected ente
      if (_struttureList.where((s) => s['id'] == -1).isEmpty) {
        _struttureList.insert(0, {'id': -1, 'nome': 'Tutte le strutture'});
      }
      if (_selectedStrutturaId == null || _selectedStrutturaId == -1 || !_struttureList.any((s) => s['id'] == _selectedStrutturaId)) {
        _selectedStrutturaId = -1;
        _selectedStrutturaNome = 'Tutte le strutture';
        _strutturaController.text = "Tutte le strutture";
      } else {
        final structure = _struttureList.firstWhereOrNull((s) => s['id'] == _selectedStrutturaId);
        if (structure != null) {
          _selectedStrutturaNome = structure['nome'] as String?;
          _strutturaController.text = "$_selectedStrutturaId - $_selectedStrutturaNome";
        } else {
          _selectedStrutturaId = -1;
          _selectedStrutturaNome = 'Tutte le strutture';
          _strutturaController.text = "Tutte le strutture";
        }
      }
    }
    _refreshData(); // Trigger state update, causing DBGridWidget to refetch
  }

  // Handler for Struttura selection changes (from Autocomplete)
  void _onStrutturaSelected(Map<String, dynamic> selectedStructure) {
    final int? newId = selectedStructure['id'] as int?;
    final String? newName = selectedStructure['nome'] as String?;

    if (newId == null || newName == null) return;

    setState(() {
      _selectedStrutturaId = newId;
      _selectedStrutturaNome = newName;
      _currentPage = 0; // Reset page to 0 when Struttura changes
    });

    if (newId == -1) {
      _strutturaController.text = "Tutte le strutture";
    } else {
      _strutturaController.text = "$newId - $newName";
    }
    _refreshData(); // Trigger state update
  }

  // Method to go to the previous page
  void _goToPreviousPage() {
    if (_currentPage > 0) {
      setState(() {
        _currentPage--;
      });
    }
  }

  // Method to go to the next page
  void _goToNextPage() {
    final int totalPages = (_totalRecords / _pageSize).ceil();
    if (_currentPage < totalPages - 1) {
      setState(() {
        _currentPage++;
      });
    }
  }

  // Callback to update total records from DBGridWidget
  void _onDBGridTotalRecordsChanged(int totalRecords) {
    if (mounted) {
      setState(() {
        _totalRecords = totalRecords;
        final int totalPages = (_totalRecords / _pageSize).ceil();
        if (_currentPage >= totalPages && totalPages > 0) {
          _currentPage = totalPages - 1;
        } else if (totalPages == 0 && _currentPage != 0) {
          _currentPage = 0;
        }
      });
    }
  }

  // Builds the Ente dropdown widget
  Widget getEnteDropdown() {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: "Ente",
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: _selectedEnte,
          hint: const Text("Seleziona Ente"),
          items: _entiList.map((e) {
            final ente = e['ente'].toString();
            return DropdownMenuItem<String>(value: ente, child: Text(ente));
          }).toList(),
          onChanged: _onEnteChanged,
        ),
      ),
    );
  }

  // Builds the Struttura Autocomplete widget
  Widget getStrutturaAutocomplete() {
    return Autocomplete<Map<String, dynamic>>(
      key: ValueKey('struttura_autocomplete_$_selectedEnte'), // Key to force rebuild when ente changes
      fieldViewBuilder: (BuildContext context, TextEditingController textEditingController, FocusNode focusNode, VoidCallback onFieldSubmitted) {
        _strutturaController.value = textEditingController.value;
        textEditingController.addListener(() {
          if (_strutturaController.text != textEditingController.text) {
            _strutturaController.text = textEditingController.text;
          }
        });

        return TextFormField(
          controller: textEditingController,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: "Struttura",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            suffixIcon: textEditingController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 20),
                    onPressed: () {
                      textEditingController.clear();
                      _onStrutturaSelected({'id': -1, 'nome': 'Tutte le strutture'});
                      focusNode.unfocus();
                    },
                  )
                : null,
          ),
          onFieldSubmitted: (String value) {
            final matchingOption = _struttureList.firstWhereOrNull((s) =>
                (s['id'] != null && s['id'].toString() == value) ||
                (s['nome'] != null && s['nome'].toString().toLowerCase() == value.toLowerCase()) ||
                (s['id'] != null && s['nome'] != null && "${s['id']} - ${s['nome']}".toLowerCase() == value.toLowerCase()));
            if (matchingOption != null) {
              _onStrutturaSelected(matchingOption);
            } else {
              _onStrutturaSelected({'id': -1, 'nome': 'Tutte le strutture'});
            }
            onFieldSubmitted();
          },
        );
      },
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return _struttureList;
        }

        final String searchText = textEditingValue.text.toLowerCase();
        final bool hasDigits = searchText.contains(RegExp(r'\d'));

        final List<Map<String, dynamic>> suggestions = [];
        final Map<String, dynamic> tutteLeStrutture = {'id': -1, 'nome': 'Tutte le strutture'};

        if (tutteLeStrutture['nome'].toString().toLowerCase().contains(searchText)) {
          suggestions.add(tutteLeStrutture);
        }

        if (hasDigits && searchText.isNotEmpty) {
          final int? searchId = int.tryParse(searchText);
          if (searchId != null) {
            suggestions.addAll(_struttureList.where((s) => s['id'] != -1 && s['id'] == searchId));
          }
        } else if (searchText.length >= 3) {
          suggestions.addAll(_struttureList.where((s) => s['id'] != -1 && s['nome'].toString().toLowerCase().contains(searchText)));
        }

        final uniqueSuggestions = <Map<String, dynamic>>[];
        final Set<int> seenIds = <int>{};
        for (var s in suggestions) {
          if (s['id'] == -1) {
            if (!uniqueSuggestions.any((us) => us['id'] == -1)) {
              uniqueSuggestions.insert(0, s);
            }
          } else if (!seenIds.contains(s['id'])) {
            uniqueSuggestions.add(s);
            seenIds.add(s['id'] as int);
          }
        }

        uniqueSuggestions.sort((a, b) {
          if (a['id'] == -1) return -1;
          if (b['id'] == -1) return 1;
          return (a['nome'] as String).toLowerCase().compareTo((b['nome'] as String).toLowerCase());
        });

        return uniqueSuggestions;
      },
      displayStringForOption: (Map<String, dynamic> option) {
        final id = option['id'] as int;
        final nome = option['nome'].toString();
        if (id == -1) {
          return nome;
        }
        return "$id - $nome";
      },
      onSelected: _onStrutturaSelected,
      optionsViewBuilder: (BuildContext context, AutocompleteOnSelected<Map<String, dynamic>> onSelected, Iterable<Map<String, dynamic>> options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4.0,
            child: SizedBox(
              height: options.isNotEmpty ? 200.0 : 0,
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: options.length,
                itemBuilder: (BuildContext context, int index) {
                  final Map<String, dynamic> option = options.elementAt(index);
                  return InkWell(
                    onTap: () {
                      onSelected(option);
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        option['id'] == -1 ? option['nome'].toString() : "${option['id']} - ${option['nome']}",
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  // Builds the row containing Ente and Struttura dropdowns
  Widget getSelectionRow() {
    return Container(
      color: const Color.fromARGB(255, 0, 204, 136),
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
      child: Row(
        children: [
          const Text(
            "Filtra Colleghi:",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(width: 16),
          Expanded(flex: 2, child: getEnteDropdown()),
          const SizedBox(width: 16),
          Expanded(flex: 3, child: getStrutturaAutocomplete()),
          if (_isLoadingDropdowns)
            Padding(
              padding: const EdgeInsets.only(left: 16.0),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)),
            ),
        ],
      ),
    );
  }

  // --- Main Build Method ---
  @override
  Widget build(BuildContext context) {
    final bool showInitialLoading = isLoading || _isLoadingDropdowns;

    if (showInitialLoading && (personaleController.personale.value == null && Supabase.instance.client.auth.currentUser != null)) {
      // Usiamo un Center con CircularProgressIndicator perché lo Scaffold è fornito dal parent.
      return const Center(child: CircularProgressIndicator());
    }

    if (personaleController.personale.value == null) {
      // Usiamo un Center con Text perché lo Scaffold è fornito dal parent.
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            authController.isPersonale ? 'Errore: Dati del personale non disponibili. Tentare di ricaricare l\'app o contattare il supporto.' : 'Questa sezione è riservata al personale universitario.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.error),
          ),
        ),
      );
    }

    final Map<String, dynamic> rpcParams = {
      'p_ente': (_selectedEnte != null && _selectedEnte != 'Tutti gli enti') ? _selectedEnte : null,
      'p_struttura_id': (_selectedStrutturaId != null && _selectedStrutturaId != -1) ? _selectedStrutturaId : null,
      'p_filter_column': _currentFilterColumn,
      'p_filter_value': _currentFilterValue,
      'p_limit': _pageSize,
      'p_offset': _currentPage * _pageSize,
      'p_order_by': _currentSortColumn,
      'p_order_direction': _currentSortDirection,
    };

    final dbGridConfig = DBGridConfig(
      columns: columns,
      dataSourceTable: 'colleghi',
      emptyDataMessage: "Nessun collega trovato per i criteri selezionati.",
      excludeColumns: ['ente', 'struttura'],
      fixedColumnsCount: 1,
      initialSortBy: [
        SortColumn(column: _currentSortColumn, direction: _currentSortDirection == 'asc' ? SortDirection.asc : SortDirection.desc),
      ],
      pageLength: _pageSize,
      primaryKeyColumns: ['id'],
      rpcFunctionName: 'get_colleagues_by_struttura',
      rpcFunctionParams: rpcParams,
      selectable: true,
      showHeader: true,
      uiModes: const [UIMode.grid],
      onTotalRecordsChanged: _onDBGridTotalRecordsChanged,
    );

    final String dynamicKeyString = '${_selectedEnte}_${_selectedStrutturaId}_${_currentPage}_${_pageSize}_${_currentSortColumn}_${_currentSortDirection}_${_currentFilterColumn}_$_currentFilterValue';
    final ValueKey<String> dbGridKey = ValueKey<String>(dynamicKeyString);

    final int totalPages = (_totalRecords / _pageSize).ceil();

    // Rimosso lo Scaffold e l'AppBar, restituisci direttamente la Column
    return Column(
      children: [
        getSelectionRow(),
        if (showInitialLoading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else
          Expanded(
            child: DBGridWidget(
              key: dbGridKey,
              config: dbGridConfig,
            ),
          ),
        if (!showInitialLoading && _totalRecords > 0)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _currentPage > 0 ? _goToPreviousPage : null,
                ),
                Text('Pag. ${_currentPage + 1}/$totalPages'),
                IconButton(
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: _currentPage < totalPages - 1 ? _goToNextPage : null,
                ),
              ],
            ),
          ),
      ],
    );
  }
}
