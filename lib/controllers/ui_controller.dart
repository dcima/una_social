import 'package:get/get.dart';
import 'package:flutter/material.dart'; // Needed for IconData, if you want icons
import 'package:supabase_flutter/supabase_flutter.dart'; // Importa Supabase
import 'package:una_social/helpers/logger_helper.dart'; // Per il logging

class BreadcrumbItem {
  final String title;
  final String path;
  final IconData? icon; // Optional: for displaying an icon with the breadcrumb

  BreadcrumbItem({required this.title, required this.path, this.icon});

  @override
  String toString() => 'BreadcrumbItem(title: $title, path: $path)';

  @override
  bool operator ==(Object other) => identical(this, other) || other is BreadcrumbItem && runtimeType == other.runtimeType && title == other.title && path == other.path;

  @override
  int get hashCode => title.hashCode ^ path.hashCode;
}

class UiController extends GetxController {
  final RxString currentScreenName = 'Home'.obs;
  final RxList<BreadcrumbItem> breadcrumbs = <BreadcrumbItem>[].obs;

  // Nuove variabili per la gestione delle tabelle del database
  final RxList<String> tableNames = <String>[].obs;
  final RxBool isLoadingTables = false.obs;
  final RxString errorMessageForDBTables = RxString('');

  final supabase = Supabase.instance.client; // Accedi al client Supabase

  void updateCurrentScreenName(String name) {
    appLogger.info("UiController: Updating current screen name to $name");

    currentScreenName.value = name;
  }

  void updateBreadcrumbs(List<BreadcrumbItem> newBreadcrumbs) {
    appLogger.info("UiController: Updating breadcrumbs to $newBreadcrumbs");

    // 1. Controlla se la lista dei breadcrumbs è effettivamente cambiata
    //    Usiamo un confronto basato sul contenuto (elementi e ordine)
    bool breadcrumbsChanged = false;

    if (breadcrumbs.length != newBreadcrumbs.length) {
      breadcrumbsChanged = true;
    } else {
      for (int i = 0; i < breadcrumbs.length; i++) {
        if (breadcrumbs[i] != newBreadcrumbs[i]) {
          // Richiede che BreadcrumbItem abbia un operatore == e hashCode ben definiti
          breadcrumbsChanged = true;
          break;
        }
      }
    }

    if (breadcrumbsChanged) {
      breadcrumbs.assignAll(newBreadcrumbs);
      appLogger.info("UiController: Breadcrumbs updated to $newBreadcrumbs");
    } else {
      appLogger.info("UiController: Breadcrumbs are identical, skipping update.");
    }

    // 2. Controlla se il nome della schermata corrente è effettivamente cambiato
    String newScreenTitle;
    if (newBreadcrumbs.isNotEmpty) {
      newScreenTitle = newBreadcrumbs.last.title;
    } else {
      newScreenTitle = 'Home';
    }

    if (currentScreenName.value != newScreenTitle) {
      currentScreenName.value = newScreenTitle;
      appLogger.info("UiController: Current screen name updated to $newScreenTitle");
    } else {
      appLogger.info("UiController: Current screen name is identical, skipping update.");
    }
  }

  // Metodo per recuperare i nomi delle tabelle una sola volta per sessione
  // Aggiunto parametro 'force' per forzare il ricaricamento
  Future<void> fetchTableNamesOnce({bool force = false}) async {
    appLogger.info("UiController: fetchTableNamesOnce called with force=$force");

    if (!force && (tableNames.isNotEmpty || isLoadingTables.value)) {
      appLogger.info("UiController: Nomi tabelle già caricati o in corso di caricamento e non forzato. Saltando il fetch.");
      return;
    }

    isLoadingTables.value = true; // Inizia il caricamento
    errorMessageForDBTables.value = '';
    tableNames.clear(); // Pulisci i dati precedenti prima di un nuovo tentativo di fetch

    appLogger.info("UiController: Avvio caricamento nomi tabelle da Supabase (force: $force)...");

    try {
      final response = await supabase.rpc('get_public_tables');

      if (response == null) {
        throw Exception('Chiamata RPC per tabelle ha restituito null');
      }

      final List<dynamic> tableData = response as List<dynamic>;
      final newTableNames = tableData.map((table) => table['table_name'].toString()).toList();

      tableNames.assignAll(newTableNames);
      appLogger.info("UiController: Caricate ${tableNames.length} tabelle da Supabase.");
    } catch (e) {
      final String errorMsg = "Errore in caricamento tabelle: ${e.toString()}";
      appLogger.error(errorMsg);
      errorMessageForDBTables.value = "Impossibile caricare le tabelle. Controlla la console per dettagli.";
      tableNames.clear(); // Svuota per indicare che non ci sono dati validi
    } finally {
      isLoadingTables.value = false; // Termina il caricamento
    }
  }

  static String _capitalize(String s) => s.isNotEmpty ? s[0].toUpperCase() + s.substring(1).replaceAll('_', ' ') : '';

  static List<BreadcrumbItem> buildBreadcrumbsFromPath(String fullPath) {
    appLogger.info("UiController: buildBreadcrumbsFromPath called with path: $fullPath");

    final List<BreadcrumbItem> items = [];
    final cleanPath = Uri.parse(fullPath).path;
    final normalizedPath = cleanPath.startsWith('/') ? cleanPath : '/$cleanPath';
    final trimmedPath = normalizedPath.endsWith('/') && normalizedPath != '/' ? normalizedPath.substring(0, normalizedPath.length - 1) : normalizedPath;

    if (!trimmedPath.startsWith('/app')) {
      return [];
    }

    items.add(BreadcrumbItem(title: 'Home', path: '/app/home', icon: Icons.home_outlined));

    final appPath = '/app';
    if (trimmedPath.length <= appPath.length) {
      return items;
    }

    String remainingPath = trimmedPath.substring(appPath.length);
    final segments = remainingPath.split('/').where((s) => s.isNotEmpty).toList();

    String currentPathAccumulator = appPath;

    for (int i = 0; i < segments.length; i++) {
      final segment = segments[i];
      currentPathAccumulator += '/$segment';
      String title = _capitalize(segment);
      IconData? icon;

      if (segment == 'database') {
        title = 'Database';
        icon = Icons.storage_outlined; // Icona aggiornata per Database
      } else if (segment == 'chat') {
        title = 'Chat';
        icon = Icons.chat;
      } else if (segment == 'ambiti') {
        title = 'Ambiti';
        icon = Icons.category;
      } else if (segment == 'import-contacts') {
        title = 'Importa Contatti';
        icon = Icons.person_add_alt_1_outlined;
      } else if (segment == 'colleghi') {
        title = 'Colleghi';
        icon = Icons.groups_outlined;
      } else if (currentPathAccumulator.startsWith('/app/database/')) {
        // Gestione dinamica per le tabelle del database
        // Esempio di personalizzazione per nomi di tabelle comuni
        switch (segment.toLowerCase()) {
          case 'strutture':
            title = 'Strutture';
            icon = Icons.business_outlined;
            break;
          case 'enti':
            title = 'Enti';
            icon = Icons.corporate_fare_outlined;
            break;
          case 'profili':
            title = 'Profili Personali'; // Più specifico
            icon = Icons.person_outlined; // Icona per profilo personale
            break;
          case 'campus':
            title = 'Campus';
            icon = Icons.location_city_outlined; // Icona per campus
            break;
          case 'lauree': // Esempio
            title = 'Lauree';
            icon = Icons.school_outlined; // Icona per laurea
            break;
          case 'relazioni': // Esempio
            title = 'Relazioni';
            icon = Icons.handshake_outlined; // Icona per relazioni professionali
            break;
          case 'settori_scientifico_disciplinari': // Esempio
            title = 'Settori Scientifico Disciplinari';
            icon = Icons.subject_outlined; // Icona per SSD
            break;
          default:
            title = _capitalize(segment); // Capitalizza il nome della tabella
            icon = Icons.table_chart_outlined; // Icona generica per tabella
            break;
        }
      }
      // Aggiungi altri titoli/icone personalizzate qui

      if (currentPathAccumulator == '/app/home') {
        continue;
      }

      items.add(BreadcrumbItem(title: title, path: currentPathAccumulator, icon: icon));
    }

    final uniqueItems = <BreadcrumbItem>[];
    final seenPaths = <String>{};
    for (var item in items) {
      if (!seenPaths.contains(item.path)) {
        uniqueItems.add(item);
        seenPaths.add(item.path);
      }
    }

    return uniqueItems;
  }
}
