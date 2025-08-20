// lib/helpers/db_grid.dart
// ignore_for_file: prefer_final_fields, prefer_const_constructors_in_immutables, library_private_types_in_public_api, depend_on_referenced_packages, avoid_print

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:una_social/helpers/logger_helper.dart';
import 'package:una_social/helpers/db_grid_form_view.dart';
import 'package:collection/collection.dart';
import 'dart:convert';
import 'dart:async';

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
  final String? rpcFunctionName;
  final Map<String, dynamic>? rpcFunctionParams;
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
  final List<String> primaryKeyColumns;
  final List<String> excludeColumns; // Columns to exclude from grid display

  DBGridConfig({
    required this.dataSourceTable,
    this.rpcFunctionName,
    this.rpcFunctionParams,
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
    this.primaryKeyColumns = const ['id'],
    this.excludeColumns = const [], // Default to empty list for backward compatibility
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
  List<Map<String, dynamic>> _data = [];
  List<GridColumn> _columns = [];
  bool _isLoading = true;
  String _errorMessage = '';

  int _currentPage = 0;
  int _totalRecords = 0;
  int get _totalPages => _totalRecords > 0 && widget.config.pageLength > 0 ? (_totalRecords / widget.config.pageLength).ceil() : 0;

  DataGridController _dataGridController = DataGridController();
  Map<String, DataGridSortDirection?> _sortedColumnsState = {};
  late UIMode _currentUIMode;
  int _currentFormRecordIndex = -1;

  // NEW: Filtering state
  Map<String, String> _filterValues = {}; // Map: column name -> filter text
  Timer? _filterDebounce; // For filter debouncing

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
      areMapsEqualCallback: _areMapsEqual,
      // NEW: Callback for server-side sorting requests from DataGridSource
      onSortRequest: (sortColumns) {
        if (!mounted) return;
        setState(() {
          _sortedColumnsState.clear();
          if (sortColumns.isNotEmpty) {
            final sortCol = sortColumns.first;
            _sortedColumnsState[sortCol.columnName] = sortCol.sortDirection;
          }
        });
        _fetchData(isRefresh: true);
      },
    );
    _fetchData(isRefresh: true);
  }

  @override
  void dispose() {
    _filterDebounce?.cancel(); // Cancel debounce timer on dispose
    super.dispose();
  }

  // Centralized map comparison logic
  bool _areMapsEqual(Map<String, dynamic> map1, Map<String, dynamic> map2) {
    // Attempt to use primary keys for comparison first
    if (widget.config.primaryKeyColumns.isNotEmpty) {
      bool allPkMatch = true;
      for (String pkCol in widget.config.primaryKeyColumns) {
        if (!map1.containsKey(pkCol) || !map2.containsKey(pkCol) || map1[pkCol] != map2[pkCol]) {
          allPkMatch = false;
          break;
        }
      }
      if (allPkMatch) return true; // If all primary keys match, consider them equal
    }

    // Fallback to full map comparison if no primary keys or PKs don't match
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
      final limit = widget.config.pageLength;
      final offset = _currentPage * limit;

      if (widget.config.rpcFunctionName != null) {
        appLogger.info('Calling RPC: ${widget.config.rpcFunctionName}');

        // Prepare RPC parameters for pagination, sorting, and filtering
        final Map<String, dynamic> rpcParams = Map.from(widget.config.rpcFunctionParams ?? {});
        rpcParams['p_limit'] = limit;
        rpcParams['p_offset'] = offset;

        // Add sorting parameters
        final sortedColumn = _sortedColumnsState.entries.firstOrNull;
        if (sortedColumn != null) {
          rpcParams['p_order_by'] = sortedColumn.key;
          rpcParams['p_order_direction'] = sortedColumn.value == DataGridSortDirection.ascending ? 'asc' : 'desc';
        } else {
          // Default sorting if not specified by user
          rpcParams['p_order_by'] = widget.config.initialSortBy.isNotEmpty ? widget.config.initialSortBy.first.column : 'cognome'; // Default to 'cognome'
          rpcParams['p_order_direction'] = widget.config.initialSortBy.isNotEmpty && widget.config.initialSortBy.first.direction == SortDirection.desc ? 'desc' : 'asc';
        }

        // Add filtering parameters (supports only one active filter for simplicity)
        // Find the first column with a non-empty filter value
        final activeFilter = _filterValues.entries.firstWhereOrNull((e) => e.value.isNotEmpty);
        if (activeFilter != null) {
          rpcParams['p_filter_column'] = activeFilter.key;
          rpcParams['p_filter_value'] = activeFilter.value;
        } else {
          rpcParams['p_filter_column'] = null;
          rpcParams['p_filter_value'] = null;
        }

        appLogger.info('RPC final params: $rpcParams');

        final dynamic rpcResult = await Supabase.instance.client.rpc(
          widget.config.rpcFunctionName!,
          params: rpcParams,
        );

        appLogger.info('RPC raw result: $rpcResult');

        // Handle JSONB return type { "data": [...], "count": N }
        if (rpcResult is Map<String, dynamic> && rpcResult.containsKey('data') && rpcResult.containsKey('count')) {
          _data = List<Map<String, dynamic>>.from(rpcResult['data'] ?? []);
          _totalRecords = rpcResult['count'] as int;
        } else if (rpcResult is List) {
          _data = List<Map<String, dynamic>>.from(rpcResult);
          _totalRecords = _data.length; // Fallback: assume all data returned if not JSONB
          appLogger.warning('RPC did not return expected JSONB with data and count. Assuming all data returned.');
        } else if (rpcResult != null) {
          _data = [Map<String, dynamic>.from(rpcResult)];
          _totalRecords = 1;
        } else {
          _data = [];
          _totalRecords = 0;
        }
      } else {
        // --- Standard table selection (existing logic) ---
        final PostgrestResponse<dynamic> response = await Supabase.instance.client.from(widget.config.dataSourceTable).select().range(offset, offset + limit - 1).count(CountOption.exact);

        _data = List<Map<String, dynamic>>.from(response.data ?? []);
        _totalRecords = response.count ?? 0;
      }

      if (!mounted) return;

      // Handle decoding of JSONB strings if they come as strings from Supabase
      _data = _data.map((row) {
        final Map<String, dynamic> newRow = Map.from(row);
        // Helper function to decode JSON strings to List<dynamic>
        List<dynamic>? decodeJsonbList(dynamic value, String fieldName) {
          if (value is String) {
            try {
              final decoded = jsonDecode(value);
              if (decoded is List) {
                return List<dynamic>.from(decoded);
              }
            } catch (e) {
              appLogger.error('Error decoding $fieldName string in DBGridWidget: $e');
            }
          } else if (value is List) {
            return List<dynamic>.from(value);
          }
          return null;
        }

        newRow['telefoni'] = decodeJsonbList(newRow['telefoni'], 'telefoni');
        newRow['ruoli'] = decodeJsonbList(newRow['ruoli'], 'ruoli');
        newRow['altre_emails'] = decodeJsonbList(newRow['altre_emails'], 'altre_emails');

        return newRow;
      }).toList();

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

      // Handle column regeneration (includes exclusion)
      bool needsColumnRegeneration = _columns.isEmpty || isRefresh;
      if (!needsColumnRegeneration && _data.isNotEmpty) {
        // Get keys that are not in excludeColumns
        final currentDataKeys = _data.first.keys.where((key) => !widget.config.excludeColumns.contains(key)).toList();
        int currentDataColumns = currentDataKeys.length;
        int displayedColumns = _columns.length - (widget.config.selectable ? 1 : 0);
        if (currentDataColumns != displayedColumns) {
          needsColumnRegeneration = true;
        }
      }

      if (needsColumnRegeneration && _data.isNotEmpty) {
        // Pass only non-excluded column names to _generateColumns
        _columns = _generateColumns(_data.first.keys.where((key) => !widget.config.excludeColumns.contains(key)).toList());
      } else if (needsColumnRegeneration && _data.isEmpty) {
        _columns = [];
      }

      _dataSource.updateDataGridSource(_data);

      // Logic for form mode
      if (_currentUIMode == UIMode.form && _data.isNotEmpty) {
        final Map<String, dynamic>? previouslySelected = _dataSource.getSelectedDataForForm();
        if (previouslySelected != null) {
          _currentFormRecordIndex = _data.indexWhere((d) => _areMapsEqual(d, previouslySelected));
        } else {
          _currentFormRecordIndex = 0;
        }
        if (_currentFormRecordIndex != -1) {
          _dataSource.clearSelections();
          _dataSource.handleRowSelection(_data[_currentFormRecordIndex], isSelected: true);
        } else {
          if (_data.isNotEmpty) {
            _currentFormRecordIndex = 0;
            _dataSource.clearSelections();
            _dataSource.handleRowSelection(_data[_currentFormRecordIndex], isSelected: true);
          } else {
            _currentFormRecordIndex = -1;
          }
        }
      } else {
        _currentFormRecordIndex = -1;
      }
    } catch (e, s) {
      if (mounted) {
        appLogger.error('Error fetching data for ${widget.config.dataSourceTable}: $e', e, s);
        _errorMessage = 'Error loading data: $e';
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

    // Handle 'photo_url' column specifically
    if (columnNames.contains('photo_url') && !widget.config.excludeColumns.contains('photo_url')) {
      cols.add(GridColumn(
        columnName: 'photo_url', // Use original column name for internal logic
        label: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0), // Adjusted vertical padding
          alignment: Alignment.centerLeft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Foto', overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.bold)), // Display 'Foto' as header
              if (widget.config.rpcFunctionName != null)
                SizedBox(
                  height: 24,
                  child: TextField(
                    controller: TextEditingController(text: _filterValues['photo_url']),
                    decoration: InputDecoration(
                      hintText: 'Filter',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4.0),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Theme.of(context).cardColor,
                    ),
                    onChanged: (value) {
                      _filterValues['photo_url'] = value;
                      _debounceFilter();
                    },
                    onSubmitted: (value) {
                      _fetchData(isRefresh: true);
                    },
                  ),
                ),
            ],
          ),
        ),
        allowSorting: true,
        width: 80, // Set a reasonable width for the photo column
      ));
      // Remove 'photo_url' from the list to avoid duplicate processing
      columnNames.remove('photo_url');
    }

    // Process remaining columns
    for (var name in columnNames) {
      if (widget.config.excludeColumns.contains(name)) {
        continue; // Ensure excluded columns are skipped
      }
      cols.add(GridColumn(
        columnName: name,
        label: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0), // Adjusted vertical padding
          alignment: Alignment.centerLeft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_formatHeader(name), overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.bold)),
              if (widget.config.rpcFunctionName != null)
                SizedBox(
                  height: 24,
                  child: TextField(
                    controller: TextEditingController(text: _filterValues[name]),
                    decoration: InputDecoration(
                      hintText: 'Filter',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4.0),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Theme.of(context).cardColor,
                    ),
                    onChanged: (value) {
                      _filterValues[name] = value;
                      _debounceFilter();
                    },
                    onSubmitted: (value) {
                      _fetchData(isRefresh: true);
                    },
                  ),
                ),
            ],
          ),
        ),
        allowSorting: true,
      ));
    }
    return cols;
  }

  void _debounceFilter() {
    if (_filterDebounce != null && _filterDebounce!.isActive) {
      _filterDebounce!.cancel();
    }
    _filterDebounce = Timer(const Duration(milliseconds: 500), () {
      _fetchData(isRefresh: true);
    });
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
      // Exclude specified columns from rowData
      if (widget.config.excludeColumns.contains(key) || key == '_selector') {
        return;
      }

      if (key == 'photo_url') {
        final String? photoUrl = value?.toString();
        Widget imageWidget;
        if (photoUrl != null && Uri.tryParse(photoUrl)?.hasAbsolutePath == true) {
          imageWidget = Image.network(
            photoUrl,
            fit: BoxFit.cover,
            width: 40, // Adjust size as needed
            height: 40,
            errorBuilder: (context, error, stackTrace) => const Icon(Icons.person, size: 40), // Placeholder on error
          );
        } else {
          imageWidget = const Icon(Icons.person, size: 40); // Anonymous user icon
        }
        cells.add(DataGridCell<Widget>(columnName: key, value: imageWidget));
      }
      // Special handling for List types (e.g., telefoni, ruoli, altre_emails)
      else if (value is List) {
        if (key == 'telefoni') {
          cells.add(DataGridCell<String>(columnName: key, value: (value).map((e) => e['v']?.toString() ?? '').where((s) => s.isNotEmpty).join(', ')));
        } else {
          cells.add(DataGridCell<String>(columnName: key, value: (value).map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).join(', ')));
        }
      } else {
        cells.add(DataGridCell<dynamic>(columnName: key, value: value));
      }
    });
    return DataGridRow(cells: cells);
  }

  @override
  void toggleUIModePublic() => _toggleUIMode();

  void _toggleUIMode({Map<String, dynamic>? initialRecordForForm}) {
    if (widget.config.uiModes.length <= 1 && initialRecordForForm == null) return;

    setState(() {
      if (initialRecordForForm != null && widget.config.uiModes.contains(UIMode.form)) {
        _currentUIMode = UIMode.form;
        _setSelectedRecordForForm(initialRecordForForm);
      } else {
        int currentIndex = widget.config.uiModes.indexOf(_currentUIMode);
        _currentUIMode = widget.config.uiModes[(currentIndex + 1) % widget.config.uiModes.length];
        if (_currentUIMode == UIMode.form && _data.isNotEmpty && _currentFormRecordIndex == -1) {
          _setSelectedRecordForForm(_data.first);
        } else if (_currentUIMode != UIMode.form) {
          _currentFormRecordIndex = -1;
        }
      }
      widget.config.onViewModeChanged?.call(_currentUIMode);
      appLogger.info("DBGridWidget: UI Mode toggled to: $_currentUIMode");
    });
  }

  void _handleRowDoubleTap(DataGridCellDoubleTapDetails details) {
    final rowIndex = details.rowColumnIndex.rowIndex;
    if (rowIndex > 0) {
      final dataIndex = rowIndex - 1;
      if (dataIndex >= 0 && dataIndex < _data.length) {
        final rowData = _data[dataIndex];
        if (widget.config.uiModes.contains(UIMode.form)) {
          _toggleUIMode(initialRecordForForm: rowData);
        } else if (widget.config.formHookName != null) {
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
    appLogger.info("Trigger Form Hook: ${widget.config.formHookName} with data: $recordData");
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Form Hook '${widget.config.formHookName}' called for ID: ${recordData['id'] ?? 'N/A'}")));
    }
  }

  void _setSelectedRecordForForm(Map<String, dynamic> recordData) {
    _currentFormRecordIndex = _data.indexWhere((d) => _areMapsEqual(d, recordData));
    _dataSource.clearSelections();
    if (_currentFormRecordIndex != -1) {
      _dataSource.handleRowSelection(recordData, isSelected: true);
    }
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
    return _dataSource.getSelectedDataForForm();
  }

  @override
  List<String> getPrimaryKeyColumns() {
    return widget.config.primaryKeyColumns;
  }

  @override
  bool canGoToPreviousRecordInForm() {
    return _currentFormRecordIndex > 0;
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
  bool canGoToNextRecordInForm() {
    return _currentFormRecordIndex < _data.length - 1;
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
            appLogger.warning("DBGridWidget: In Form Mode but no valid record. Returning to grid.");
            setState(() {
              _currentUIMode = widget.config.uiModes.firstWhereOrNull((m) => m == UIMode.grid) ?? widget.config.uiModes.first;
              widget.config.onViewModeChanged?.call(_currentUIMode);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No record selected for form. Displaying Grid View.")));
              }
            });
          }
        });
        return _isLoading ? const Center(child: CircularProgressIndicator()) : _buildGridView();
      case UIMode.map:
        return Center(
            child: Column(
                mainAxisAlignment: MainAxisAlignment.center, children: [Text("Map View (Not Implemented for ${widget.config.dataSourceTable})"), const SizedBox(height: 20), ElevatedButton(onPressed: _toggleUIMode, child: const Text("Back to Grid"))]));
    }
  }

  Widget _buildPaginationControls() {
    if ((widget.config.rpcFunctionName != null && _totalPages <= 1) || (_totalRecords == 0 && _errorMessage.isNotEmpty)) {
      return const SizedBox.shrink();
    }

    if (_totalRecords == 0) {
      if (_isLoading) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: const [Text("Loading...", style: TextStyle(fontSize: 12))]),
        );
      }
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(icon: const Icon(Icons.first_page), onPressed: _isLoading || _currentPage == 0 ? null : () => _goToPage(0), tooltip: "First page"),
          IconButton(icon: const Icon(Icons.navigate_before), onPressed: _isLoading || _currentPage == 0 ? null : _previousPage, tooltip: "Previous page"),
          Expanded(child: Text('Page ${_currentPage + 1} of $_totalPages ($_totalRecords records)', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12))),
          IconButton(icon: const Icon(Icons.navigate_next), onPressed: _isLoading || _currentPage >= _totalPages - 1 ? null : _nextPage, tooltip: "Next page"),
          IconButton(icon: const Icon(Icons.last_page), onPressed: _isLoading || _currentPage >= _totalPages - 1 || _totalPages == 0 ? null : () => _goToPage(_totalPages - 1), tooltip: "Last page"),
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
                    label = "Grid";
                    break;
                  case UIMode.form:
                    icon = Icons.article_outlined;
                    label = "Form";
                    break;
                  case UIMode.map:
                    icon = Icons.map_outlined;
                    label = "Map";
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
          key: ValueKey(
              widget.config.dataSourceTable + _sortedColumnsState.entries.map((e) => '${e.key}_${e.value?.toString()}').join('_') + _currentPage.toString() + _totalRecords.toString() + _filterValues.entries.map((e) => '${e.key}_${e.value}').join('_')),
          source: _dataSource,
          columns: _columns,
          controller: _dataGridController,
          allowSorting: true,
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
                _dataSource.handleRowSelection(_data[dataIndex]);
              }
            }
          },
        ),
      ),
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
  final Function(List<SfDataGridSortColumn> sortColumns) _onSortRequest; // Corrected type

  _DBGridDataSource({
    required List<Map<String, dynamic>> gridData,
    required DataGridRow Function(Map<String, dynamic>, int) buildRowCallback,
    required List<Map<String, dynamic>> selectedRowsDataMap,
    required VoidCallback onSelectionChanged,
    required bool Function(Map<String, dynamic> map1, Map<String, dynamic> map2) areMapsEqualCallback,
    required Function(List<SfDataGridSortColumn> sortColumns) onSortRequest, // Corrected type
  })  : _gridDataInternal = gridData,
        _buildRowCallback = buildRowCallback,
        _selectedRowsDataMap = selectedRowsDataMap,
        _onSelectionChanged = onSelectionChanged,
        _areMapsEqualCallback = areMapsEqualCallback,
        _onSortRequest = onSortRequest {
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
          // Special handling for the photo_url column to display the Widget directly
          if (dataGridCell.columnName == 'photo_url' && dataGridCell.value is Widget) {
            return Container(
              alignment: Alignment.center, // Center the image
              padding: const EdgeInsets.all(4.0), // Small padding for the image
              child: ClipOval(
                // Clip the image to a circle
                child: dataGridCell.value as Widget,
              ),
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

  @override
  Future<void> handleDataGridSort(List<SfDataGridSortColumn> sortColumns) async {
    appLogger.debug("_DBGridDataSource.handleDataGridSort() called with: $sortColumns");
    _onSortRequest(sortColumns);
  }
}

class NavigationService {
  static GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
}
