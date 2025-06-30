import 'package:flutter/material.dart';
import 'package:una_social/helpers/db_grid.dart';

class CampusScreen extends StatelessWidget {
  const CampusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dbGridConfig = DBGridConfig(
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
