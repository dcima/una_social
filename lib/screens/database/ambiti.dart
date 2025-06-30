import 'package:flutter/material.dart';
import 'package:una_social/helpers/db_grid.dart';

class AmbitiScreen extends StatelessWidget {
  const AmbitiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dbGridConfig = DBGridConfig(
      dataSourceTable: 'ambiti',
      pageLength: 25,
      showHeader: true,
      fixedColumnsCount: 0,
      selectable: false,
      emptyDataMessage: "Nessun ambito trovato.",
      initialSortBy: [
        SortColumn(column: 'universita', direction: SortDirection.asc),
        SortColumn(column: 'nome_ambito', direction: SortDirection.asc),
      ],
      uiModes: const [UIMode.grid, UIMode.form],
      primaryKeyColumns: ['universita', 'id_ambito'],
    );

    return Scaffold(
      //appBar: AppBar(title: const Text('Ambiti')),
      body: DBGridWidget(config: dbGridConfig),
    );
  }
}
