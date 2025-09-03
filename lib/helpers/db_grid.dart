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
  final bool selectable;
  final bool showHeader;
  final Function(UIMode newMode)? onViewModeChanged;
  final int fixedColumnsCount;
  final int pageLength;
  final List<GridColumn> columns;
  final List<SortColumn> initialSortBy;
  final List<String> excludeColumns;
  final List<String> primaryKeyColumns;
  final List<UIMode> uiModes;
  final Map<String, dynamic>? rpcFunctionParams;
  final String dataSourceTable;
  final String emptyDataMessage;
  final String? formHookName;
  final String? mapHookName;
  final String? rpcFunctionName;

  DBGridConfig({
    required this.dataSourceTable,
    required this.columns,
    this.emptyDataMessage = "Nessun dato disponibile.",
    this.excludeColumns = const [],
    this.fixedColumnsCount = 0,
    this.formHookName,
    this.initialSortBy = const [],
    this.mapHookName,
    this.onViewModeChanged,
    this.pageLength = 25,
    this.primaryKeyColumns = const ['id'],
    this.rpcFunctionName,
    this.rpcFunctionParams,
    this.selectable = false,
    this.showHeader = true,
    this.uiModes = const [UIMode.grid],
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

  // FUNZIONE AGGIORNATA: Genera un URL proxy per l'immagine per aggirare i problemi CORS
  String getProxiedImageUrl(String originalPhotoUrl) {
    // Utilizziamo Supabase.instance.client.rest.url per ottenere un URL che contiene il project-ref
    // Sarà qualcosa come 'http://<IP_O_DOMINIO_DEL_TUO_SERVER>:8000/rest/v1'
    final restBaseUrl = Supabase.instance.client.rest.url;

    // Controlla se l'URL è nullo o vuoto prima di tentare di analizzarlo
    if (restBaseUrl.isEmpty) {
      appLogger.error('Supabase REST URL is null or empty, cannot generate proxied image URL. Falling back to original.');
      return originalPhotoUrl; // Fallback to original if base URL not available
    }

    final uri = Uri.parse(restBaseUrl);
    final host = uri.host; // e.g., '192.168.1.100' or 'localhost'
    final port = uri.port; // e.g., '8000'

    // Per un setup Docker, il "projectRef" è l'host:porta
    final projectRef = '$host:$port';

    // Aggiungi logging qui per verificare i valori estratti
    appLogger.info('DEBUG: REST Base URL: $restBaseUrl');
    appLogger.info('DEBUG: Host from URL: $host');
    appLogger.info('DEBUG: Port from URL: $port');
    appLogger.info('DEBUG: Project Ref extracted (for Docker): $projectRef');

    // Costruiamo l'URL completo della nostra Edge Function 'image-proxy'
    // Nota: per le Edge Functions su Docker, l'URL è tipicamente <host>:<port>/functions/v1/<nome_funzione>
    final proxyBaseUrl = 'https://$projectRef/functions/v1/image-proxy';

    // Codifica l'URL originale dell'immagine e lo aggiunge come parametro alla Edge Function
    final fullProxiedUrl = '$proxyBaseUrl?url=${Uri.encodeComponent(originalPhotoUrl)}';
    appLogger.info('DEBUG: Generated Proxied URL: $fullProxiedUrl');

    return fullProxiedUrl;
  }

  // Centralized map comparison logic
  bool _areMapsEqual(Map<String, dynamic> map1, Map<String, dynamic> map2) {
    if (widget.config.primaryKeyColumns.isNotEmpty) {
      bool allPkMatch = true;
      for (String pkCol in widget.config.primaryKeyColumns) {
        if (!map1.containsKey(pkCol) || !map2.containsKey(pkCol) || map1[pkCol] != map2[pkCol]) {
          allPkMatch = false;
          break;
        }
      }
      if (allPkMatch) return true;
    }

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
      _data.clear();
      _dataSource.clearSelections();
      _currentFormRecordIndex = -1;
    } else {
      _currentPage++;
    }

    if (_data.isNotEmpty && _data.length >= _totalRecords && !isRefresh) {
      appLogger.info("All records already loaded. Not fetching more.");
      setState(() => _isLoading = false);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final int limit = widget.config.pageLength;
      final int offset = _currentPage * limit;

      dynamic rpcResult;

      if (widget.config.rpcFunctionName != null) {
        final Map<String, dynamic> rpcParams = Map.from(widget.config.rpcFunctionParams ?? {});
        rpcParams['p_limit'] = limit;
        rpcParams['p_offset'] = offset;

        final sortedColumn = _sortedColumnsState.entries.firstOrNull;
        if (sortedColumn != null) {
          rpcParams['p_order_by'] = sortedColumn.key;
          rpcParams['p_order_direction'] = sortedColumn.value == DataGridSortDirection.ascending ? 'asc' : 'desc';
        } else {
          rpcParams['p_order_by'] = widget.config.initialSortBy.isNotEmpty ? widget.config.initialSortBy.first.column : 'cognome';
          rpcParams['p_order_direction'] = widget.config.initialSortBy.isNotEmpty && widget.config.initialSortBy.first.direction == SortDirection.desc ? 'desc' : 'asc';
        }

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

        if (rpcResult is Map<String, dynamic> && rpcResult.containsKey('data') && rpcResult.containsKey('count')) {
          _data.addAll(List<Map<String, dynamic>>.from(rpcResult['data'] ?? []));
          _totalRecords = (rpcResult['count'] as num?)?.toInt() ?? 0;
        } else if (rpcResult is List) {
          _data.addAll(List<Map<String, dynamic>>.from(rpcResult));
          _totalRecords = _data.length;
          appLogger.warning('RPC did not return expected JSONB with data and count. Assuming all data returned.');
        } else if (rpcResult != null) {
          _data.add(Map<String, dynamic>.from(rpcResult));
          _totalRecords = 1;
        } else {
          _totalRecords = _data.length;
        }
      } else {
        final PostgrestResponse<dynamic> response = await Supabase.instance.client.from(widget.config.dataSourceTable).select().range(offset, offset + limit - 1).count(CountOption.exact);

        _data.addAll(List<Map<String, dynamic>>.from(response.data ?? []));
        _totalRecords = response.count;
      }

      if (!mounted) return;

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

        _data[i] = newRow;
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

  Future<void> handleLoadMoreRows() async {
    if (_data.length < _totalRecords && !_isLoading) {
      appLogger.info("SfDataGrid onLoadMoreRows triggered. Current data length: ${_data.length}, Total records: $_totalRecords");
      await _fetchData(isRefresh: false);
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

    final Map<String, GridColumn> userDefinedColumns = {for (var col in widget.config.columns) col.columnName: col};

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

    Widget buildColumnLabel(String colName, GridColumn? userColumn) {
      _filterControllers.putIfAbsent(colName, () => TextEditingController());
      _filterValues.putIfAbsent(colName, () => '');

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        alignment: Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              userColumn?.label != null && userColumn!.label is Text ? (userColumn.label as Text).data! : _formatHeader(colName),
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
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
      );
    }

    for (GridColumn userColumn in widget.config.columns) {
      final String colName = userColumn.columnName;
      if (availableColumnNames.contains(colName) && !widget.config.excludeColumns.contains(colName)) {
        cols.add(GridColumn(
          columnName: userColumn.columnName,
          label: buildColumnLabel(colName, userColumn),
          allowSorting: userColumn.allowSorting,
          width: userColumn.width,
          columnWidthMode: userColumn.columnWidthMode,
        ));
        addedColumns.add(colName);
      }
    }

    for (var name in availableColumnNames) {
      if (!addedColumns.contains(name) && !widget.config.excludeColumns.contains(name)) {
        cols.add(GridColumn(
          columnName: name,
          label: buildColumnLabel(name, null),
          allowSorting: true,
          columnWidthMode: ColumnWidthMode.fill,
        ));
        addedColumns.add(name);
      }
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
          final proxiedImageUrl = getProxiedImageUrl(finalImageUrl);
          imageWidget = Image(
            image: NetworkImage(proxiedImageUrl),
            fit: BoxFit.cover,
            width: 40,
            height: 40,
            errorBuilder: (context, error, stackTrace) {
              appLogger.error('Error loading proxied image from $proxiedImageUrl: $error');
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
    if (_isLoading && _data.isEmpty && _errorMessage.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage.isNotEmpty && _data.isEmpty) {
      return Center(child: Text(_errorMessage, style: const TextStyle(color: Colors.red)));
    }
    if (!_isLoading && _data.isEmpty && _errorMessage.isEmpty) {
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

  Widget getMoreRows(BuildContext context, LoadMoreRows loadMoreRows) {
    if (_data.length >= _totalRecords && _totalRecords > 0) {
      return Container(
        height: 50.0,
        alignment: Alignment.center,
        child: Text('Tutti i $_totalRecords record caricati.', textAlign: TextAlign.center),
      );
    } else if (_isLoading) {
      return Container(
        height: 50.0,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(strokeWidth: 2),
      );
    } else {
      return FutureBuilder<void>(
        future: loadMoreRows(),
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
            return const SizedBox.shrink();
          }
        },
      );
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
          allowColumnsResizing: true,
          allowSorting: true,
          columns: _columns,
          columnWidthMode: ColumnWidthMode.fill,
          controller: _dataGridController,
          frozenColumnsCount: widget.config.fixedColumnsCount + (widget.config.selectable ? 1 : 0),
          gridLinesVisibility: GridLinesVisibility.both,
          headerGridLinesVisibility: GridLinesVisibility.both,
          headerRowHeight: 70.0,
          key: ValueKey(widget.config.dataSourceTable + _sortedColumnsState.entries.map((e) => '${e.key}_${e.value?.toString()}').join('_') + _filterValues.entries.map((e) => '${e.key}_${e.value}').join('_')),
          loadMoreViewBuilder: (BuildContext context, LoadMoreRows loadMoreRows) => getMoreRows(context, loadMoreRows),
          navigationMode: GridNavigationMode.cell,
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
          selectionMode: widget.config.selectable ? SelectionMode.multiple : SelectionMode.single,
          source: _dataSource,
        ),
      ),
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
  final Function(bool isRefresh)? fetchDataCallback;

  _DBGridDataSource({
    required List<Map<String, dynamic>> gridData,
    required DataGridRow Function(Map<String, dynamic>, int) buildRowCallback,
    required List<Map<String, dynamic>> selectedRowsDataMap,
    required VoidCallback onSelectionChanged,
    required bool Function(Map<String, dynamic> map1, Map<String, dynamic> map2) areMapsEqualCallback,
    required Function(List<SortColumnDetails> sortColumns) onSortRequest,
    this.fetchDataCallback,
  })  : _gridDataInternal = gridData,
        _buildRowCallback = buildRowCallback,
        _selectedRowsDataMap = selectedRowsDataMap,
        _onSelectionChanged = onSelectionChanged,
        _areMapsEqualCallback = areMapsEqualCallback,
        _onSortRequest = onSortRequest {
    _buildDataGridRows();
  }

  void handleRowSelection(Map<String, dynamic> rowData, {bool isSelected = true}) {
    if (isSelected) {
      _selectedRowsDataMap.clear();
      _selectedRowsDataMap.add(Map.from(rowData));
    } else {
      _selectedRowsDataMap.removeWhere((item) => _areMapsEqualCallback(item, rowData));
    }
    notifyListeners();
    _onSelectionChanged();
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
                if (originalData != null) handleRowSelection(originalData, isSelected: value ?? false);
              },
            );
          }
          if (dataGridCell.columnName == 'photo_url' && dataGridCell.value is Widget) {
            return Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.all(4.0),
              child: ClipOval(
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

  @override
  Future<void> handleLoadMoreRows() async {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      fetchDataCallback?.call(false);
    });
  }
}

class NavigationService {
  static GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
}
