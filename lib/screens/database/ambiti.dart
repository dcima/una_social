import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:una_social/helpers/db_grid.dart';

class Ambiti extends StatefulWidget {
  const Ambiti({super.key}); // Aggiungi const e correggi il costruttore

  @override
  State<Ambiti> createState() => _AmbitiState();
}

class _AmbitiState extends State<Ambiti> {
  // Rimosso l'istanza di UiController da qui, non è più necessaria per initState.
  // Se fosse necessaria per altri scopi nel build, andrebbe mantenuta.

  final List<GridColumn> columns = [
    GridColumn(
      columnWidthMode: ColumnWidthMode.fill,
      columnName: 'universita',
      label: const Text('Università'),
    ),
    GridColumn(
      columnName: 'id_ambito',
      columnWidthMode: ColumnWidthMode.fitByCellValue,
      label: const Text('ID Ambito'),
    ),
    GridColumn(
      columnName: 'nome_ambito',
      columnWidthMode: ColumnWidthMode.fill,
      label: const Text('Nome Ambito'),
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

    return DBGridWidget(config: dbGridConfig);
  }
}
