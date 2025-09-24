import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:una_social/controllers/auth_controller.dart';
import 'package:una_social/controllers/personale_controller.dart';
import 'package:una_social/controllers/ui_controller.dart'; // NUOVO IMPORT
import 'package:una_social/helpers/db_grid.dart';
import 'package:una_social/helpers/logger_helper.dart';
import 'package:una_social/helpers/snackbar_helper.dart';

class ColleghiScreen extends StatefulWidget {
  const ColleghiScreen({super.key});

  @override
  State<ColleghiScreen> createState() => _ColleghiScreenState();
}

class _ColleghiScreenState extends State<ColleghiScreen> {
  String? dataSourceTable;
  bool isLoading = true;
  final AuthController authController = Get.find<AuthController>();
  final UiController uiController = Get.find<UiController>(); // NUOVO: Ottieni UiController

  final List<GridColumn> columns = [
    GridColumn(
      columnName: 'photo_url',
      columnWidthMode: ColumnWidthMode.fitByColumnName,
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
    appLogger.info('ColleghiScreen initState');
    // Imposta un titolo temporaneo mentre si carica
    uiController.setCurrentScreenName('Colleghi: Caricamento...');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (Supabase.instance.client.auth.currentSession != null) {
        _getStructureAndColleagues();
      } else {
        if (mounted) {
          setState(() {
            dataSourceTable = 'colleghi';
            isLoading = false;
          });
          uiController.setCurrentScreenName('Colleghi'); // Titolo di fallback
        }
      }
    });
  }

  Future<void> _getStructureAndColleagues() async {
    appLogger.info('_getStructureAndColleagues: $authController.isPersonale');

    if (!authController.isPersonale) {
      if (mounted) SnackbarHelper.showErrorSnackbar(context, 'L\'utente autenticato non è personale universitario.');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
        uiController.setCurrentScreenName('Colleghi: Errore Ruolo');
      }
      return;
    }

    final personaleController = Get.find<PersonaleController>();
    final personale = personaleController.personale.value;
    if (personale?.struttura == null || personale?.ente == null) {
      if (mounted) SnackbarHelper.showErrorSnackbar(context, 'Struttura o ente del personale non disponibile.');
      if (mounted) {
        setState(() {
          dataSourceTable = 'colleghi';
          isLoading = false;
        });
        uiController.setCurrentScreenName('Colleghi: Errore Dati');
      }
      return;
    }

    String? strutturaNome; // Variabile per contenere il nome della struttura
    String screenName;
    try {
      // NUOVO: Recupera il nome della struttura dalla tabella public.strutture
      final structureResult = await Supabase.instance.client.from('strutture').select('nome').eq('ente', personale!.ente).eq('id', personale.struttura).single();

      strutturaNome = structureResult['nome'] as String?;
      appLogger.info('Nome Struttura recuperato: $strutturaNome');

      // La chiamata RPC viene gestita dal DBGridWidget
      // Non è necessario chiamare direttamente l'RPC qui per i dati della griglia.
      // Il `dataSourceTable` è solo un nome descrittivo quando si usa `rpcFunctionName`.
      if (mounted) {
        setState(() {
          dataSourceTable = 'colleghi'; // Questo può essere un valore fisso o descrittivo
          isLoading = false;
        });
        // Aggiorna il titolo con il nome della struttura recuperato
        if (strutturaNome != null) {
          screenName = 'Colleghi: $strutturaNome';
        } else {
          screenName = 'Colleghi: Struttura Sconosciuta';
        }
        appLogger.info('Screenname: $screenName');
        uiController.setCurrentScreenName(screenName);
      }
    } catch (e) {
      appLogger.error('Errore nel recupero del nome della struttura: $e');
      if (mounted) SnackbarHelper.showErrorSnackbar(context, 'Errore nel caricamento del nome della struttura: $e');
      if (mounted) {
        setState(() {
          dataSourceTable = 'colleghi';
          isLoading = false;
        });
        uiController.setCurrentScreenName('Colleghi: Errore'); // Imposta un titolo di errore
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    appLogger.info('ColleghiScreen build: isLoading=$isLoading, dataSourceTable=$dataSourceTable');

    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Assicurati che `personale` e `struttura` siano disponibili prima di costruire DBGridConfig
    final personaleController = Get.find<PersonaleController>();
    final personale = personaleController.personale.value;

    if (personale == null) {
      return Scaffold(
        body: Center(child: Text('Errore: Dati del personale non disponibili per caricare i colleghi.')),
      );
    }

    final dbGridConfig = DBGridConfig(
      columns: columns,
      dataSourceTable: dataSourceTable!, // Userà 'colleghi' come nome logico
      emptyDataMessage: "Nessun collega trovato per questa struttura.",
      excludeColumns: ['ente', 'struttura'],
      fixedColumnsCount: 2,
      initialSortBy: [
        SortColumn(column: 'cognome', direction: SortDirection.asc), // Ordinamento semplificato
      ],
      pageLength: 50,
      // Le colonne della chiave primaria devono identificare in modo univoco una riga
      primaryKeyColumns: ['ente', 'struttura', 'email_principale'],
      rpcFunctionName: 'get_colleagues_by_struttura', // Usa la funzione RPC
      rpcFunctionParams: {
        // Questi parametri fissi vengono passati alla funzione RPC ad ogni chiamata
        'p_ente': personale.ente,
        'p_struttura_id': personale.struttura,
      },
      selectable: true,
      showHeader: true,
      uiModes: const [UIMode.grid],
    );

    return Scaffold(
      body: DBGridWidget(config: dbGridConfig),
    );
  }
}
