// lib/controllers/auth_controller.dart
import 'dart:async'; // Importa async per Completer

import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:una_social/helpers/logger_helper.dart';

class AuthController extends GetxController {
  final SupabaseClient _supabase = Supabase.instance.client;

  // --- STATI OSSERVABILI ---
  final RxList<String> userGroups = <String>[].obs;
  final Rxn<bool> isSuperAdmin = Rxn<bool>(); // null = sconosciuto/in caricamento
  final RxBool isLoadingPermissions = false.obs;

  // Aggiungiamo un Completer per gestire la prima richiesta di caricamento
  // e prevenire race conditions.
  Completer<void>? _permissionsCompleter;

  @override
  void onInit() {
    super.onInit();
    // Ascolta i cambiamenti dello stato di autenticazione per ricaricare i permessi.
    _supabase.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      logInfo('[AuthController] Auth Event: $event');

      if (event == AuthChangeEvent.signedIn || event == AuthChangeEvent.tokenRefreshed || event == AuthChangeEvent.userUpdated) {
        logInfo('[AuthController] Utente autenticato o sessione aggiornata. Caricamento permessi...');
        loadPermissions();
      } else if (event == AuthChangeEvent.signedOut) {
        logInfo('[AuthController] Utente disconnesso.');
        clearUserPermissions();
      }
    });

    // All'avvio, se c'è già un utente, carica i suoi permessi.
    if (_supabase.auth.currentUser != null) {
      loadPermissions();
    }
  }

  /// Metodo principale per caricare tutti i permessi dell'utente (Super Admin + Gruppi).
  /// Gestisce la concorrenza per evitare chiamate multiple.
  Future<void> loadPermissions() async {
    // Se un caricamento è già in corso, attendi il suo completamento invece di avviarne un altro.
    if (isLoadingPermissions.value) {
      logInfo('[AuthController] Caricamento permessi già in corso, attesa...');
      return _permissionsCompleter?.future;
    }

    if (_supabase.auth.currentUser == null) {
      clearUserPermissions();
      return;
    }

    isLoadingPermissions.value = true;
    _permissionsCompleter = Completer<void>(); // Crea un nuovo completer per questa sessione di caricamento.
    logInfo('[AuthController] Avvio caricamento permessi utente...');

    try {
      // Eseguiamo le chiamate per lo stato di admin e per i gruppi in parallelo per efficienza.
      final results = await Future.wait([
        _fetchSuperAdminStatus(),
        _fetchUserGroups(),
      ]);

      final bool adminStatus = results[0] as bool;
      final List<String> groups = results[1] as List<String>;

      // Aggiorna gli stati osservabili con i nuovi valori.
      isSuperAdmin.value = adminStatus;
      userGroups.assignAll(groups);

      logInfo('[AuthController] Permessi caricati. IsSuperAdmin: $adminStatus, Groups: $groups');
    } catch (e) {
      logError('[AuthController] Errore durante il caricamento dei permessi: $e');
      // In caso di errore, per sicurezza, impostiamo i permessi a un livello non privilegiato.
      isSuperAdmin.value = false;
      userGroups.clear();
    } finally {
      isLoadingPermissions.value = false;
      // Segnala a chiunque fosse in attesa che il caricamento è finito,
      // solo se il completer non è già stato completato (per sicurezza).
      if (!(_permissionsCompleter?.isCompleted ?? true)) {
        _permissionsCompleter!.complete();
      }
    }
  }

  /// Funzione interna per chiamare la RPC e ottenere lo stato di Super Admin.
  Future<bool> _fetchSuperAdminStatus() async {
    try {
      logInfo("[AuthController] Chiamata RPC 'get_current_user_is_super_admin'...");
      final dynamic response = await _supabase.rpc('get_current_user_is_super_admin');

      if (response is bool) {
        return response;
      }

      logError("[AuthController] Risposta inattesa da 'get_current_user_is_super_admin': ${response.runtimeType}");
      return false; // Valore di default sicuro
    } catch (e) {
      logError("[AuthController] Errore in _fetchSuperAdminStatus: $e");
      return false; // Valore di default sicuro
    }
  }

  /// Funzione interna per chiamare la RPC e ottenere i gruppi dell'utente.
  Future<List<String>> _fetchUserGroups() async {
    try {
      logInfo("[AuthController] Chiamata RPC 'get_my_groups'...");
      final response = await _supabase.rpc('get_my_groups'); // Assicurati che esista

      if (response is List) {
        // Converte in sicurezza la lista dinamica in una lista di stringhe.
        return response.map((item) => item.toString()).toList();
      }

      logWarning("[AuthController] Risposta inattesa da 'get_my_groups': ${response.runtimeType}");
      return []; // Valore di default
    } catch (e) {
      // Se la funzione 'get_my_groups' non esiste, questo errore verrà sollevato.
      // È sicuro ignorarlo se non prevedi di usare i gruppi.
      logWarning("[AuthController] Errore in _fetchUserGroups (potrebbe essere normale se non usi i gruppi): $e");
      return []; // Valore di default
    }
  }

  /// Pulisce tutti i permessi dell'utente, solitamente chiamato al logout.
  void clearUserPermissions() {
    userGroups.clear();
    isSuperAdmin.value = null; // Resetta allo stato "sconosciuto"
    isLoadingPermissions.value = false;
    _permissionsCompleter = null; // Pulisci anche il completer
    logInfo('[AuthController] Permessi utente puliti.');
  }

  /// Funzione ASINCRONA e ROBUSTA per il router.
  /// Attende il caricamento dei permessi se non sono ancora pronti.
  Future<bool> checkIsSuperAdmin() async {
    // Se un caricamento è in corso, attendi che finisca.
    if (isLoadingPermissions.value) {
      logInfo('[AuthController] Controllo richiesto mentre i permessi sono in caricamento. In attesa...');
      await _permissionsCompleter?.future;
    }
    // Se i permessi non sono mai stati caricati (stato iniziale null), avvia il caricamento e attendi.
    else if (isSuperAdmin.value == null) {
      logInfo('[AuthController] Stato Super Admin non in cache, avvio caricamento e attesa...');
      await loadPermissions();
    }

    // Ora isSuperAdmin.value è sicuramente non-null (o true o false).
    logInfo('[AuthController] Controllo Super Admin completato. Risultato: ${isSuperAdmin.value ?? false}');
    return isSuperAdmin.value ?? false;
  }
}
