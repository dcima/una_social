import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:una_social/helpers/db_grid.dart';

class AmbitiScreen extends StatelessWidget {
  AmbitiScreen({super.key});

  final List<GridColumn> columns = [
    GridColumn(
      columnName: 'id_ambito',
      columnWidthMode: ColumnWidthMode.fitByCellValue,
      label: const Text('ID Ambito'),
    ),
    GridColumn(
      columnWidthMode: ColumnWidthMode.fill,
      columnName: 'universita',
      label: const Text('Università'),
    ),
    GridColumn(
      columnName: 'nome_ambito',
      columnWidthMode: ColumnWidthMode.fill,
      label: const Text('Nome Ambito'),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final dbGridConfig = DBGridConfig(
      columns: columns,
      dataSourceTable: 'ambiti',
      emptyDataMessage: "Nessun ambito trovato.",
      fixedColumnsCount: 0,
      initialSortBy: [
        SortColumn(column: 'universita', direction: SortDirection.asc),
        SortColumn(column: 'nome_ambito', direction: SortDirection.asc),
      ],
      pageLength: 25,
      primaryKeyColumns: ['universita', 'id_ambito'],
      selectable: false,
      showHeader: true,
      uiModes: const [UIMode.grid, UIMode.form],
    );

    return Scaffold(
      //appBar: AppBar(title: const Text('Ambiti')),
      body: DBGridWidget(config: dbGridConfig),
    );
  }
}
