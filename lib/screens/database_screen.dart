// lib/screens/database_screen.dart
// ignore_for_file: avoid_print, use_build_context_synchronously

import 'dart:convert';
import 'dart:typed_data'; // For Uint8List with file_saver
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:csv/csv.dart'; // For CSV generation
import 'package:file_saver/file_saver.dart';
import 'package:una_social/helpers/snackbar_helper.dart'; // Importa l'helper Snackbar

// Enum for export formats
enum ExportFormat { csv, sql, json }

// Definisci qui le costanti colore se non le importi da un file theme/shared
// const Color primaryBlue = Color(0xFF0028FF); // Esempio, se necessario per Icon

class DatabaseScreen extends StatefulWidget {
  const DatabaseScreen({super.key});

  @override
  State<DatabaseScreen> createState() => _DatabaseScreenState();
}

class _DatabaseScreenState extends State<DatabaseScreen> {
  final supabase = Supabase.instance.client;
  List<String> _tableNames = [];
  bool _isLoadingTables = true;
  String? _errorMessageForUI; // Messaggio di errore da mostrare nella UI

  @override
  void initState() {
    super.initState();
    _fetchTableNames(); // Non chiamare _fetchTableNamesAndShowSnackbar qui direttamente
    // perché initState non dovrebbe contenere chiamate dirette a
    // ScaffoldMessenger se il widget non è ancora completamente costruito
    // e inserito nell'albero.
    // Invece, _fetchTableNames chiamerà la snackbar DOPO che i dati sono stati caricati.
  }

  Future<void> _fetchTableNames() async {
    if (!mounted) return;
    setState(() {
      _isLoadingTables = true;
      _errorMessageForUI = null;
    });

    try {
      final response = await supabase.rpc('get_public_tables');
      if (!mounted) return;

      if (response == null) {
        throw Exception('Chiamata RPC per tabelle ha restituito null');
      }

      final List<dynamic> tableData = response as List<dynamic>;
      final newTableNames = tableData.map((table) => table['table_name'].toString()).toList();

      setState(() {
        _tableNames = newTableNames;
        _isLoadingTables = false;
      });

      // Mostra snackbar di successo DOPO l'aggiornamento dello stato
      // e assicurandosi che il widget sia ancora montato
      if (mounted) {
        SnackbarHelper.showSuccessSnackbar(context, "Lette ${_tableNames.length} tabelle da Supabase");
      }
    } catch (e) {
      final String errorMsg = "Errore in lettura tabelle: ${e.toString()}";
      //print(errorMsg); // Logga l'errore completo
      if (!mounted) return;

      setState(() {
        _errorMessageForUI = "Impossibile caricare le tabelle. Controlla la console per dettagli."; // Messaggio più generico per UI
        _isLoadingTables = false;
        _tableNames = [];
      });

      // Mostra snackbar di errore
      if (mounted) {
        SnackbarHelper.showErrorSnackbar(context, errorMsg);
      }
    }
  }

  Future<void> _exportTable(String tableName, ExportFormat format) async {
    if (!mounted) return;
    SnackbarHelper.showInfoSnackbar(context, 'Preparazione esportazione di "$tableName" come ${format.name.toUpperCase()}...');

    try {
      final List<Map<String, dynamic>> tableData = await supabase.from(tableName).select();
      if (!mounted) return;

      if (tableData.isEmpty) {
        SnackbarHelper.showWarningSnackbar(context, 'La tabella "$tableName" è vuota. Nessun dato da esportare.');
        return;
      }

      String fileContent = '';
      String fileExtension = '';

      switch (format) {
        case ExportFormat.csv:
          fileExtension = 'csv';
          List<List<dynamic>> csvData = [tableData.first.keys.toList()]; // Header
          for (var row in tableData) {
            csvData.add(row.values.map((value) {
              // Gestisci valori null o complessi per CSV in modo più esplicito
              if (value == null) return '';
              if (value is List || value is Map) return jsonEncode(value); // JSON per oggetti complessi in CSV
              return value.toString();
            }).toList());
          }
          fileContent = const ListToCsvConverter().convert(csvData);
          break;
        case ExportFormat.json:
          fileExtension = 'json';
          // Usa JsonEncoder con indentazione per una migliore leggibilità
          const encoder = JsonEncoder.withIndent('  ');
          fileContent = encoder.convert(tableData);
          break;
        case ExportFormat.sql:
          fileExtension = 'sql';
          final StringBuffer sqlBuffer = StringBuffer();
          sqlBuffer.writeln('-- Esportazione SQL per la tabella: $tableName');
          sqlBuffer.writeln('-- Generato il: ${DateTime.now().toIso8601String()}\n');

          final columns = tableData.first.keys.toList();
          final columnsString = columns.map((c) => '"$c"').join(', ');

          for (var row in tableData) {
            final valuesString = columns.map((colName) {
              dynamic value = row[colName];
              if (value == null) return 'NULL';
              if (value is String) return "'${value.replaceAll("'", "''")}'"; // Escape single quotes
              if (value is bool) return value ? 'TRUE' : 'FALSE';
              if (value is DateTime) return "'${value.toIso8601String()}'";
              // Per array o JSONB, assicurati che il casting a jsonb sia corretto
              // o semplicemente serializza come stringa JSON e lascia che il DB lo interpreti.
              if (value is List || value is Map) return "'${jsonEncode(value).replaceAll("'", "''")}'::jsonb";
              if (value is num) return value.toString(); // Numeri non necessitano di apici
              return "'${value.toString().replaceAll("'", "''")}'"; // Fallback per altri tipi
            }).join(', ');
            sqlBuffer.writeln('INSERT INTO "$tableName" ($columnsString) VALUES ($valuesString);');
          }
          fileContent = sqlBuffer.toString();
          break;
      }

      final fileName = '${tableName}_${format.name}_export_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
      final Uint8List bytes = utf8.encode(fileContent);

      await FileSaver.instance.saveFile(
        name: fileName,
        bytes: bytes,
        fileExtension: fileExtension,
        // file_saver inferisce il mimeType dall'estensione, ma puoi specificarlo
        // mimeType: MimeType.OTHER, // o MimeType.CSV, MimeType.JSON, etc.
      );

      if (!mounted) return;
      SnackbarHelper.showSuccessSnackbar(context, '"$tableName" esportato con successo come $fileName!');
    } catch (e) {
      final String errorMsg = 'Errore durante l\'esportazione di "$tableName": ${e.toString()}';
      //print("$errorMsg\nStackTrace: $stackTrace");
      if (!mounted) return;
      SnackbarHelper.showErrorSnackbar(context, errorMsg);
    }
  }

  Widget buildCard(BuildContext context, String tableName) {
    // Costruisce una Card per ogni tabella
    // Puoi personalizzare ulteriormente l'aspetto della Card qui
    // Ad esempio, aggiungendo un'icona o un'azione specifica per la tabella

    // Se vuoi mostrare il numero di righe, puoi passarlo come parametro o calcolarlo in anticipo
    // Per ora, usiamo una stringa fittizia per il conteggio delle righe
    // final rowCount = _tableNames.length; // Supponiamo che ogni tabella abbia lo stesso numero di righe
    return GestureDetector(
      child: Card(
        elevation: 2,
        margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
        child: ListTile(
          leading: Icon(Icons.table_rows_outlined, color: Theme.of(context).colorScheme.primary),
          title: Text(tableName, style: const TextStyle(fontWeight: FontWeight.w500)),
          trailing: PopupMenuButton<ExportFormat>(
            icon: Icon(Icons.file_download_outlined, color: Theme.of(context).colorScheme.secondary),
            tooltip: 'Opzioni di Esportazione per $tableName',
            onSelected: (ExportFormat format) {
              _exportTable(tableName, format);
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<ExportFormat>>[
              PopupMenuItem<ExportFormat>(
                value: ExportFormat.csv,
                child: Row(children: [const Icon(Icons.grid_on_sharp, size: 20), const SizedBox(width: 10), Text('CSV (${_tableNames.length} righe)')]),
              ),
              PopupMenuItem<ExportFormat>(
                value: ExportFormat.json,
                child: Row(children: [const Icon(Icons.data_object_rounded, size: 20), const SizedBox(width: 10), Text('JSON (${_tableNames.length} righe)')]),
              ),
              PopupMenuItem<ExportFormat>(
                value: ExportFormat.sql,
                child: Row(children: [const Icon(Icons.code_rounded, size: 20), const SizedBox(width: 10), Text('SQL (INSERTs, ${_tableNames.length} righe)')]),
              ),
            ],
          ),
          onTap: () {
            // Potresti aggiungere un'azione qui, tipo navigare a una vista dettagliata della tabella
            //print("Selezionata tabella: $tableName");
            SnackbarHelper.showInfoSnackbar(context, "Un tap selezionata tabella: $tableName, doppio tap per aprire tabella e gestione. Usa il menu per esportare.");
          },
        ),
      ),
      onDoubleTap: () {
        GoRouter.of(context).go('/app/$tableName');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingTables) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessageForUI != null && _tableNames.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(
                'Errore Caricamento Tabelle',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.red),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessageForUI!, // Messaggio più generico per la UI
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Riprova'),
                onPressed: _fetchTableNames,
                style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Theme.of(context).colorScheme.onPrimary),
              )
            ],
          ),
        ),
      );
    }

    if (!_isLoadingTables && _tableNames.isEmpty && _errorMessageForUI == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.info_outline, color: Colors.blueGrey, size: 48),
              const SizedBox(height: 16),
              Text(
                'Nessuna Tabella Trovata',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Non ci sono tabelle nello schema "public" o non è stato possibile caricarle.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Ricarica'),
                onPressed: _fetchTableNames,
              ),
            ],
          ),
        ),
      );
    }

    // Corpo principale con la lista delle tabelle
    return RefreshIndicator(
      onRefresh: _fetchTableNames, // Aggiunge pull-to-refresh
      child: ListView.separated(
        padding: const EdgeInsets.all(8.0),
        itemCount: _tableNames.length,
        itemBuilder: (context, index) {
          final tableName = _tableNames[index];
          return buildCard(context, tableName);
        },
        separatorBuilder: (context, index) => const SizedBox(height: 0), // Nessun separatore visibile tra le Card
      ),
    );
  }
}
