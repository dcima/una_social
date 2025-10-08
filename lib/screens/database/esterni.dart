import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:una_social/helpers/db_grid.dart';

class Esterni extends StatefulWidget {
  const Esterni({super.key}); // Aggiungi const e correggi il costruttore

  @override
  State<Esterni> createState() => _EsterniState();
}

class _EsterniState extends State<Esterni> {
  // Rimosso l'istanza di UiController da qui, non è più necessaria per initState.
  // Se fosse necessaria per altri scopi nel build, andrebbe mantenuta.

  final List<GridColumn> columns = [
    GridColumn(
      columnName: 'id',
      columnWidthMode: ColumnWidthMode.fitByCellValue,
      label: const Text('ID'),
    ),
    GridColumn(
      columnWidthMode: ColumnWidthMode.fitByCellValue,
      columnName: 'auth_uuid',
      label: const Text('Auth UUID'),
    ),
    GridColumn(
      columnName: 'cognome',
      columnWidthMode: ColumnWidthMode.fitByCellValue,
      label: const Text('Cognome'),
    ),
    GridColumn(
      columnName: 'nome',
      columnWidthMode: ColumnWidthMode.fitByCellValue,
      label: const Text('Nome'),
    ),
  ];

  @override
  void initState() {
    super.initState();
    // Rimosso: uiController.updateBreadcrumbs(UiController.buildBreadcrumbsFromPath('/app/Esterni'));
    // L'aggiornamento dei breadcrumbs è gestito centralmente dal ShellRoute in app_router.dart
  }

  @override
  Widget build(BuildContext context) {
    final dbGridConfig = DBGridConfig(
      columns: columns,
      dataSourceTable: 'esterni',
      emptyDataMessage: "Nessun account esterno trovato.",
      fixedColumnsCount: 0,
      initialSortBy: [
        SortColumn(column: 'cognome', direction: SortDirection.asc),
        SortColumn(column: 'nome', direction: SortDirection.asc),
      ],
      pageLength: 25,
      primaryKeyColumns: ['id'],
      selectable: false,
      showHeader: true,
      uiModes: const [UIMode.grid, UIMode.form],
    );

    return DBGridWidget(config: dbGridConfig);
  }
}
