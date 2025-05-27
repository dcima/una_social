// lib/controllers/auth_controller.dart (o user_permissions_controller.dart)
// ignore_for_file: avoid_print

import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:una_social_app/helpers/logger_helper.dart'; // Per Supabase client

class AuthController extends GetxController {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Lista osservabile dei gruppi dell'utente
  final RxList<String> userGroups = <String>[].obs;

  // Flag osservabile per indicare se l'utente è super admin
  final RxBool isSuperAdmin = false.obs;

  // Flag per sapere se i gruppi sono stati caricati
  final RxBool isLoadingGroups = false.obs;

  @override
  void onInit() {
    super.onInit();
    // Ascolta i cambiamenti dello stato di autenticazione
    _supabase.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      final Session? session = data.session;

      logInfo('[AuthController] Auth Event: $event');
      if (event == AuthChangeEvent.signedIn) {
        logInfo('[AuthController] User signed in. Session: ${session != null}');
        if (session != null) {
          // Dopo il login, prova a caricare i gruppi dal token e/o dal DB
          _loadUserGroupsFromTokenAndFallback(session.user);
        }
      } else if (event == AuthChangeEvent.signedOut) {
        logInfo('[AuthController] User signed out.');
        clearUserPermissions(); // Pulisci i permessi al logout
      } else if (event == AuthChangeEvent.tokenRefreshed || event == AuthChangeEvent.userUpdated) {
        logInfo('[AuthController] Token refreshed or user updated. Session: ${session != null}');
        if (session != null) {
          _loadUserGroupsFromTokenAndFallback(session.user); // Ricarica i gruppi
        }
      }
    });

    // Carica i gruppi per l'utente corrente all'avvio, se esiste
    final currentUser = _supabase.auth.currentUser;
    if (currentUser != null) {
      _loadUserGroupsFromTokenAndFallback(currentUser);
    }
  }

  /// Prova a caricare i gruppi dal token JWT.
  /// Se non presenti o vuoti, e se non è un tentativo post-RPC,
  /// potrebbe fare una chiamata RPC come fallback (se hai implementato l'Opzione 2).
  Future<void> _loadUserGroupsFromTokenAndFallback(User? user, {bool fromRpcFallback = false}) async {
    if (user == null) {
      clearUserPermissions();
      return;
    }

    isLoadingGroups.value = true;
    List<String> groupsFromToken = [];

    // 1. Prova a leggere da appMetadata
    final dynamic groupsClaim = user.appMetadata['groups'];
    if (groupsClaim != null && groupsClaim is List) {
      try {
        groupsFromToken = List<String>.from(groupsClaim.map((item) => item.toString()));
        logInfo('[AuthController] Groups from token appMetadata: $groupsFromToken');
      } catch (e) {
        logError('[AuthController] Error parsing groups from token appMetadata:', e);
      }
    } else {
      logError('[AuthController] No "groups" claim found in token appMetadata for user ${user.email}. Claim was: $groupsClaim');
    }

    if (groupsFromToken.isNotEmpty) {
      setUserGroups(groupsFromToken);
    } else if (!fromRpcFallback) {
      // Se non ci sono gruppi nel token e NON stiamo già venendo da un fallback RPC,
      // allora prova a chiamare la funzione RPC per ottenere i gruppi.
      // Questo è utile se i trigger del DB hanno aggiornato i metadati
      // ma il token non è ancora stato rinfrescato.
      logWarning('[AuthController] Groups not in token or empty, attempting RPC fallback for user ${user.email}.');
      await fetchUserGroupsViaRpc(user); // Passa l'utente per usare il suo ID
    } else {
      // Se i gruppi non sono nel token E questo era già un tentativo di fallback RPC,
      // allora significa che l'utente probabilmente non ha gruppi.
      // Imposta i gruppi a vuoti.
      logWarning('[AuthController] Groups still not found after RPC fallback for user ${user.email}, or RPC not configured. Setting empty groups.');
      setUserGroups([]); // Assicura che i gruppi siano vuoti
    }
    isLoadingGroups.value = false;
  }

  /// Metodo per caricare i gruppi dell'utente tramite chiamata RPC (Opzione 2 o fallback)
  Future<void> fetchUserGroupsViaRpc(User user) async {
    // Non chiamare se stiamo già caricando per evitare chiamate multiple
    if (isLoadingGroups.value && userGroups.isNotEmpty) return;

    print('[AuthController] Fetching user groups via RPC for user ${user.id}');
    isLoadingGroups.value = true;
    try {
      // Assicurati che la funzione 'get_my_groups' esista e sia SECURITY INVOKER
      // e che l'utente abbia i permessi per chiamarla.
      // Se la funzione prende user_id come parametro:
      // final response = await _supabase.rpc('get_user_groups_by_id', params: {'p_user_id': user.id});
      // Se la funzione usa auth.uid() internamente:
      final response = await _supabase.rpc('get_my_groups');

      if (response != null && response is List) {
        // Supabase rpc può restituire List<dynamic>
        final List<String> fetchedGroups = response
            .map((item) => (item is Map && item.containsKey('group_name')) ? item['group_name'].toString() : null)
            .whereType<String>() // Filtra i null e assicura che siano stringhe
            .toList();
        print('[AuthController] Groups fetched via RPC: $fetchedGroups');
        setUserGroups(fetchedGroups);
      } else if (response == null) {
        print('[AuthController] RPC call "get_my_groups" returned null. User might have no groups.');
        setUserGroups([]); // Nessun gruppo
      } else {
        print('[AuthController] Unexpected response type from RPC "get_my_groups": ${response.runtimeType}. Data: $response');
        // Non fare nulla o imposta gruppi vuoti se l'errore è grave
        // setUserGroups([]);
      }
    } catch (e) {
      print('[AuthController] Error fetching groups via RPC: $e');
      // Considera se impostare i gruppi a vuoti o lasciare lo stato precedente
      // setUserGroups([]); // Potrebbe essere troppo aggressivo
    } finally {
      isLoadingGroups.value = false;
    }
  }

  /// Imposta i gruppi dell'utente e aggiorna isSuperAdmin
  void setUserGroups(List<String> groups) {
    userGroups.assignAll(groups);
    isSuperAdmin.value = groups.contains('SUPER-ADMIN'); // CAMBIA SE IL NOME DEL GRUPPO È DIVERSO
    print('[AuthController] User groups set: ${userGroups.toList()}, Is Super Admin: ${isSuperAdmin.value}');
  }

  /// Pulisce i permessi dell'utente (es. al logout)
  void clearUserPermissions() {
    userGroups.clear();
    isSuperAdmin.value = false;
    isLoadingGroups.value = false;
    print('[AuthController] User permissions cleared.');
  }

  /// Metodo helper sincrono per verificare se l'utente è super admin
  /// DA USARE NEL ROUTER o dove serve una verifica immediata.
  bool checkIsSuperAdminSync() {
    // Se i gruppi non sono ancora stati caricati, potresti voler restituire false
    // o basarti su un valore precedente se accettabile.
    // Per il router, è importante che questo sia veloce.
    // Se isLoadingGroups è true, potrebbe significare che i dati non sono pronti.
    // if (isLoadingGroups.value) return false; // Decisione da prendere in base al tuo flusso
    return isSuperAdmin.value;
  }

  /// Forza un refresh dei permessi, utile dopo che l'utente ha aggiornato la password
  /// o se sospetti che i claims debbano essere ricaricati.
  Future<void> forceRefreshUserPermissions() async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser != null) {
      print('[AuthController] Forcing refresh of user permissions...');
      // Prova prima a rinfrescare la sessione per ottenere un token aggiornato
      try {
        await _supabase.auth.refreshSession();
        print('[AuthController] Session refreshed successfully.');
      } catch (e) {
        print('[AuthController] Error refreshing session: $e');
        // Continua comunque a provare a caricare i gruppi
      }
      // Ricarica i gruppi dal token (che dovrebbe essere aggiornato) o fallback RPC
      await _loadUserGroupsFromTokenAndFallback(_supabase.auth.currentUser, fromRpcFallback: false);
    } else {
      print('[AuthController] Cannot force refresh, no current user.');
      clearUserPermissions();
    }
  }
}
