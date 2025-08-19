// colleghi_screen.dart
// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:una_social/helpers/db_grid.dart'; // Import the new DBGridWidget
import 'package:una_social/helpers/logger_helper.dart'; // Assuming logger_helper.dart exists

// Removed the Personale model and ColleaguesDataSource from here
// as DBGridWidget handles generic Map<String, dynamic> data.

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
      appLogger.info('ColleghiScreen: Inizio risoluzione parametri RPC.');

      // --- Step 1: Fetch the structure ID based on its name and entity ---
      appLogger.info('ColleghiScreen: Caricamento ID struttura per "$_targetStrutturaNome"');
      final List<Map<String, dynamic>> structures = await Supabase.instance.client.from('strutture').select('id').eq('ente', _targetEnte).eq('nome', _targetStrutturaNome).limit(1);

      if (structures.isEmpty) {
        _rpcParamsErrorMessage = 'Struttura "$_targetStrutturaNome" non trovata per l\'ente "$_targetEnte".';
        appLogger.error(_rpcParamsErrorMessage!);
      } else {
        final int strutturaId = structures.first['id'] as int;
        appLogger.info('ColleghiScreen: ID struttura trovato: $strutturaId');
        _resolvedRpcParams = {
          'p_ente': _targetEnte,
          'p_struttura_id': strutturaId,
        };
      }
    } catch (e, s) {
      _rpcParamsErrorMessage = 'Errore nel caricamento dei parametri RPC: $e';
      appLogger.error('ColleghiScreen: Errore risoluzione parametri RPC: $e', e, s);
    } finally {
      setState(() {
        _isLoadingRpcParams = false;
        appLogger.info('ColleghiScreen: Fine risoluzione parametri RPC.');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    appLogger.info('ColleghiScreen: build');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Colleghi dell\'Università'),
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
                        child: const Text('Riprova Caricamento Parametri'),
                      ),
                    ],
                  ),
                )
              : Column(
                  // Main Column to hold controls and the DBGridWidget
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Elenco dei Colleghi per $_targetStrutturaNome:',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    Expanded(
                      // DBGridWidget takes the remaining vertical space
                      child: DBGridWidget(
                        config: DBGridConfig(
                          dataSourceTable: 'personale', // Logical table name for identification
                          rpcFunctionName: 'get_colleagues_by_struttura',
                          rpcFunctionParams: _resolvedRpcParams,
                          pageLength: 20, // This might be ignored if RPC returns all data
                          showHeader: true,
                          fixedColumnsCount: 0,
                          selectable: false, // Set to true if you want row selection
                          emptyDataMessage: "Nessun collega trovato per questa struttura.",
                          initialSortBy: const [], // Sorting is handled by the RPC
                          uiModes: const [UIMode.grid], // Only grid view for now
                          primaryKeyColumns: const ['ente', 'id'], // Define primary keys for row identification
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
