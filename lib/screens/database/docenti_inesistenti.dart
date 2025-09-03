import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:una_social/helpers/db_grid.dart';

class DocentiInesistentiScreen extends StatelessWidget {
  DocentiInesistentiScreen({super.key});

  final List<GridColumn> columns = [
    GridColumn(
      columnName: 'nome_docente_originale',
      columnWidthMode: ColumnWidthMode.fill,
      label: const Text('Nome Docente Originale'),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final dbGridConfig = DBGridConfig(
      columns: columns,
      dataSourceTable: 'docenti_inesistenti',
      pageLength: 25,
      showHeader: true,
      fixedColumnsCount: 0,
      selectable: false,
      emptyDataMessage: "Nessun docente (inesistente!) trovato.",
      initialSortBy: [
        SortColumn(column: 'nome_docente_originale', direction: SortDirection.asc),
      ],
      uiModes: const [UIMode.grid, UIMode.form],
      primaryKeyColumns: [],
    );

    return Scaffold(
      //appBar: AppBar(title: const Text('Docenti Inesistenti')),
      body: DBGridWidget(config: dbGridConfig),
    );
  }
}
