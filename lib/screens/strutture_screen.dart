// lib/screens/strutture_screen.dart
import 'package:flutter/material.dart';
import 'package:una_social_app/helpers/db_grid.dart'; // DBGridProvider is here

class StruttureScreen extends StatefulWidget implements DBGridProvider {
  // Implement interface
  final GlobalKey<State<DBGridWidget>> dbGridWidgetStateKey = GlobalKey<State<DBGridWidget>>();

  // The field that holds the config
  final DBGridConfig _internalGridConfig;

  StruttureScreen({super.key})
      : _internalGridConfig = DBGridConfig(
          // Initialize the internal field
          dataSourceTable: 'strutture',
          pageLength: 10,
          showHeader: true,
          fixedColumnsCount: 1,
          selectable: true,
          emptyDataMessage: "Nessuna struttura trovata.",
          initialSortBy: [SortColumn(column: 'nome', direction: SortDirection.asc)],
          uiModes: [UIMode.grid, UIMode.form, UIMode.map],
          formHookName: 'EditStrutturaForm',
        );

  // Implement the getter for dbGridWidgetKey from DBGridProvider
  @override
  GlobalKey<State<DBGridWidget>> get dbGridWidgetKey => dbGridWidgetStateKey;

  // Implement the getter for dbGridConfig from DBGridProvider
  @override
  DBGridConfig get dbGridConfig => _internalGridConfig; // Return the internal field

  @override
  State<StruttureScreen> createState() => _StruttureScreenState();
}

class _StruttureScreenState extends State<StruttureScreen> {
  @override
  Widget build(BuildContext context) {
    // Access the key and config via 'widget.'
    // Now widget.dbGridConfig correctly uses the getter.
    return DBGridWidget(
      key: widget.dbGridWidgetKey, // Use the getter for the key
      config: widget.dbGridConfig, // Use the getter for the config
    );
  }
}
