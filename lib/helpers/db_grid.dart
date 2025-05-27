// lib/helpers/db_grid.dart
// ignore_for_file: prefer_final_fields, prefer_const_constructors_in_immutables, library_private_types_in_public_api

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:una_social_app/helpers/logger_helper.dart';

// --------------- ENUMS E CLASSI DI CONFIGURAZIONE ---------------
enum SortDirection { asc, desc }

enum UIMode { grid, form, map }

class SortColumn {
  final String column;
  final SortDirection direction;
  SortColumn({required this.column, required this.direction});
}

class DBGridConfig {
  final String dataSourceTable;
  final int pageLength;
  final bool showHeader;
  final int fixedColumnsCount;
  final bool selectable;
  final String emptyDataMessage;
  final List<SortColumn> initialSortBy;
  final List<UIMode> uiModes;
  final String? formHookName;
  final String? mapHookName;
  final Function(UIMode newMode)? onViewModeChanged;

  DBGridConfig({
    required this.dataSourceTable,
    this.pageLength = 25,
    this.showHeader = true,
    this.fixedColumnsCount = 0,
    this.selectable = false,
    this.emptyDataMessage = "Nessun dato disponibile.",
    this.initialSortBy = const [],
    this.uiModes = const [UIMode.grid],
    this.formHookName,
    this.mapHookName,
    this.onViewModeChanged,
  });
}

// --------------- INTERFACCIA PUBBLICA DI CONTROLLO ---------------
abstract class DBGridControl {
  void toggleUIModePublic();
  UIMode get currentDisplayUIMode;
  void refreshData();
}

// --------------- WIDGET BASE ASTRATTO ---------------
abstract class DBGridAbstractWidget extends StatefulWidget {
  final DBGridConfig config;
  const DBGridAbstractWidget({super.key, required this.config});
}

// --------------- WIDGET CONCRETO DBGRIDWIDGET ---------------
class DBGridWidget extends DBGridAbstractWidget {
  const DBGridWidget({super.key, required super.config});

  @override
  State<DBGridWidget> createState() => _DBGridWidgetState();
}

class _DBGridWidgetState extends State<DBGridWidget> implements DBGridControl {
  late _DBGridDataSource _dataSource;
  List<Map<String, dynamic>> _data = [];
  List<GridColumn> _columns = [];
  bool _isLoading = true;
  String _errorMessage = '';
  int _currentPage = 0;
  DataGridController _dataGridController = DataGridController();
  // Mantiene lo stato di sort: nome colonna -> direzione (o null se non ordinata per quella colonna)
  Map<String, DataGridSortDirection?> _sortedColumnsState = {};

  late UIMode _currentUIMode;

  @override
  void initState() {
    super.initState();
    _currentUIMode = widget.config.uiModes.isNotEmpty ? widget.config.uiModes.first : UIMode.grid;
    _initializeSortedColumns();
    _dataSource = _DBGridDataSource(
      gridData: _data,
      // config: widget.config, // _config non è usato in _DBGridDataSource
      buildRowCallback: _buildRow,
      selectedRowsDataMap: [], // Inizializza la lista vuota
      onSelectionChanged: () {
        // Callback per aggiornare la UI del checkbox header
        if (mounted) setState(() {});
      },
    );
    _fetchData();
  }

  void _initializeSortedColumns() {
    _sortedColumnsState.clear(); // Pulisci prima
    for (var sortCol in widget.config.initialSortBy) {
      _sortedColumnsState[sortCol.column] = sortCol.direction == SortDirection.asc ? DataGridSortDirection.ascending : DataGridSortDirection.descending;
    }
  }

  Future<void> _fetchData({bool isRefresh = false}) async {
    // ... (codice _fetchData come prima, usa _sortedColumnsState per la query.order) ...
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      if (isRefresh) {
        _data.clear();
        _dataSource.clearSelections();
      }
    });

    try {
      PostgrestTransformBuilder<PostgrestList> query = Supabase.instance.client.from(widget.config.dataSourceTable).select();

      _sortedColumnsState.forEach((columnName, direction) {
        if (direction != null) {
          query = query.order(columnName, ascending: direction == DataGridSortDirection.ascending);
        }
      });

      final response = await query;
      if (!mounted) return;

      _data = List<Map<String, dynamic>>.from(response);
      if (_data.isEmpty && _errorMessage.isEmpty) {
        _errorMessage = widget.config.emptyDataMessage;
        if (isRefresh) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.config.emptyDataMessage)));
          });
        }
      }
      // Ricostruisci le colonne solo se cambiano i nomi delle colonne (di solito solo al primo fetch o se la struttura dati cambia)
      // o se le colonne sono vuote.
      if (_columns.isEmpty || isRefresh || (_data.isNotEmpty && _columns.length - (widget.config.selectable ? 1 : 0) != _data.first.keys.length)) {
        _columns = _generateColumns(_data.isNotEmpty ? _data.first.keys.toList() : []);
      }
      _dataSource.updateDataGridSource(_data);
    } catch (e, s) {
      if (mounted) {
        appLogger.error('Errore fetch data per ${widget.config.dataSourceTable}', e, s);
        _errorMessage = 'Errore nel caricamento dati.';
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Chiamato quando l'utente clicca su un header di colonna per ordinare
  void _handleSortRequest(String columnName) {
    appLogger.debug("Sort request for column: $columnName");
    setState(() {
      _isLoading = true;
      DataGridSortDirection? newDirection;
      final currentDirection = _sortedColumnsState[columnName];

      if (currentDirection == null) {
        newDirection = DataGridSortDirection.ascending;
      } else if (currentDirection == DataGridSortDirection.ascending) {
        newDirection = DataGridSortDirection.descending;
      } else {
        // era descending
        newDirection = null; // Rimuovi sort (o torna ad ascendente se preferisci un ciclo senza "none")
      }

      _sortedColumnsState.clear(); // Supporta sort a colonna singola
      if (newDirection != null) {
        _sortedColumnsState[columnName] = newDirection;
      }
      // Le icone di sort sulla griglia saranno aggiornate dal DataGridSource
      // quando gli passeremo i nuovi dati ordinati.
      // Oppure, la griglia potrebbe aver bisogno di conoscere lo stato di sort tramite `sortedColumns`.
    });
    _fetchData();
  }

  List<GridColumn> _generateColumns(List<String> columnNames) {
    List<GridColumn> cols = [];
    if (widget.config.selectable) {
      cols.add(GridColumn(
          columnName: '_selector',
          allowSorting: false,
          width: 60,
          label: Checkbox(
            // Header checkbox
            value: _dataSource.isAllSelected(),
            onChanged: (bool? value) {
              _dataSource.selectAllRows(value ?? false);
              // setState(() {}); // Potrebbe essere necessario per aggiornare l'UI dell'header checkbox
            },
            tristate: true,
          )));
    }
    for (var name in columnNames) {
      if (name == '_selector') continue;
      // La label della colonna ora è un GestureDetector per il sorting
      cols.add(GridColumn(
        columnName: name,
        label: GestureDetector(
          onTap: () => _handleSortRequest(name), // Chiama il sort quando l'header viene cliccato
          child: Container(
            padding: const EdgeInsets.all(12.0),
            alignment: Alignment.centerLeft,
            child: Row(
              // Row per testo e icona di sort
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(_formatHeader(name), overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.bold))),
                if (_sortedColumnsState[name] != null) // Mostra icona solo se la colonna è ordinata
                  Icon(
                    _sortedColumnsState[name] == DataGridSortDirection.ascending ? Icons.arrow_upward : Icons.arrow_downward,
                    size: 16,
                  ),
              ],
            ),
          ),
        ),
        allowSorting: false, // Disabilitiamo il sorting interno della griglia, lo gestiamo noi
      ));
    }
    return cols;
  }

  String _formatHeader(String text) {
    /* ... come prima ... */
    if (text.isEmpty) return '';
    return text.replaceAll('_', ' ').split(' ').map((str) => str.isEmpty ? '' : '${str[0].toUpperCase()}${str.substring(1).toLowerCase()}').join(' ');
  }

  DataGridRow _buildRow(Map<String, dynamic> rowData, int rowIndex) {
    /* ... come prima ... */
    List<DataGridCell> cells = [];
    if (widget.config.selectable) {
      cells.add(DataGridCell<Map<String, dynamic>>(columnName: '_selector', value: rowData));
    }
    rowData.forEach((key, value) {
      if (key == '_selector') return;
      cells.add(DataGridCell<dynamic>(columnName: key, value: value));
    });
    return DataGridRow(cells: cells);
  }

  @override
  void toggleUIModePublic() => _toggleUIMode();
  @override
  UIMode get currentDisplayUIMode => _currentUIMode;
  @override
  void refreshData() => _fetchData(isRefresh: true);

  void _toggleUIMode() {
    /* ... come prima ... */
    if (widget.config.uiModes.length <= 1) return;
    setState(() {
      int currentIndex = widget.config.uiModes.indexOf(_currentUIMode);
      _currentUIMode = widget.config.uiModes[(currentIndex + 1) % widget.config.uiModes.length];
      widget.config.onViewModeChanged?.call(_currentUIMode);
      appLogger.info("DBGridWidget: UI Mode cambiata in: $_currentUIMode");
      if (_currentUIMode == UIMode.form && widget.config.formHookName != null) {
        final selected = _dataSource.getSelectedDataForForm();
        if (selected != null) {
          _handleFormHook(selected);
        } else {
          appLogger.info("DBGridWidget: Modo Form, ma nessun record singolo selezionato.");
        }
      }
    });
  }

  void _handleRowDoubleTap(DataGridCellDoubleTapDetails details) {
    /* ... come prima ... */
    if (widget.config.formHookName != null) {
      final rowIndex = details.rowColumnIndex.rowIndex;
      if (details.rowColumnIndex.rowIndex != 0 && rowIndex - 1 >= 0 && rowIndex - 1 < _data.length) {
        // -1 se l'header è contato
        final rowData = _data[rowIndex - 1]; // Adatta se l'indice include l'header
        _handleFormHook(rowData);
      } else {
        appLogger.warning("Double tap su riga non valida o header: $rowIndex");
      }
    }
  }

  void _handleFormHook(Map<String, dynamic> recordData) {
    /* ... come prima ... */
    appLogger.info("Trigger Form Hook: ${widget.config.formHookName} con dati: $recordData");
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Form Hook '${widget.config.formHookName}' chiamato per ID: ${recordData['id'] ?? 'N/D'}")));
  }

  @override
  Widget build(BuildContext context) {
    /* ... come prima ... */
    if (_isLoading && _data.isEmpty) return const Center(child: CircularProgressIndicator());
    if (_errorMessage.isNotEmpty && _data.isEmpty) return Center(child: Text(_errorMessage, style: const TextStyle(color: Colors.red)));
    if (!_isLoading && _data.isEmpty && _errorMessage.isEmpty) return Center(child: Text(widget.config.emptyDataMessage));

    switch (_currentUIMode) {
      case UIMode.grid:
        return _buildGridView();
      case UIMode.form:
        final formData = _dataSource.getSelectedDataForForm();
        if (formData != null && widget.config.formHookName != null) {
          return Center(
              child: Card(
                  margin: const EdgeInsets.all(16),
                  child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text("Vista Modulo per: ${formData['nome'] ?? 'Record'}", style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 10),
                        Text("ID: ${formData['id'] ?? 'N/D'}"),
                        const SizedBox(height: 20),
                        ElevatedButton(onPressed: _toggleUIMode, child: const Text("Torna alla Griglia"))
                      ]))));
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_currentUIMode == UIMode.form && mounted) _toggleUIMode();
        });
        return _buildGridView();
      case UIMode.map:
        return Center(
            child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [Text("Vista Mappa (Non Implementata per ${widget.config.dataSourceTable})"), const SizedBox(height: 20), ElevatedButton(onPressed: _toggleUIMode, child: const Text("Torna alla Griglia"))]));
    }
  }

  Widget _buildGridView() {
    /* ... come prima, ma onSortChanged rimosso da SfDataGrid ... */
    if (_columns.isEmpty && _data.isNotEmpty) _columns = _generateColumns(_data.first.keys.toList());
    if (_columns.isEmpty && !_isLoading) return Center(child: Text(widget.config.emptyDataMessage));
    if (_columns.isEmpty && _isLoading) return const Center(child: CircularProgressIndicator());
    if (_columns.isEmpty) return Center(child: Text("Impossibile generare colonne. ${widget.config.emptyDataMessage}"));

    return Column(children: [
      if (widget.config.uiModes.length > 1)
        Padding(
            padding: const EdgeInsets.all(8.0),
            child: SegmentedButton<UIMode>(
              segments: widget.config.uiModes.map((mode) {
                IconData icon;
                String label;
                switch (mode) {
                  case UIMode.grid:
                    icon = Icons.grid_view_rounded;
                    label = "Griglia";
                    break;
                  case UIMode.form:
                    icon = Icons.article_outlined;
                    label = "Modulo";
                    break;
                  case UIMode.map:
                    icon = Icons.map_outlined;
                    label = "Mappa";
                    break;
                }
                return ButtonSegment<UIMode>(value: mode, icon: Icon(icon), label: Text(label));
              }).toList(),
              selected: <UIMode>{_currentUIMode},
              onSelectionChanged: (Set<UIMode> newSelection) {
                if (newSelection.isNotEmpty) {
                  // Chiamiamo _toggleUIMode che gestisce il ciclo e la logica del form
                  _toggleUIMode();
                }
              },
            )),
      Expanded(
          child: SfDataGrid(
        key: ValueKey(widget.config.dataSourceTable + _sortedColumnsState.entries.map((e) => '${e.key}_${e.value}').join('_') + _currentPage.toString()),
        source: _dataSource,
        columns: _columns,
        controller: _dataGridController,
        allowSorting: false, // Il sorting è gestito manualmente cliccando gli header
        // onSortChanged: _handleSort, // RIMOSSO - ora gestito da GestureDetector in _generateColumns
        selectionMode: widget.config.selectable ? SelectionMode.multiple : SelectionMode.single,
        navigationMode: GridNavigationMode.cell,
        frozenColumnsCount: widget.config.fixedColumnsCount + (widget.config.selectable ? 1 : 0),
        gridLinesVisibility: GridLinesVisibility.both,
        headerGridLinesVisibility: GridLinesVisibility.both,
        columnWidthMode: ColumnWidthMode.fill,
        onCellDoubleTap: _handleRowDoubleTap,
        onCellTap: (DataGridCellTapDetails details) {
          final int rowIndex = details.rowColumnIndex.rowIndex;
          if (rowIndex > 0 && widget.config.selectable && details.column.columnName != '_selector') {
            final int dataIndex = rowIndex - 1;
            if (dataIndex >= 0 && dataIndex < _data.length) {
              // Aggiunto check dataIndex >= 0
              // La logica di selezione è nel DataSource, qui potremmo solo notificare se necessario
              // o lasciare che il DataSource gestisca il click sulla cella per selezionare la riga.
              // Syncfusion dovrebbe gestire la selezione della riga se selectionMode è single/multiple
              // e l'utente clicca su una cella (non solo sul checkbox).
              // Per coerenza con il checkbox, potremmo chiamare il nostro metodo.
              _dataSource.handleRowSelection(_data[dataIndex]);
            }
          }
        },
      ))
    ]);
  }
}

// --------------- DATASOURCE PER SfDataGrid ---------------
class _DBGridDataSource extends DataGridSource {
  List<Map<String, dynamic>> _gridDataInternal = [];
  // final DBGridConfig _config; // Non più usato direttamente qui
  final DataGridRow Function(Map<String, dynamic>, int) _buildRowCallback;
  List<Map<String, dynamic>> _selectedRowsDataMap = [];
  List<DataGridRow> _dataGridRows = [];
  final VoidCallback _onSelectionChanged; // Callback per notificare lo stato

  _DBGridDataSource({
    required List<Map<String, dynamic>> gridData,
    // required DBGridConfig config,
    required DataGridRow Function(Map<String, dynamic>, int) buildRowCallback,
    required List<Map<String, dynamic>> selectedRowsDataMap, // Passa la lista di selezione
    required VoidCallback onSelectionChanged,
  })  : _gridDataInternal = gridData,
        // _config = config,
        _buildRowCallback = buildRowCallback,
        _selectedRowsDataMap = selectedRowsDataMap, // Usa la lista passata
        _onSelectionChanged = onSelectionChanged {
    _buildDataGridRows();
  }

  // ... (buildRow, updateDataGridSource, isAllSelected, selectAllRows come prima) ...
  // ... (ma ora selectAllRows e handleRowSelection usano _onSelectionChanged)

  @override
  List<DataGridRow> get rows => _dataGridRows;

  void _buildDataGridRows() {
    _dataGridRows = _gridDataInternal.asMap().entries.map((entry) => _buildRowCallback(entry.value, entry.key)).toList();
  }

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    final int dataGridRowIndex = _dataGridRows.indexOf(row);
    Map<String, dynamic>? originalData;
    if (dataGridRowIndex >= 0 && dataGridRowIndex < _gridDataInternal.length) {
      originalData = _gridDataInternal[dataGridRowIndex];
    }

    return DataGridRowAdapter(
        cells: row.getCells().map<Widget>((dataGridCell) {
      if (dataGridCell.columnName == '_selector') {
        return Checkbox(
          value: originalData != null && _selectedRowsDataMap.any((item) => _areMapsEqual(item, originalData!)),
          onChanged: (bool? value) {
            if (originalData != null) handleRowSelection(originalData, isSelected: value);
          },
        );
      }
      return Container(alignment: Alignment.centerLeft, padding: const EdgeInsets.all(12.0), child: Text(dataGridCell.value?.toString() ?? '', overflow: TextOverflow.ellipsis));
    }).toList());
  }

  // Helper per confrontare mappe (semplice, basato su ID se presente)
  bool _areMapsEqual(Map<String, dynamic> map1, Map<String, dynamic> map2) {
    if (map1.containsKey('id') && map2.containsKey('id')) {
      return map1['id'] == map2['id'];
    }
    // Fallback a confronto di uguaglianza di riferimento (rischioso se le istanze sono diverse)
    return map1 == map2;
  }

  void updateDataGridSource(List<Map<String, dynamic>> newData) {
    _gridDataInternal = newData;
    _buildDataGridRows();
    // Mantieni le selezioni valide
    _selectedRowsDataMap.removeWhere((selectedItem) => !_gridDataInternal.any((newItem) => _areMapsEqual(selectedItem, newItem)));
    notifyListeners();
    _onSelectionChanged(); // Notifica anche per aggiornare l'header checkbox
  }

  bool isAllSelected() {
    if (_gridDataInternal.isEmpty) return false;
    if (_selectedRowsDataMap.length != _gridDataInternal.length) return false;
    // Verifica più approfondita se necessario
    for (var item in _gridDataInternal) {
      if (!_selectedRowsDataMap.any((selected) => _areMapsEqual(selected, item))) return false;
    }
    return true;
  }

  void selectAllRows(bool select) {
    _selectedRowsDataMap.clear();
    if (select) {
      _selectedRowsDataMap.addAll(List.from(_gridDataInternal)); // Copia per evitare modifiche impreviste
    }
    notifyListeners();
    _onSelectionChanged();
  }

  // Logica di selezione per singola riga
  void handleRowSelection(Map<String, dynamic> rowData, {bool? isSelected}) {
    final bool currentlySelected = _selectedRowsDataMap.any((item) => _areMapsEqual(item, rowData));
    final bool shouldBeSelected = isSelected ?? !currentlySelected; // Toggle se isSelected è null

    if (shouldBeSelected) {
      if (!currentlySelected) _selectedRowsDataMap.add(Map.from(rowData)); // Aggiungi una copia
    } else {
      _selectedRowsDataMap.removeWhere((item) => _areMapsEqual(item, rowData));
    }
    notifyListeners();
    _onSelectionChanged();
  }

  void clearSelections() {
    _selectedRowsDataMap.clear();
    notifyListeners();
    _onSelectionChanged();
  }

  Map<String, dynamic>? getSelectedDataForForm() => _selectedRowsDataMap.length == 1 ? _selectedRowsDataMap.first : null;
  List<Map<String, dynamic>> get selectedRowsData => List.unmodifiable(_selectedRowsDataMap); // Restituisci una copia non modificabile

  // Questo metodo viene chiamato dalla SfDataGrid quando allowSorting = true e l'utente
  // clicca su un header. Per il sorting server-side, questo metodo DEVE
  // comunicare allo _DBGridWidgetState di ricaricare i dati con i nuovi criteri di sort.
  // La griglia poi aggiornerà i suoi indicatori di sort in base alla proprietà `sortedColumns`
  // che DEVE essere passata a SfDataGrid.
  Future<void> handleSort() async {
    // Questa implementazione è per il sorting server-side.
    // Lo _DBGridWidgetState è responsabile del fetch.
    // Qui, `this.sortedColumns` (del DataGridSource) sarà aggiornato dalla griglia.
    // Dobbiamo prendere questi valori e passarli allo stato.

    // Poiché lo stato (_DBGridWidgetState) gestisce già _sortedColumnsState
    // e il fetch dei dati, e noi abbiamo reso le label degli header cliccabili
    // per chiamare _handleSortRequest nello stato, questo metodo handleSort()
    // nel DataSource potrebbe non essere il punto primario per il nostro sort server-side.
    // Lasciandolo vuoto, ci affidiamo al GestureDetector sull'header.
    // Se si vuole usare il meccanismo di sort interno della griglia per triggerare il fetch server-side:
    // 1. Rimuovere i GestureDetector dagli header.
    // 2. Impostare `allowSorting = true` su SfDataGrid e GridColumn.
    // 3. _DBGridWidgetState dovrebbe passare una callback a _DBGridDataSource.
    // 4. In questo metodo handleSort(), il DataSource chiamerebbe quella callback
    //    passando le `sortColumnDescriptions` (o simile) allo Stato,
    //    che poi aggiornerebbe `_sortedColumnsState` e farebbe `_fetchData()`.

    // Con l'approccio del GestureDetector sull'header, questo metodo può rimanere vuoto.
    appLogger.debug("_DBGridDataSource.handleSort() chiamato. sortedColumns: $sortedColumns");
    // Se volessimo usare questo:
    // final stateSortHandler = // ... ottenere riferimento a _handleSortRequest nello state ...
    // if (this.sortColumnDescriptions.isNotEmpty) {
    //    final sortInfo = this.sortColumnDescriptions.first; // Assumendo sort colonna singola
    //    stateSortHandler(sortInfo.columnName, sortInfo.sortDirection);
    // } else {
    //    stateSortHandler(null, null); // Nessun sort
    // }
  }
}

extension IterableExtensions<E> on Iterable<E> {
  /* ... come prima ... */
  E? firstWhereOrNull(bool Function(E) test) {
    for (var element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}
