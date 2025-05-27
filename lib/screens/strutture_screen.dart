// lib/screens/strutture_screen.dart
import 'package:flutter/material.dart';
// Aggiorna il percorso se hai spostato db_grid.dart
import 'package:una_social_app/helpers/db_grid.dart';
// import 'package:una_social_app/widgets/db_grid/db_grid.dart'; // Se è in widgets/db_grid/

class StruttureScreen extends StatefulWidget {
  // La GlobalKey è un membro del Widget StruttureScreen
  final GlobalKey<State<DBGridWidget>> dbGridWidgetStateKey = GlobalKey<State<DBGridWidget>>();

  // La config è anche un membro del Widget StruttureScreen,
  // così HomeScreen può leggerla direttamente.
  final DBGridConfig gridConfig;

  StruttureScreen({super.key})
      : gridConfig = DBGridConfig(
          dataSourceTable: 'strutture',
          pageLength: 20,
          showHeader: true,
          fixedColumnsCount: 1,
          selectable: true,
          emptyDataMessage: "Nessuna struttura trovata.",
          initialSortBy: [SortColumn(column: 'nome', direction: SortDirection.asc)],
          uiModes: [UIMode.grid, UIMode.form, UIMode.map],
          formHookName: 'EditStrutturaForm',
          // La callback onViewModeChanged può essere passata qui se HomeScreen
          // ha bisogno di reagire ai cambi di UI mode del DBGridWidget.
          // onViewModeChanged: (newMode) {
          //   // Questa callback verrebbe chiamata da DBGridWidget
          //   // HomeScreen potrebbe passarla qui per essere notificata
          // }
        );

  @override
  State<StruttureScreen> createState() => _StruttureScreenState();
}

class _StruttureScreenState extends State<StruttureScreen> {
  @override
  Widget build(BuildContext context) {
    // Accedi alla chiave e alla config tramite 'widget.' perché sono membri di StruttureScreen
    return DBGridWidget(
      key: widget.dbGridWidgetStateKey, // Passa la chiave dal widget StruttureScreen
      config: widget.gridConfig,
    );
  }
}
