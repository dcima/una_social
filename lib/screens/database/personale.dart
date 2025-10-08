import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:una_social/helpers/db_grid.dart';

class Personale extends StatelessWidget {
  Personale({super.key});

  final List<GridColumn> columns = [
    GridColumn(
      columnName: 'ente',
      columnWidthMode: ColumnWidthMode.fill,
      label: const Text('Ente'),
    ),
    GridColumn(
      columnWidthMode: ColumnWidthMode.fitByCellValue,
      columnName: 'id',
      label: const Text('Id'),
    ),
    GridColumn(
      columnName: 'cognome',
      columnWidthMode: ColumnWidthMode.fill,
      label: const Text('Cognome'),
    ),
    GridColumn(
      columnName: 'nome',
      columnWidthMode: ColumnWidthMode.fill,
      label: const Text('Nome'),
    ),
    GridColumn(
      columnName: 'struttura',
      columnWidthMode: ColumnWidthMode.fill,
      label: const Text('Struttura'),
    ),
    GridColumn(
      columnName: 'email_principale',
      columnWidthMode: ColumnWidthMode.fill,
      label: const Text('Email Principale'),
    ),
    GridColumn(
      columnName: 'ruoli',
      columnWidthMode: ColumnWidthMode.fill,
      label: const Text('Ruoli'),
    ),
    GridColumn(
      columnName: 'altre_emails',
      columnWidthMode: ColumnWidthMode.fill,
      label: const Text('Altre Emails'),
    ),
    GridColumn(
      columnName: 'telefoni',
      columnWidthMode: ColumnWidthMode.fill,
      label: const Text('Telefoni'),
    ),
    GridColumn(
      columnName: 'photo_url',
      columnWidthMode: ColumnWidthMode.fill,
      label: const Text('Photo URL'),
    ),
    GridColumn(
      columnName: 'cv',
      columnWidthMode: ColumnWidthMode.fill,
      label: const Text('CV'),
    ),
    GridColumn(
      columnName: 'web',
      columnWidthMode: ColumnWidthMode.fill,
      label: const Text('Web'),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final dbGridConfig = DBGridConfig(
      columns: columns,
      dataSourceTable: 'personale',
      pageLength: 50,
      showHeader: true,
      fixedColumnsCount: 0,
      selectable: false,
      emptyDataMessage: "Nessun dipendente/studente trovato.",
      initialSortBy: [
        SortColumn(column: 'ente', direction: SortDirection.asc),
        SortColumn(column: 'cognome', direction: SortDirection.asc),
      ],
      uiModes: const [UIMode.grid, UIMode.form],
      primaryKeyColumns: ['ente', 'id'],
    );

    return Scaffold(
      //appBar: AppBar(title: const Text('Personale')),
      body: DBGridWidget(config: dbGridConfig),
    );
  }
}
