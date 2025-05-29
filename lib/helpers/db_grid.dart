// lib/helpers/db_grid.dart
// ignore_for_file: prefer_final_fields, prefer_const_constructors_in_immutables, library_private_types_in_public_api

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Ensure this import is correct
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:una_social_app/helpers/logger_helper.dart'; // Assuming logger_helper.dart exists
import 'package:una_social_app/helpers/db_grid_form_view.dart'; // Import the new form view

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
  final String? formHookName; // Still potentially useful for other actions
  final String? mapHookName;
  final Function(UIMode newMode)? onViewModeChanged;
  final List<String> primaryKeyColumns; // For identifying PKs in the form view

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
    this.primaryKeyColumns = const ['id'], // Default to 'id'
  }) : assert(pageLength > 0, 'pageLength must be greater than 0');
}

// --------------- INTERFACE FOR SCREENS PROVIDING DBGRID ACCESS ---------------
abstract class DBGridProvider {
  DBGridConfig get dbGridConfig;
  GlobalKey<State<DBGridWidget>> get dbGridWidgetKey;
}

// --------------- INTERFACCIA PUBBLICA DI CONTROLLO ---------------
abstract class DBGridControl {
  void toggleUIModePublic();
  UIMode get currentDisplayUIMode;
  void refreshData();
  // Form navigation methods
  bool canGoToPreviousRecordInForm();
  bool canGoToNextRecordInForm();
  void goToPreviousRecordInForm();
  void goToNextRecordInForm();
  Map<String, dynamic>? getCurrentRecordForForm();
  List<String> getPrimaryKeyColumns();
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
  List<Map<String, dynamic>> _data = []; // Data for the current grid page
  List<GridColumn> _columns = [];
  bool _isLoading = true;
  String _errorMessage = '';

  int _currentPage = 0;
  int _totalRecords = 0;
  int get _totalPages => _totalRecords > 0 && widget.config.pageLength > 0 ? (_totalRecords / widget.config.pageLength).ceil() : 0;

  DataGridController _dataGridController = DataGridController();
  Map<String, DataGridSortDirection?> _sortedColumnsState = {};
  late UIMode _currentUIMode;
  int _currentFormRecordIndex = -1; // Index of the current record being viewed in form mode within _data

  @override
  void initState() {
    super.initState();
    _currentUIMode = widget.config.uiModes.isNotEmpty ? widget.config.uiModes.first : UIMode.grid;
    _initializeSortedColumns();
    _dataSource = _DBGridDataSource(
      gridData: _data,
      buildRowCallback: _buildRow,
      selectedRowsDataMap: [],
      onSelectionChanged: () {
        if (mounted) setState(() {});
      },
      // Pass the areMapsEqual method for the datasource to use internally
      areMapsEqualCallback: _areMapsEqual,
    );
    _fetchData(isRefresh: true);
  }

  // Centralized map comparison logic
  bool _areMapsEqual(Map<String, dynamic> map1, Map<String, dynamic> map2) {
    if (map1.containsKey('id') && map2.containsKey('id')) {
      return map1['id'] == map2['id'];
    }
    // Fallback for maps without 'id' or for more robust comparison if needed
    if (map1.length != map2.length) return false;
    for (var key in map1.keys) {
      if (!map2.containsKey(key) || map1[key] != map2[key]) {
        return false;
      }
    }
    return true;
  }

  Future<void> _fetchData({bool isRefresh = false}) async {
    if (!mounted) return;

    if (isRefresh) {
      _currentPage = 0;
      _currentFormRecordIndex = -1; // Reset form index on full refresh
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
      if (isRefresh) {
        _dataSource.clearSelections();
      }
    });

    try {
      final fromRecord = _currentPage * widget.config.pageLength;
      final limit = widget.config.pageLength;
      final offset = fromRecord;

      var query = Supabase.instance.client.from(widget.config.dataSourceTable).select('*');
      var rangedQuery = query.range(offset, offset + limit - 1);

      _sortedColumnsState.forEach((columnName, direction) {
        if (direction != null) {
          rangedQuery = rangedQuery.order(
            columnName,
            ascending: direction == DataGridSortDirection.ascending,
          );
        }
      });

      var builderForCount = rangedQuery.count(CountOption.exact);
      final PostgrestResponse<PostgrestList> response = await builderForCount;

      if (!mounted) return;

      _data = List<Map<String, dynamic>>.from(response.data);
      _totalRecords = response.count;

      if (_data.isEmpty && _totalRecords == 0 && _errorMessage.isEmpty) {
        _errorMessage = widget.config.emptyDataMessage;
        if (isRefresh) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(widget.config.emptyDataMessage)),
              );
            }
          });
        }
      }

      bool needsColumnRegeneration = _columns.isEmpty || isRefresh;
      if (!needsColumnRegeneration && _data.isNotEmpty) {
        int currentDataColumns = _data.first.keys.length;
        int displayedColumns = _columns.length - (widget.config.selectable ? 1 : 0);
        if (currentDataColumns != displayedColumns) {
          needsColumnRegeneration = true;
        }
      }

      if (needsColumnRegeneration) {
        List<String> columnKeys = [];
        if (_data.isNotEmpty) {
          columnKeys = _data.first.keys.toList();
        } else if (_columns.isNotEmpty && _totalRecords > 0) {
          columnKeys = _columns.where((c) => c.columnName != '_selector').map((c) => c.columnName).toList();
        }
        _columns = _generateColumns(columnKeys);
      }
      _dataSource.updateDataGridSource(_data); // This will also update its internal copy of _data

      // If form index was valid, try to maintain it if the record still exists
      if (_currentFormRecordIndex != -1 && _currentFormRecordIndex < (response.data as List).length) {
        // Potentially re-validate if the data changed significantly
      } else if (_currentUIMode == UIMode.form && _data.isNotEmpty) {
        _currentFormRecordIndex = 0; // Default to first record if in form mode and data loaded
        _dataSource.clearSelections();
        _dataSource.handleRowSelection(_data[_currentFormRecordIndex], isSelected: true);
      } else {
        _currentFormRecordIndex = -1;
      }
    } catch (e, s) {
      if (mounted) {
        appLogger.error('Errore fetch data per ${widget.config.dataSourceTable}: $e', e, s);
        _errorMessage = 'Errore nel caricamento dati.';
        _totalRecords = 0;
        _data.clear();
        _currentFormRecordIndex = -1;
        if (isRefresh || _columns.isEmpty) _columns.clear();
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _initializeSortedColumns() {
    _sortedColumnsState.clear();
    for (var sortCol in widget.config.initialSortBy) {
      _sortedColumnsState[sortCol.column] = sortCol.direction == SortDirection.asc ? DataGridSortDirection.ascending : DataGridSortDirection.descending;
    }
  }

  List<GridColumn> _generateColumns(List<String> columnNames) {
    List<GridColumn> cols = [];
    if (widget.config.selectable) {
      cols.add(GridColumn(
          columnName: '_selector',
          allowSorting: false,
          width: 60,
          label: Checkbox(
            value: _dataSource.isAllSelected(),
            onChanged: (bool? value) {
              _dataSource.selectAllRows(value ?? false);
            },
            tristate: true,
          )));
    }
    for (var name in columnNames) {
      if (name == '_selector') continue;
      cols.add(GridColumn(
        columnName: name,
        label: GestureDetector(
          onTap: () => _handleSortRequest(name),
          child: Container(
            padding: const EdgeInsets.all(12.0),
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(_formatHeader(name), overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.bold))),
                if (_sortedColumnsState[name] != null)
                  Icon(
                    _sortedColumnsState[name] == DataGridSortDirection.ascending ? Icons.arrow_upward : Icons.arrow_downward,
                    size: 16,
                  ),
              ],
            ),
          ),
        ),
        allowSorting: false,
      ));
    }
    return cols;
  }

  void _handleSortRequest(String columnName) {
    appLogger.debug("Sort request for column: $columnName");
    setState(() {
      DataGridSortDirection? newDirection;
      final currentDirection = _sortedColumnsState[columnName];

      if (currentDirection == null) {
        newDirection = DataGridSortDirection.ascending;
      } else if (currentDirection == DataGridSortDirection.ascending) {
        newDirection = DataGridSortDirection.descending;
      } else {
        newDirection = null;
      }
      _sortedColumnsState.clear();
      if (newDirection != null) {
        _sortedColumnsState[columnName] = newDirection;
      }
    });
    _fetchData(isRefresh: true);
  }

  String _formatHeader(String text) {
    if (text.isEmpty) return '';
    return text.replaceAll('_', ' ').split(' ').map((str) => str.isEmpty ? '' : '${str[0].toUpperCase()}${str.substring(1).toLowerCase()}').join(' ');
  }

  DataGridRow _buildRow(Map<String, dynamic> rowData, int rowIndex) {
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

  void _toggleUIMode({Map<String, dynamic>? initialRecordForForm}) {
    // Allow forcing to form mode if initialRecordForForm is provided and form mode is available
    if (initialRecordForForm != null && widget.config.uiModes.contains(UIMode.form)) {
      setState(() {
        _currentUIMode = UIMode.form;
        _setSelectedRecordForForm(initialRecordForForm);
        widget.config.onViewModeChanged?.call(_currentUIMode);
        appLogger.info("DBGridWidget: UI Mode forced to Form with initial record.");
      });
      return;
    }

    if (widget.config.uiModes.length <= 1) return;

    setState(() {
      int currentIndex = widget.config.uiModes.indexOf(_currentUIMode);
      _currentUIMode = widget.config.uiModes[(currentIndex + 1) % widget.config.uiModes.length];
      widget.config.onViewModeChanged?.call(_currentUIMode);
      appLogger.info("DBGridWidget: UI Mode toggled to: $_currentUIMode");

      if (_currentUIMode == UIMode.form) {
        final selectedRecord = _dataSource.getSelectedDataForForm(); // Get last known selection
        if (selectedRecord != null) {
          _setSelectedRecordForForm(selectedRecord);
        } else if (_data.isNotEmpty) {
          _setSelectedRecordForForm(_data.first); // Default to first record on current page
        } else {
          // No data to show in form, might revert in build method
          _currentFormRecordIndex = -1;
          appLogger.info("DBGridWidget: Form Mode, but no record selected and no data available.");
        }
      } else {
        _currentFormRecordIndex = -1; // Reset when leaving form mode
      }
    });
  }

  void _handleRowDoubleTap(DataGridCellDoubleTapDetails details) {
    final rowIndex = details.rowColumnIndex.rowIndex;
    if (rowIndex > 0) {
      final dataIndex = rowIndex - 1;
      if (dataIndex >= 0 && dataIndex < _data.length) {
        final rowData = _data[dataIndex];
        if (widget.config.uiModes.contains(UIMode.form)) {
          _toggleUIMode(initialRecordForForm: rowData); // Switch to form mode with this record
        } else if (widget.config.formHookName != null) {
          // Fallback to old hook behavior if form mode is not an available UI Mode
          _handleFormHook(rowData);
        }
      } else {
        appLogger.warning("Double tap on invalid data row index: $dataIndex, _data.length: ${_data.length}");
      }
    } else {
      appLogger.warning("Double tap on header ignored: rowIndex $rowIndex");
    }
  }

  void _handleFormHook(Map<String, dynamic> recordData) {
    appLogger.info("Trigger Form Hook: ${widget.config.formHookName} con dati: $recordData");
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Form Hook '${widget.config.formHookName}' chiamato per ID: ${recordData['id'] ?? 'N/D'}")));
    }
  }

  void _setSelectedRecordForForm(Map<String, dynamic> recordData) {
    _currentFormRecordIndex = _data.indexWhere((d) => _areMapsEqual(d, recordData));
    _dataSource.clearSelections();
    _dataSource.handleRowSelection(recordData, isSelected: true);
    if (mounted) setState(() {});
  }

  @override
  UIMode get currentDisplayUIMode => _currentUIMode;
  @override
  void refreshData() => _fetchData(isRefresh: true);

  @override
  Map<String, dynamic>? getCurrentRecordForForm() {
    if (_currentFormRecordIndex >= 0 && _currentFormRecordIndex < _data.length) {
      return _data[_currentFormRecordIndex];
    }
    return _dataSource.getSelectedDataForForm(); // Fallback
  }

  @override
  List<String> getPrimaryKeyColumns() {
    return widget.config.primaryKeyColumns;
  }

  @override
  bool canGoToPreviousRecordInForm() {
    logInfo('canGoToPreviousRecordInForm: $_currentFormRecordIndex');
    return _currentFormRecordIndex > 0;
  }

  @override
  bool canGoToNextRecordInForm() {
    logInfo('canGoToNextRecordInForm: $_data.length - $_currentFormRecordIndex');
    return _currentFormRecordIndex < _data.length - 1;
  }

  @override
  void goToPreviousRecordInForm() {
    if (canGoToPreviousRecordInForm()) {
      setState(() {
        _currentFormRecordIndex--;
        _setSelectedRecordForForm(_data[_currentFormRecordIndex]);
      });
    }
  }

  @override
  void goToNextRecordInForm() {
    if (canGoToNextRecordInForm()) {
      setState(() {
        _currentFormRecordIndex++;
        _setSelectedRecordForForm(_data[_currentFormRecordIndex]);
      });
    }
  }

  void _goToPage(int pageIndex) {
    if (pageIndex >= 0 && (_totalPages == 0 || pageIndex < _totalPages) && pageIndex != _currentPage) {
      setState(() {
        _currentPage = pageIndex;
      });
      _fetchData();
    } else if (pageIndex == 0 && _currentPage == 0 && _totalPages == 0 && _totalRecords == 0) {
      setState(() {
        _currentPage = pageIndex;
      });
      _fetchData();
    }
  }

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _goToPage(_currentPage + 1);
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _goToPage(_currentPage - 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _totalRecords == 0 && _data.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage.isNotEmpty && _totalRecords == 0 && _data.isEmpty) {
      return Center(child: Text(_errorMessage, style: const TextStyle(color: Colors.red)));
    }
    if (!_isLoading && _totalRecords == 0 && _errorMessage.isEmpty) {
      return Center(child: Text(widget.config.emptyDataMessage));
    }

    switch (_currentUIMode) {
      case UIMode.grid:
        return _buildGridView();
      case UIMode.form:
        final Map<String, dynamic>? formData = getCurrentRecordForForm();
        if (formData != null) {
          return DBGridFormView(
            formData: formData,
            dbGridControl: this,
            primaryKeyColumns: getPrimaryKeyColumns(),
          );
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _currentUIMode == UIMode.form) {
            appLogger.warning("DBGridWidget: In Form Mode ma nessun record valido. Ritorno alla griglia.");
            setState(() {
              _currentUIMode = widget.config.uiModes.firstWhereOrNull((m) => m == UIMode.grid) ?? widget.config.uiModes.first;
              widget.config.onViewModeChanged?.call(_currentUIMode);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Nessun record selezionato per il modulo. Visualizzazione Griglia.")));
              }
            });
          }
        });
        return _isLoading ? const Center(child: CircularProgressIndicator()) : _buildGridView();
      case UIMode.map:
        return Center(
            child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [Text("Vista Mappa (Non Implementata per ${widget.config.dataSourceTable})"), const SizedBox(height: 20), ElevatedButton(onPressed: _toggleUIMode, child: const Text("Torna alla Griglia"))]));
    }
  }

  Widget _buildPaginationControls() {
    if (_totalPages == 0 && _totalRecords == 0) {
      if (_isLoading) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: const [Text("Caricamento...", style: TextStyle(fontSize: 12))]),
        );
      }
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(icon: const Icon(Icons.first_page), onPressed: _isLoading || _currentPage == 0 ? null : () => _goToPage(0), tooltip: "Prima pagina"),
          IconButton(icon: const Icon(Icons.navigate_before), onPressed: _isLoading || _currentPage == 0 ? null : _previousPage, tooltip: "Pagina precedente"),
          Expanded(child: Text('Pag. ${_currentPage + 1} di $_totalPages ($_totalRecords record)', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12))),
          IconButton(icon: const Icon(Icons.navigate_next), onPressed: _isLoading || _currentPage >= _totalPages - 1 ? null : _nextPage, tooltip: "Pagina successiva"),
          IconButton(icon: const Icon(Icons.last_page), onPressed: _isLoading || _currentPage >= _totalPages - 1 || _totalPages == 0 ? null : () => _goToPage(_totalPages - 1), tooltip: "Ultima pagina"),
        ],
      ),
    );
  }

  Widget _buildGridView() {
    if (_columns.isEmpty && _totalRecords == 0) {
      if (_isLoading) return const Center(child: CircularProgressIndicator());
      return Center(child: Text(_errorMessage.isNotEmpty ? _errorMessage : widget.config.emptyDataMessage));
    }
    if (_columns.isEmpty && (_isLoading || _totalRecords > 0)) {
      return const Center(child: CircularProgressIndicator());
    }
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
                if (newSelection.isNotEmpty && newSelection.first != _currentUIMode) {
                  _toggleUIMode(initialRecordForForm: newSelection.first == UIMode.form ? _dataSource.getSelectedDataForForm() ?? (_data.isNotEmpty ? _data.first : null) : null);
                }
              },
            )),
      Expanded(
          child: SfDataGrid(
        key: ValueKey(widget.config.dataSourceTable + _sortedColumnsState.entries.map((e) => '${e.key}_${e.value?.toString()}').join('_') + _currentPage.toString() + _totalRecords.toString()),
        source: _dataSource,
        columns: _columns,
        controller: _dataGridController,
        allowSorting: false,
        selectionMode: widget.config.selectable ? SelectionMode.multiple : SelectionMode.single,
        navigationMode: GridNavigationMode.cell,
        frozenColumnsCount: widget.config.fixedColumnsCount + (widget.config.selectable ? 1 : 0),
        gridLinesVisibility: GridLinesVisibility.both,
        headerGridLinesVisibility: GridLinesVisibility.both,
        columnWidthMode: ColumnWidthMode.auto,
        onCellDoubleTap: _handleRowDoubleTap,
        onCellTap: (DataGridCellTapDetails details) {
          final int rowIndex = details.rowColumnIndex.rowIndex;
          if (rowIndex > 0 && widget.config.selectable && details.column.columnName != '_selector') {
            final int dataIndex = rowIndex - 1;
            if (dataIndex >= 0 && dataIndex < _data.length) {
              _dataSource.handleRowSelection(_data[dataIndex]);
            }
          }
        },
      )),
      _buildPaginationControls(),
    ]);
  }
}

// --------------- DATASOURCE PER SfDataGrid ---------------
class _DBGridDataSource extends DataGridSource {
  List<Map<String, dynamic>> _gridDataInternal = [];
  final DataGridRow Function(Map<String, dynamic>, int) _buildRowCallback;
  List<Map<String, dynamic>> _selectedRowsDataMap = [];
  List<DataGridRow> _dataGridRows = [];
  final VoidCallback _onSelectionChanged;
  final bool Function(Map<String, dynamic> map1, Map<String, dynamic> map2) _areMapsEqualCallback;

  _DBGridDataSource({
    required List<Map<String, dynamic>> gridData,
    required DataGridRow Function(Map<String, dynamic>, int) buildRowCallback,
    required List<Map<String, dynamic>> selectedRowsDataMap,
    required VoidCallback onSelectionChanged,
    required bool Function(Map<String, dynamic> map1, Map<String, dynamic> map2) areMapsEqualCallback,
  })  : _gridDataInternal = gridData,
        _buildRowCallback = buildRowCallback,
        _selectedRowsDataMap = selectedRowsDataMap,
        _onSelectionChanged = onSelectionChanged,
        _areMapsEqualCallback = areMapsEqualCallback {
    _buildDataGridRows();
  }

  @override
  List<DataGridRow> get rows => _dataGridRows;

  void _buildDataGridRows() {
    _dataGridRows = _gridDataInternal.asMap().entries.map((entry) => _buildRowCallback(entry.value, entry.key)).toList();
  }

  bool areMapsEqual(Map<String, dynamic> map1, Map<String, dynamic> map2) {
    return _areMapsEqualCallback(map1, map2);
  }

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    final int dataGridRowIndex = _dataGridRows.indexOf(row);
    Map<String, dynamic>? originalData;
    if (dataGridRowIndex >= 0 && dataGridRowIndex < _gridDataInternal.length) {
      originalData = _gridDataInternal[dataGridRowIndex];
    }

    final bool isSelected = originalData != null && _selectedRowsDataMap.any((item) => _areMapsEqualCallback(item, originalData!));

    Color? rowColor;
    if (NavigationService.navigatorKey.currentContext != null) {
      // Check context
      final currentContext = NavigationService.navigatorKey.currentContext!;
      if (isSelected) {
        rowColor = Theme.of(currentContext).highlightColor.withAlpha((0.3 * 255).round());
      }
    }

    return DataGridRowAdapter(
        color: rowColor,
        cells: row.getCells().map<Widget>((dataGridCell) {
          if (dataGridCell.columnName == '_selector') {
            return Checkbox(
              value: isSelected,
              onChanged: (bool? value) {
                if (originalData != null) handleRowSelection(originalData, isSelected: value);
              },
            );
          }
          return Container(alignment: Alignment.centerLeft, padding: const EdgeInsets.all(12.0), child: Text(dataGridCell.value?.toString() ?? '', overflow: TextOverflow.ellipsis));
        }).toList());
  }

  void updateDataGridSource(List<Map<String, dynamic>> newData) {
    _gridDataInternal = newData;
    _buildDataGridRows();
    _selectedRowsDataMap.removeWhere((selectedItem) => !_gridDataInternal.any((newItem) => _areMapsEqualCallback(selectedItem, newItem)));
    notifyListeners();
    _onSelectionChanged();
  }

  bool isAllSelected() {
    if (_gridDataInternal.isEmpty) return false;
    for (var item in _gridDataInternal) {
      if (!_selectedRowsDataMap.any((selected) => _areMapsEqualCallback(selected, item))) return false;
    }
    return _gridDataInternal.isNotEmpty;
  }

  void selectAllRows(bool select) {
    if (select) {
      for (var item in _gridDataInternal) {
        if (!_selectedRowsDataMap.any((selected) => _areMapsEqualCallback(selected, item))) {
          _selectedRowsDataMap.add(Map.from(item));
        }
      }
    } else {
      _selectedRowsDataMap.removeWhere((selectedItem) => _gridDataInternal.any((itemOnPage) => _areMapsEqualCallback(selectedItem, itemOnPage)));
    }
    notifyListeners();
    _onSelectionChanged();
  }

  void handleRowSelection(Map<String, dynamic> rowData, {bool? isSelected}) {
    final bool currentlySelected = _selectedRowsDataMap.any((item) => _areMapsEqualCallback(item, rowData));
    final bool shouldBeSelected = isSelected ?? !currentlySelected;

    if (shouldBeSelected) {
      if (!currentlySelected) _selectedRowsDataMap.add(Map.from(rowData));
    } else {
      _selectedRowsDataMap.removeWhere((item) => _areMapsEqualCallback(item, rowData));
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
  List<Map<String, dynamic>> get selectedRowsData => List.unmodifiable(_selectedRowsDataMap);

  Future<void> handleSort() async {
    appLogger.debug("_DBGridDataSource.handleSort() called. This is typically for client-side sorting via SfDataGrid's internal mechanism.");
  }
}

class NavigationService {
  // Ensure this is correctly set up in your app
  static GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
}

extension IterableExtensions<E> on Iterable<E> {
  E? firstWhereOrNull(bool Function(E) test) {
    for (var element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}
