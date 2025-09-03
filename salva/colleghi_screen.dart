// colleghi_screen.dart
// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:una_social/helpers/db_grid.dart'; // Import the new DBGridWidget
import 'package:una_social/helpers/logger_helper.dart'; // Assuming logger_helper.dart exists

class ColleghiScreen extends StatefulWidget {
  const ColleghiScreen({super.key});

  @override
  State<ColleghiScreen> createState() => _ColleghiScreenState();
}

class _ColleghiScreenState extends State<ColleghiScreen> {
  // State variables to hold RPC parameters
  bool _isLoadingRpcParams = true;
  String? _rpcParamsErrorMessage;
  Map<String, dynamic>? _resolvedRpcParams;

  // Define the target entity and structure name
  final String _targetEnte = 'UNIBO';
  final String _targetStrutturaNome = 'Dipartimento di Scienze Statistiche "Paolo Fortunati"';

  final List<GridColumn> columns = [
    GridColumn(
      columnName: 'photo_url',
      columnWidthMode: ColumnWidthMode.fill,
      label: const Text('Foto'),
    ),
    GridColumn(
      columnWidthMode: ColumnWidthMode.fill,
      columnName: 'cognome',
      label: const Text('Cognome'),
    ),
    GridColumn(
      columnName: 'nome',
      columnWidthMode: ColumnWidthMode.fill,
      label: const Text('Nome'),
    ),
    GridColumn(
      columnName: 'email_principale',
      columnWidthMode: ColumnWidthMode.fill,
      label: const Text('Email'),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _resolveRpcParameters();
  }

  /// Fetches the necessary parameters for the RPC call.
  /// This is specific to ColleghiScreen as DBGridWidget is generic.
  Future<void> _resolveRpcParameters() async {
    setState(() {
      _isLoadingRpcParams = true;
      _rpcParamsErrorMessage = null;
    });
    try {
      appLogger.info('ColleghiScreen: Starting RPC parameter resolution.');

      // --- Step 1: Fetch the structure ID based on its name and entity ---
      appLogger.info('ColleghiScreen: Loading structure ID for "$_targetStrutturaNome"');
      final List<Map<String, dynamic>> structures = await Supabase.instance.client.from('strutture').select('id').eq('ente', _targetEnte).eq('nome', _targetStrutturaNome).limit(1);

      if (structures.isEmpty) {
        _rpcParamsErrorMessage = 'Structure "$_targetStrutturaNome" not found for entity "$_targetEnte".';
        appLogger.error(_rpcParamsErrorMessage!);
      } else {
        final int strutturaId = structures.first['id'] as int;
        appLogger.info('ColleghiScreen: Structure ID found: $strutturaId');
        _resolvedRpcParams = {
          'p_ente': _targetEnte,
          'p_struttura_id': strutturaId,
        };
      }
    } catch (e, s) {
      _rpcParamsErrorMessage = 'Error loading RPC parameters: $e';
      appLogger.error('ColleghiScreen: Error resolving RPC parameters: $e', e, s);
    } finally {
      setState(() {
        _isLoadingRpcParams = false;
        appLogger.info('ColleghiScreen: Finished RPC parameter resolution.');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    appLogger.info('ColleghiScreen: build');

    return Scaffold(
      appBar: AppBar(
        // Added AppBar back for consistency with image
        title: const Text('Colleghi'), // Assuming the title is just "Colleghi" as in the image
      ),
      body: _isLoadingRpcParams
          ? const Center(child: CircularProgressIndicator())
          : _rpcParamsErrorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _rpcParamsErrorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red, fontSize: 16),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _resolveRpcParameters,
                        child: const Text('Retry Parameter Loading'),
                      ),
                    ],
                  ),
                )
              : Column(
                  // Main Column to hold controls and the DBGridWidget
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0), // Changed to const
                      child: Text(
                        'List of Colleagues for $_targetStrutturaNome:',
                        style: Theme.of(context).textTheme.labelMedium, // Changed back to labelMedium
                      ),
                    ),
                    Expanded(
                      // DBGridWidget takes the remaining vertical space
                      child: DBGridWidget(
                        config: DBGridConfig(
                          columns: columns,
                          dataSourceTable: 'colleghi', // Logical table name for identification
                          emptyDataMessage: "Nessun collega trovato per l'ente $_targetEnte e la struttura $_targetStrutturaNome.",
                          excludeColumns: const ['ente', 'struttura', 'telefoni', 'ruoli', 'altre_emails'], // UPDATED: Exclude these columns from display
                          fixedColumnsCount: 2,
                          initialSortBy: const [], // Sorting is handled by the RPC
                          pageLength: 10, // Page length is now used by the RPC
                          primaryKeyColumns: const ['ente', 'struttura', 'email_principale'], // Define primary keys for row identification
                          rpcFunctionName: 'get_colleagues_by_struttura',
                          rpcFunctionParams: _resolvedRpcParams,
                          selectable: true, // Set to true if you want row selection
                          showHeader: true,
                          uiModes: const [UIMode.grid], // Only grid view for now
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
