import 'package:flutter/material.dart';
import 'package:una_social/helpers/db_grid.dart';

class PersonaleScreen extends StatelessWidget {
  const PersonaleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dbGridConfig = DBGridConfig(
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
