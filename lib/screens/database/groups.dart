import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:una_social/helpers/db_grid.dart';

class Groups extends StatefulWidget {
  const Groups({super.key}); // Aggiungi const e correggi il costruttore

  @override
  State<Groups> createState() => _GroupsState();
}

class _GroupsState extends State<Groups> {
  final List<GridColumn> columns = [
    GridColumn(
      columnName: 'id',
      columnWidthMode: ColumnWidthMode.fitByCellValue,
      label: const Text('ID'),
    ),
    GridColumn(
      columnWidthMode: ColumnWidthMode.fitByCellValue,
      columnName: 'descrizione',
      label: const Text('Descrizione'),
    ),
  ];

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final dbGridConfig = DBGridConfig(
      columns: columns,
      dataSourceTable: 'groups',
      emptyDataMessage: "Nessun gruppo tovato.",
      fixedColumnsCount: 0,
      initialSortBy: [
        SortColumn(column: 'id', direction: SortDirection.asc),
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
