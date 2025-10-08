import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:una_social/helpers/db_grid.dart';

class Insegamenti extends StatefulWidget {
  const Insegamenti({super.key}); // Aggiungi const e correggi il costruttore

  @override
  State<Insegamenti> createState() => _InsegamentiState();
}

class _InsegamentiState extends State<Insegamenti> {
  final List<GridColumn> columns = [
    GridColumn(
      columnName: 'universita',
      columnWidthMode: ColumnWidthMode.fitByCellValue,
      label: const Text('Università'),
    ),
    GridColumn(
      columnWidthMode: ColumnWidthMode.fitByCellValue,
      columnName: 'id_insegnamento',
      label: const Text('ID'),
    ),
    GridColumn(
      columnWidthMode: ColumnWidthMode.fitByCellValue,
      columnName: 'anno_accademico',
      label: const Text('Anno Accademico'),
    ),
    GridColumn(
      columnWidthMode: ColumnWidthMode.fitByCellValue,
      columnName: 'progressivo',
      label: const Text('Progressivo'),
    ),
    GridColumn(
      columnWidthMode: ColumnWidthMode.fitByCellValue,
      columnName: 'nome_insegnamento',
      label: const Text('Nome Insegnamento'),
    ),
    GridColumn(
      columnWidthMode: ColumnWidthMode.fitByCellValue,
      columnName: 'id_docente',
      label: const Text('ID Docente'),
    ),
    GridColumn(
      columnWidthMode: ColumnWidthMode.fitByCellValue,
      columnName: 'cfu',
      label: const Text('CFU'),
    ),
    GridColumn(
      columnWidthMode: ColumnWidthMode.fitByCellValue,
      columnName: 'id_ambito',
      label: const Text('ID Ambito'),
    ),
    GridColumn(
      columnWidthMode: ColumnWidthMode.fitByCellValue,
      columnName: 'id_campus',
      label: const Text('ID Campus'),
    ),
    GridColumn(
      columnWidthMode: ColumnWidthMode.fitByCellValue,
      columnName: 'id_ssd',
      label: const Text('ID SSD'),
    ),
    GridColumn(
      columnWidthMode: ColumnWidthMode.fitByCellValue,
      columnName: 'id_laurea',
      label: const Text('ID Laurea'),
    ),
    GridColumn(
      columnWidthMode: ColumnWidthMode.fitByCellValue,
      columnName: 'id_padre',
      label: const Text('ID Padre'),
    ),
    GridColumn(
      columnWidthMode: ColumnWidthMode.fitByCellValue,
      columnName: 'id_zio',
      label: const Text('ID Zio'),
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
      dataSourceTable: 'insegnamenti',
      emptyDataMessage: "Nessun insegnamento tovato.",
      fixedColumnsCount: 0,
      initialSortBy: [
        SortColumn(column: 'universita', direction: SortDirection.asc),
        SortColumn(column: 'id_insegnamento', direction: SortDirection.asc),
      ],
      pageLength: 25,
      primaryKeyColumns: ['universita', 'id'],
      selectable: false,
      showHeader: true,
      uiModes: const [UIMode.grid, UIMode.form],
    );

    return DBGridWidget(config: dbGridConfig);
  }
}
