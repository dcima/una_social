// lib/screens/colleghi_screen.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:una_social/controllers/auth_controller.dart';
import 'package:una_social/controllers/personale_controller.dart';
import 'package:una_social/controllers/ui_controller.dart';
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
  final UiController uiController = Get.find<UiController>();
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
  String _currentSortColumn = 'cognome';
  String _currentSortDirection = 'asc';

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
    uiController.setCurrentScreenName('Colleghi: Caricamento...');
    // Initialize dropdowns based on user profile or defaults
    _initializeDropdowns();
  }

  @override
  void dispose() {
    _enteController.dispose();
    _strutturaController.dispose();
    super.dispose();
  }

  // Resets the screen to its initial or empty state
  void _resetScreenState() {
    setState(() {
      isLoading = false;
      _isLoadingDropdowns = false;
      _selectedEnte = null;
      _selectedStrutturaId = null;
      _selectedStrutturaNome = null;
      _entiList = [];
      _struttureList = [];
      _currentPage = 0;
      _totalRecords = 0;
      _currentFilterValue = null;
      _currentSortColumn = 'cognome';
      _currentSortDirection = 'asc';
      _enteController.clear();
      _strutturaController.clear();
    });
    uiController.setCurrentScreenName('Colleghi: Nessun Dati');
  }

  // Initializes dropdowns based on user's profile or defaults
  Future<void> _initializeDropdowns() async {
    if (!mounted) return;

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

    // Set _selectedEnte: user's ente if exists, otherwise 'Tutti gli enti'
    _selectedEnte = userProfileEnte ?? 'Tutti gli enti';
    _enteController.text = _selectedEnte!;

    // Ensure "Tutte le strutture" is always the first option
    _struttureList.clear();

    // Fetch structures for the resolved _selectedEnte
    if (_selectedEnte != 'Tutti gli enti') {
      await _fetchStrutture(_selectedEnte!);
    } else {
      await _fetchStrutture(null);
    }

    _struttureList.insert(0, {'id': -1, 'nome': 'Tutte le strutture'});

    // Set _selectedStrutturaId: user's structure if found and valid for selected ente, otherwise -1
    if (userProfileStrutturaId != null && userProfileStrutturaId != -1) {
      final structure = _struttureList.firstWhereOrNull((s) => s['id'] == userProfileStrutturaId);
      if (structure != null) {
        _selectedStrutturaId = userProfileStrutturaId;
        _selectedStrutturaNome = structure['nome'] as String?;
        _strutturaController.text = "$userProfileStrutturaId - $_selectedStrutturaNome";
      } else {
        // User's structure not found in the list (e.g., belongs to a different ente), default to 'Tutte le strutture'
        _selectedStrutturaId = -1;
        _selectedStrutturaNome = 'Tutte le strutture';
        _strutturaController.text = "Tutte le strutture";
      }
    } else {
      // No user structure or it's -1, default to 'Tutte le strutture'
      _selectedStrutturaId = -1;
      _selectedStrutturaNome = 'Tutte le strutture';
      _strutturaController.text = "Tutte le strutture";
    }

    setState(() {
      isLoading = false;
      _isLoadingDropdowns = false;
    });
    _fetchColleagues(); // Fetch initial data based on resolved selections
  }

  // Handles errors during data fetching or initialization
  void _handleError(String message) {
    if (mounted) {
      SnackbarHelper.showErrorSnackbar(context, message);
      setState(() {
        isLoading = false;
        _isLoadingDropdowns = false;
      });
      uiController.setCurrentScreenName('Colleghi: Errore');
    }
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
    var response;

    try {
      if (ente != null) {
        response = await Supabase.instance.client.from('strutture').select('id, nome').eq('ente', ente).order('nome');
      } else {
        response = await Supabase.instance.client.from('strutture').select('id, nome').order('nome');
      }

      if (mounted) {
        setState(() {
          _struttureList = (response as List<dynamic>).cast<Map<String, dynamic>>();
          // Ensure "Tutte le strutture" is always the first option and unique
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
          // Clear and reset on error
          _struttureList = [];
          _struttureList.insert(0, {'id': -1, 'nome': 'Tutte le strutture'});
        });
      }
    }
  }

  // Updates screen title and ensures loading states are managed.
  // This function's state changes will trigger DBGridWidget re-evaluation via ValueKey.
  void _fetchColleagues() {
    String screenTitle = 'Colleghi';
    if (_selectedEnte != null && _selectedEnte != 'Tutti gli enti') {
      screenTitle = 'Colleghi: $_selectedEnte';
      if (_selectedStrutturaNome != null && _selectedStrutturaNome != 'Tutte le strutture') {
        screenTitle += ' - $_selectedStrutturaNome';
      }
    } else if (_selectedStrutturaNome != null && _selectedStrutturaNome != 'Tutte le strutture') {
      screenTitle = 'Colleghi: $_selectedStrutturaNome';
    }
    uiController.setCurrentScreenName(screenTitle);

    setState(() {
      isLoading = false;
    }); // Initial setup loading is done.
  }

  // Resets to the first page and triggers state update.
  // This will cause DBGridWidget to refetch data with the new state.
  void _refreshData() {
    setState(() {
      _currentPage = 0; // Reset to the first page
      // No explicit fetch needed, changing _currentPage will update the key and trigger DBGridWidget
    });
    _fetchColleagues(); // Update title
  }

  // Handler for Ente dropdown changes
  void _onEnteChanged(String? newValue) async {
    if (newValue == null) return;

    setState(() {
      _selectedEnte = newValue;
      _selectedStrutturaId = null; // Reset structure selection
      _selectedStrutturaNome = null;
      _struttureList = []; // Clear current structures
      _strutturaController.clear();
      _currentPage = 0; // Reset page to 0
    });

    _enteController.text = newValue;

    if (newValue == 'Tutti gli enti') {
      // If "Tutti gli enti" is selected, set default "Tutte le strutture"
      _struttureList.clear();
      _struttureList.insert(0, {'id': -1, 'nome': 'Tutte le strutture'});
      _selectedStrutturaId = -1;
      _selectedStrutturaNome = 'Tutte le strutture';
      _strutturaController.text = "Tutte le strutture";
    } else {
      await _fetchStrutture(newValue);
      if (_struttureList.where((s) => s['id'] == -1).isEmpty) {
        _struttureList.insert(0, {'id': -1, 'nome': 'Tutte le strutture'});
      }
      if (_selectedStrutturaId == null || _selectedStrutturaId == -1) {
        _selectedStrutturaId = -1;
        _selectedStrutturaNome = 'Tutte le strutture';
        _strutturaController.text = "Tutte le strutture";
      } else {
        // If a previously selected structure is still valid, keep it.
        final structure = _struttureList.firstWhereOrNull((s) => s['id'] == _selectedStrutturaId);
        if (structure != null) {
          _selectedStrutturaNome = structure['nome'] as String?;
          _strutturaController.text = "$_selectedStrutturaId - $_selectedStrutturaNome";
        } else {
          // If previously selected structure is invalid, reset to default.
          _selectedStrutturaId = -1;
          _selectedStrutturaNome = 'Tutte le strutture';
          _strutturaController.text = "Tutte le strutture";
        }
      }
    }
    _refreshData(); // Trigger state update, causing DBGridWidget to refetch
  }

  // Handler for Struttura dropdown changes
  void _onStrutturaChanged(int? newValue) async {
    if (newValue == null) return;

    setState(() {
      _selectedStrutturaId = newValue;
      if (newValue == -1) {
        _selectedStrutturaNome = 'Tutte le strutture';
      } else {
        _selectedStrutturaNome = _struttureList.firstWhereOrNull((s) => s['id'] == newValue)?['nome'] as String?;
      }
      _currentPage = 0; // Reset page to 0 when Struttura changes
    });

    // Update the text controller for display
    if (newValue == -1) {
      _strutturaController.text = "Tutte le strutture";
    } else {
      _strutturaController.text = "$newValue - $_selectedStrutturaNome";
    }
    _refreshData(); // Trigger state update
  }

  // Method to go to the previous page
  void _goToPreviousPage() {
    if (_currentPage > 0) {
      setState(() {
        _currentPage--;
      });
      // The ValueKey change will trigger DBGridWidget to refetch data
    }
  }

  // Method to go to the next page
  void _goToNextPage() {
    final int totalPages = (_totalRecords / _pageSize).ceil();
    if (_currentPage < totalPages - 1) {
      setState(() {
        _currentPage++;
      });
      // The ValueKey change will trigger DBGridWidget to refetch data
    }
  }

  // Callback to update total records from DBGridWidget
  void _onDBGridTotalRecordsChanged(int totalRecords) {
    if (mounted) {
      setState(() {
        _totalRecords = totalRecords;
        // Ensure current page is valid if total records change
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

  // Builds the Struttura dropdown widget
  Widget getStrutturaDropdown(String? ente) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: "Struttura",
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          isExpanded: true,
          value: _selectedStrutturaId,
          hint: const Text("Seleziona Struttura"),
          items: _struttureList.map((s) {
            final id = s['id'] as int;
            final nome = s['nome'].toString();
            return DropdownMenuItem<int>(value: id, child: Text("$id - $nome"));
          }).toList(),
          // Disable dropdown if "Tutti gli enti" is selected AND it's not the user's default ente
          onChanged: _selectedEnte == null || _selectedEnte == 'Tutti gli enti' ? null : _onStrutturaChanged,
        ),
      ),
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
          Expanded(flex: 3, child: getStrutturaDropdown(_selectedEnte)),
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
    // Determine overall loading state: initial setup or dropdown loading
    final bool showInitialLoading = isLoading || _isLoadingDropdowns;

    // Handle case where user is logged in but personal data hasn't loaded yet.
    if (showInitialLoading && (personaleController.personale.value == null && Supabase.instance.client.auth.currentUser != null)) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Handle case where user is not logged in or personal data is unavailable
    if (personaleController.personale.value == null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              authController.isPersonale ? 'Errore: Dati del personale non disponibili. Tentare di ricaricare l\'app o contattare il supporto.' : 'Questa sezione è riservata al personale universitario.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.error),
            ),
          ),
        ),
      );
    }

    // Construct RPC parameters for DBGridConfig
    // Crucially, include all parameters expected by the Supabase function,
    // passing null or default values if they are not specifically filtered by.
    final Map<String, dynamic> rpcParams = {
      // Always pass p_ente, default to null if 'Tutti gli enti' is selected
      'p_ente': (_selectedEnte != null && _selectedEnte != 'Tutti gli enti') ? _selectedEnte : null,
      // Always pass p_struttura_id, default to null if -1 is selected
      'p_struttura_id': (_selectedStrutturaId != null && _selectedStrutturaId != -1) ? _selectedStrutturaId : null,
      'p_filter_column': _currentFilterColumn,
      'p_filter_value': _currentFilterValue,
      'p_limit': _pageSize,
      'p_offset': _currentPage * _pageSize,
      'p_order_by': _currentSortColumn,
      'p_order_direction': _currentSortDirection,
    };

    // Configure the DBGridWidget
    final dbGridConfig = DBGridConfig(
      columns: columns,
      dataSourceTable: 'colleghi', // Required parameter
      emptyDataMessage: "Nessun collega trovato per i criteri selezionati.",
      excludeColumns: ['ente', 'struttura'], // Columns not to display in the grid
      fixedColumnsCount: 1,
      initialSortBy: [
        SortColumn(column: _currentSortColumn, direction: _currentSortDirection == 'asc' ? SortDirection.asc : SortDirection.desc),
      ],
      pageLength: _pageSize, // Use the page length from state
      primaryKeyColumns: ['id'],
      rpcFunctionName: 'get_colleagues_by_struttura',
      rpcFunctionParams: rpcParams, // Pass the constructed RPC parameters

      selectable: true,
      showHeader: true,
      uiModes: const [UIMode.grid], // Default UI mode
      onTotalRecordsChanged: _onDBGridTotalRecordsChanged, // NEW: Pass the callback
    );

    // --- Dynamic Key Strategy ---
    // Construct a key string from all parameters that influence data fetching.
    // When this string changes, Flutter will re-create the DBGridWidget,
    // forcing a re-initialization and data fetch.
    final String dynamicKeyString = '${_selectedEnte}_${_selectedStrutturaId}_${_currentPage}_${_pageSize}_${_currentSortColumn}_${_currentSortDirection}_${_currentFilterColumn}_$_currentFilterValue';
    final ValueKey<String> dbGridKey = ValueKey<String>(dynamicKeyString);

    final int totalPages = (_totalRecords / _pageSize).ceil();

    return Scaffold(
      body: Column(
        children: [
          getSelectionRow(), // Row with Ente and Struttura dropdowns
          // Show loading indicator during initial setup or dropdown loading
          if (showInitialLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            // The actual data grid widget.
            Expanded(
              child: DBGridWidget(
                key: dbGridKey, // Pass the dynamic key to DBGridWidget
                config: dbGridConfig,
              ),
            ),
          // NEW: Pagination row at the bottom
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
      ),
    );
  }
}
