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
import 'package:universal_html/html.dart' as html; // Import per parsing HTML

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

  DataGridController _dataGridController = DataGridController();
  Map<String, DataGridSortDirection?> _sortedColumnsState = {};
  late UIMode _currentUIMode;
  int _currentFormRecordIndex = -1;

  // Filtering state - Stores actual filter values and their controllers
  final Map<String, String> _filterValues = {};
  final Map<String, TextEditingController> _filterControllers = {};
  Timer? _filterDebounce; // For filter debouncing

  @override
  void initState() {
    super.initState();
    _currentUIMode = widget.config.uiModes.isNotEmpty ? widget.config.uiModes.first : UIMode.grid;
    _initializeSortedColumns();

    // Initialize filter controllers for all potentially filterable columns
    // including those in fixedOrderColumns and any other dynamic columns.
    // It's safer to initialize them all at once or dynamically as columns are generated.
    // Here, we initialize for the fixed columns. Other columns will be putIfAbsent in _generateColumns.
    final List<String> initialFilterableColumns = ['photo_url', 'cognome', 'nome', 'email_principale'];
    for (var colName in initialFilterableColumns) {
      _filterControllers[colName] = TextEditingController();
      _filterValues[colName] = '';
    }

    _dataSource = _DBGridDataSource(
      gridData: _data,
      buildRowCallback: _buildRow,
      selectedRowsDataMap: [],
      onSelectionChanged: () {
        if (mounted) setState(() {});
      },
      areMapsEqualCallback: _areMapsEqual,
      onSortRequest: (sortColumns) {
        if (!mounted) return;
        setState(() {
          _sortedColumnsState.clear();
          if (sortColumns.isNotEmpty) {
            final sortCol = sortColumns.first;
            _sortedColumnsState[sortCol.name] = sortCol.sortDirection;
          }
        });
        _fetchData(isRefresh: true); // Trigger full refresh on sort change
      },
      // Pass the widget's _fetchData method to the DataSource for handleLoadMoreRows
      fetchDataCallback: (isRefresh) => _fetchData(isRefresh: isRefresh),
    );

    _fetchData(isRefresh: true); // Initial data fetch
  }

  @override
  void dispose() {
    _filterDebounce?.cancel(); // Cancel debounce timer on dispose
    _filterControllers.forEach((key, controller) => controller.dispose()); // Dispose all controllers
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
      _data.clear(); // Clear existing data on full refresh/filter change
      _dataSource.clearSelections();
      _currentFormRecordIndex = -1; // Reset form index on full refresh
    } else {
      // For infinite scroll, increment page before fetching
      _currentPage++;
    }

    // Prevent fetching if all records are already loaded (for infinite scroll)
    if (_data.isNotEmpty && _data.length >= _totalRecords && !isRefresh) {
      appLogger.info("All records already loaded. Not fetching more.");
      setState(() => _isLoading = false); // Ensure loading state is false
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final int limit = widget.config.pageLength;
      final int offset = _currentPage * limit;

      dynamic rpcResult; // Declare rpcResult here to ensure scope

      if (widget.config.rpcFunctionName != null) {
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
          rpcParams['p_order_by'] = widget.config.initialSortBy.isNotEmpty ? widget.config.initialSortBy.first.column : 'cognome';
          rpcParams['p_order_direction'] = widget.config.initialSortBy.isNotEmpty && widget.config.initialSortBy.first.direction == SortDirection.desc ? 'desc' : 'asc';
        }

        // Add filtering parameters (supports only one active filter for simplicity with current RPC)
        final activeFilter = _filterValues.entries.firstWhereOrNull((e) => e.value.isNotEmpty);
        if (activeFilter != null) {
          rpcParams['p_filter_column'] = activeFilter.key;
          rpcParams['p_filter_value'] = activeFilter.value;
        } else {
          rpcParams['p_filter_column'] = null;
          rpcParams['p_filter_value'] = null;
        }

        appLogger.info('RPC final params: $rpcParams');

        rpcResult = await Supabase.instance.client.rpc(
          widget.config.rpcFunctionName!,
          params: rpcParams,
        );

        // Handle JSONB return type { "data": [...], "count": N }
        if (rpcResult is Map<String, dynamic> && rpcResult.containsKey('data') && rpcResult.containsKey('count')) {
          _data.addAll(List<Map<String, dynamic>>.from(rpcResult['data'] ?? []));
          _totalRecords = (rpcResult['count'] as num?)?.toInt() ?? 0; // Safe cast from num to int
        } else if (rpcResult is List) {
          _data.addAll(List<Map<String, dynamic>>.from(rpcResult));
          _totalRecords = _data.length; // Fallback: assume all data returned if not JSONB
          appLogger.warning('RPC did not return expected JSONB with data and count. Assuming all data returned.');
        } else if (rpcResult != null) {
          _data.add(Map<String, dynamic>.from(rpcResult));
          _totalRecords = 1;
        } else {
          _totalRecords = _data.length; // No new data added, total remains current size
        }
      } else {
        // --- Standard table selection (existing logic, not ideal for infinite scroll without count from select) ---
        final PostgrestResponse<dynamic> response = await Supabase.instance.client.from(widget.config.dataSourceTable).select().range(offset, offset + limit - 1).count(CountOption.exact);

        _data.addAll(List<Map<String, dynamic>>.from(response.data ?? []));
        _totalRecords = response.count;
      }

      if (!mounted) return;

      // Decode JSONB strings for newly added/refreshed data
      final int startIndexForDecoding = isRefresh ? 0 : _data.length - (rpcResult is Map && rpcResult.containsKey('data') ? ((rpcResult['data']?.length ?? 0) as num).toInt() : (rpcResult is List ? rpcResult.length.toInt() : 0));
      for (int i = startIndexForDecoding; i < _data.length; i++) {
        final Map<String, dynamic> row = _data[i];
        final Map<String, dynamic> newRow = Map.from(row);

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
        _data[i] = newRow; // Update the row in the main list
      }

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
        final currentDataKeys = _data.first.keys.where((key) => !widget.config.excludeColumns.contains(key)).toList();
        int currentDataColumns = currentDataKeys.length;
        int displayedColumns = _columns.length - (widget.config.selectable ? 1 : 0);
        if (currentDataColumns != displayedColumns) {
          needsColumnRegeneration = true;
        }
      }

      if (needsColumnRegeneration && _data.isNotEmpty) {
        _columns = _generateColumns(_data.first.keys.where((key) => !widget.config.excludeColumns.contains(key)).toList());
      } else if (needsColumnRegeneration && _data.isEmpty) {
        _columns = [];
      }

      _dataSource.updateDataGridSource(_data);

      // Logic for form mode (remains unchanged)
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

  // NEW: Callback for SfDataGrid's onLoadMoreRows
  // This method is called by SfDataGrid's internal mechanism when it needs more rows.
  Future<void> handleLoadMoreRows() async {
    // This method is called by SfDataGrid when it needs more rows.
    // It should trigger fetching more data in the widget state.
    // The _fetchData method already contains the logic to check if more data is available.
    if (_data.length < _totalRecords && !_isLoading) {
      appLogger.info("SfDataGrid onLoadMoreRows triggered. Current data length: ${_data.length}, Total records: $_totalRecords");
      await _fetchData(isRefresh: false); // Fetch more data, append to existing
    } else {
      appLogger.info("SfDataGrid onLoadMoreRows skipped. All data loaded or currently loading.");
    }
  }

  void _initializeSortedColumns() {
    _sortedColumnsState.clear();
    for (var sortCol in widget.config.initialSortBy) {
      _sortedColumnsState[sortCol.column] = sortCol.direction == SortDirection.asc ? DataGridSortDirection.ascending : DataGridSortDirection.descending;
    }
  }

  List<GridColumn> _generateColumns(List<String> availableColumnNames) {
    List<GridColumn> cols = [];
    Set<String> addedColumns = {};

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
      addedColumns.add('_selector');
    }

    final List<String> fixedOrderColumns = ['photo_url', 'cognome', 'nome', 'email_principale'];

    for (String colName in fixedOrderColumns) {
      if (availableColumnNames.contains(colName) && !widget.config.excludeColumns.contains(colName)) {
        // Ensure controller exists for this column. If not, create it.
        _filterControllers.putIfAbsent(colName, () => TextEditingController());
        _filterValues.putIfAbsent(colName, () => '');

        cols.add(GridColumn(
          columnName: colName,
          label: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_formatHeader(colName), overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.bold)),
                if (widget.config.rpcFunctionName != null)
                  SizedBox(
                    height: 24,
                    child: TextField(
                      controller: _filterControllers[colName],
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
                        suffixIcon: ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _filterControllers[colName]!,
                          builder: (context, value, child) {
                            return value.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 16),
                                    onPressed: () {
                                      _filterControllers[colName]!.clear();
                                      _filterValues[colName] = '';
                                      _fetchData(isRefresh: true);
                                    },
                                  )
                                : const SizedBox.shrink();
                          },
                        ),
                      ),
                      onChanged: (value) {
                        _filterValues[colName] = value;
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
          // Set width for photo_url; other columns will be handled by ColumnWidthMode.fill if width is null
          width: colName == 'photo_url' ? 80 : 0,
        ));
        addedColumns.add(colName);
      }
    }

    for (var name in availableColumnNames) {
      if (!addedColumns.contains(name) && !widget.config.excludeColumns.contains(name)) {
        // Ensure controller exists for this column. If not, create it.
        _filterControllers.putIfAbsent(name, () => TextEditingController());
        _filterValues.putIfAbsent(name, () => '');

        cols.add(GridColumn(
          columnName: name,
          label: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_formatHeader(name), overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.bold)),
                if (widget.config.rpcFunctionName != null)
                  SizedBox(
                    height: 24,
                    child: TextField(
                      controller: _filterControllers[name],
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
                        suffixIcon: ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _filterControllers[name]!,
                          builder: (context, value, child) {
                            return value.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 16),
                                    onPressed: () {
                                      _filterControllers[name]!.clear();
                                      _filterValues[name] = '';
                                      _fetchData(isRefresh: true);
                                    },
                                  )
                                : const SizedBox.shrink();
                          },
                        ),
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
    }
    return cols;
  }

  void _debounceFilter() {
    if (_filterDebounce != null && _filterDebounce!.isActive) {
      _filterDebounce!.cancel();
    }
    _filterDebounce = Timer(const Duration(milliseconds: 500), () {
      _fetchData(isRefresh: true); // Trigger full refresh when filter changes
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

    for (var column in _columns) {
      final String columnName = column.columnName;

      if (columnName == '_selector' || widget.config.excludeColumns.contains(columnName)) {
        continue;
      }

      final dynamic value = rowData[columnName];

      if (columnName == 'photo_url') {
        String? photoUrl = value?.toString();
        String? finalImageUrl;

        if (photoUrl != null && photoUrl.isNotEmpty) {
          if (photoUrl.trim().startsWith('<') && photoUrl.trim().endsWith('>') && photoUrl.contains('<img')) {
            try {
              final html.DomParser parser = html.DomParser();
              final html.Document document = parser.parseFromString(photoUrl, 'text/html');
              final html.ImageElement? imgElement = document.querySelector('img') as html.ImageElement?;
              if (imgElement != null && imgElement.src != null) {
                finalImageUrl = imgElement.src;
                finalImageUrl = finalImageUrl!.replaceAll('&amp;', '&');
              } else {
                appLogger.warning("Could not find <img> tag or src in HTML string: $photoUrl");
              }
            } catch (e) {
              appLogger.error("Error parsing HTML for photo_url: $e, original: $photoUrl");
              finalImageUrl = photoUrl;
            }
          } else {
            finalImageUrl = photoUrl;
          }
        }

        Widget imageWidget;
        if (finalImageUrl != null && Uri.tryParse(finalImageUrl)?.isAbsolute == true) {
          final proxiedImageUrl = 'https://cors-anywhere.herokuapp.com/$finalImageUrl';
          imageWidget = Image(
            image: NetworkImage(
              proxiedImageUrl,
              headers: const {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/100.0.4896.88 Safari/537.36',
              },
            ),
            fit: BoxFit.cover,
            width: 40,
            height: 40,
            errorBuilder: (context, error, stackTrace) {
              appLogger.warning("Error loading image from URL: $proxiedImageUrl, Error: $error");
              return const Icon(Icons.person, size: 40);
            },
          );
        } else {
          imageWidget = const Icon(Icons.person, size: 40);
        }
        cells.add(DataGridCell<Widget>(columnName: columnName, value: imageWidget));
      } else if (value is List) {
        if (columnName == 'telefoni') {
          cells.add(DataGridCell<String>(columnName: columnName, value: (value).map((e) => e['v']?.toString() ?? '').where((s) => s.isNotEmpty).join(', ')));
        } else {
          cells.add(DataGridCell<String>(columnName: columnName, value: (value).map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).join(', ')));
        }
      } else {
        cells.add(DataGridCell<dynamic>(columnName: columnName, value: value));
      }
    }
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

  @override
  Widget build(BuildContext context) {
    // Adjusted initial loading/error checks
    if (_isLoading && _data.isEmpty && _errorMessage.isEmpty) {
      // Initial loading, no data yet
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage.isNotEmpty && _data.isEmpty) {
      // Initial error, no data loaded
      return Center(child: Text(_errorMessage, style: const TextStyle(color: Colors.red)));
    }
    if (!_isLoading && _data.isEmpty && _errorMessage.isEmpty) {
      // No data, not loading, no error means empty message
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

  Widget _buildGridView() {
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
          key: ValueKey(widget.config.dataSourceTable + _sortedColumnsState.entries.map((e) => '${e.key}_${e.value?.toString()}').join('_') + _filterValues.entries.map((e) => '${e.key}_${e.value}').join('_')),
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
          headerRowHeight: 70.0,
          // NEW: Infinite scroll configuration
          loadMoreViewBuilder: (BuildContext context, LoadMoreRows loadMoreRows) {
            // This builder will display the loading indicator or status message.
            // The `loadMoreRows` function is the one provided by SfDataGrid
            // that you call to trigger loading more data.
            // We'll call it within a FutureBuilder to manage the async call.

            if (_data.length >= _totalRecords && _totalRecords > 0) {
              // All data loaded
              return Container(
                height: 50.0,
                alignment: Alignment.center,
                child: Text('Tutti i $_totalRecords record caricati.', textAlign: TextAlign.center),
              );
            } else if (_isLoading) {
              // Currently loading (either initial or more data)
              return Container(
                height: 50.0,
                alignment: Alignment.center,
                child: const CircularProgressIndicator(strokeWidth: 2),
              );
            } else {
              // Not loading, but more data is available.
              // Trigger `loadMoreRows` automatically if it's not already loading.
              // Using FutureBuilder to ensure it's triggered once per visibility and manages its internal future.
              return FutureBuilder<void>(
                future: loadMoreRows(), // Call the provided loadMoreRows function
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Container(
                      height: 50.0,
                      alignment: Alignment.center,
                      child: const CircularProgressIndicator(strokeWidth: 2),
                    );
                  } else if (snapshot.hasError) {
                    appLogger.error("Error in loadMoreViewBuilder: ${snapshot.error}");
                    return Container(
                      height: 50.0,
                      alignment: Alignment.center,
                      child: Text('Errore caricamento dati: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
                    );
                  } else if (_data.length < _totalRecords) {
                    return Container(
                      height: 50.0,
                      alignment: Alignment.center,
                      child: Text('Scorri per caricare altri ${_totalRecords - _data.length} record (su $_totalRecords totali).', textAlign: TextAlign.center),
                    );
                  } else {
                    return const SizedBox.shrink(); // All data loaded or other state
                  }
                },
              );
            }
          },
        ),
      ),
      // The external loading indicators and status texts are now managed within loadMoreViewBuilder.
      // Removed previous conditional Padding widgets.
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
  final Function(List<SortColumnDetails> sortColumns) _onSortRequest;
  // NEW: Callback to trigger data fetching in the StatefulWidget
  final Function(bool isRefresh)? fetchDataCallback;

  _DBGridDataSource({
    required List<Map<String, dynamic>> gridData,
    required DataGridRow Function(Map<String, dynamic>, int) buildRowCallback,
    required List<Map<String, dynamic>> selectedRowsDataMap,
    required VoidCallback onSelectionChanged,
    required bool Function(Map<String, dynamic> map1, Map<String, dynamic> map2) areMapsEqualCallback,
    required Function(List<SortColumnDetails> sortColumns) onSortRequest,
    this.fetchDataCallback, // Initialize the callback
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

  Future<void> handleDataGridSort(List<SortColumnDetails> sortColumns) async {
    appLogger.debug("_DBGridDataSource.handleDataGridSort() called with: $sortColumns");
    _onSortRequest(sortColumns);
  }

  // Override the handleLoadMoreRows method from DataGridSource
  @override
  Future<void> handleLoadMoreRows() async {
    // This method is called by the DataGrid's loadMoreViewBuilder mechanism.
    // It should trigger the actual data fetching in the StatefulWidget.
    fetchDataCallback?.call(false); // Call the callback with isRefresh: false
  }
}

class NavigationService {
  static GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
}
