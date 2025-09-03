import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:una_social/helpers/db_grid.dart';

class CampusScreen extends StatelessWidget {
  CampusScreen({super.key});

  final List<GridColumn> columns = [
    GridColumn(
      columnWidthMode: ColumnWidthMode.fitByCellValue,
      columnName: 'id_campus',
      label: const Text('Id Campus'),
    ),
    GridColumn(
      columnName: 'universita',
      columnWidthMode: ColumnWidthMode.fill,
      label: const Text('Università'),
    ),
    GridColumn(
      columnName: 'nome_campus',
      columnWidthMode: ColumnWidthMode.fill,
      label: const Text('Nome campus'),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final dbGridConfig = DBGridConfig(
      columns: columns,
      dataSourceTable: 'campus',
      pageLength: 25,
      showHeader: true,
      fixedColumnsCount: 0,
      selectable: false,
      emptyDataMessage: "Nessun campus trovato.",
      initialSortBy: [
        SortColumn(column: 'universita', direction: SortDirection.asc),
        SortColumn(column: 'nome_campus', direction: SortDirection.asc),
      ],
      uiModes: const [UIMode.grid, UIMode.form],
      primaryKeyColumns: ['universita', 'id_campus'],
    );

    return Scaffold(
      //appBar: AppBar(title: const Text('Campus')),
      body: DBGridWidget(config: dbGridConfig),
    );
  }
}
