import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:una_social/helpers/db_grid.dart';

class Strutture extends StatelessWidget {
  Strutture({super.key});

  final List<GridColumn> columns = [
    GridColumn(
      columnName: 'ente',
      columnWidthMode: ColumnWidthMode.fitByCellValue,
      label: const Text('Ente'),
    ),
    GridColumn(
      columnWidthMode: ColumnWidthMode.fill,
      columnName: 'id',
      label: const Text('Id'),
    ),
    GridColumn(
      columnName: 'nome',
      columnWidthMode: ColumnWidthMode.fill,
      label: const Text('Nome'),
    ),
    GridColumn(
      columnName: 'indirizzo',
      columnWidthMode: ColumnWidthMode.fill,
      label: const Text('Indirizzo'),
    ),
    GridColumn(
      columnName: 'numero',
      columnWidthMode: ColumnWidthMode.fill,
      label: const Text('Num.'),
    ),
    GridColumn(
      columnName: 'citta',
      columnWidthMode: ColumnWidthMode.fill,
      label: const Text('Città'),
    ),
    GridColumn(
      columnName: 'cap',
      columnWidthMode: ColumnWidthMode.fill,
      label: const Text('CAP'),
    ),
    GridColumn(
      columnName: 'longitudine',
      columnWidthMode: ColumnWidthMode.fill,
      label: const Text('Longitudine'),
    ),
    GridColumn(
      columnName: 'latitudine',
      columnWidthMode: ColumnWidthMode.fill,
      label: const Text('Latitudine'),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final dbGridConfig = DBGridConfig(
      columns: columns,
      dataSourceTable: 'strutture',
      emptyDataMessage: "Nessuna struttura trovata.",
      fixedColumnsCount: 0,
      initialSortBy: [
        SortColumn(column: 'ente', direction: SortDirection.asc),
        SortColumn(column: 'id', direction: SortDirection.asc),
      ],
      pageLength: 25,
      primaryKeyColumns: ['ente', 'id'],
      selectable: false,
      showHeader: true,
      uiModes: const [UIMode.grid, UIMode.form, UIMode.map],
    );

    return Scaffold(
      body: DBGridWidget(config: dbGridConfig),
    );
  }
}
