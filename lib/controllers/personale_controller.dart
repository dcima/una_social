// controller: personale_controller.dart
// ignore_for_file: avoid_print, non_constant_identifier_names

import 'dart:async'; // Aggiunto per Timer se necessario in futuro, per ora non usato.

import 'package:get/get_rx/src/rx_types/rx_types.dart';
import 'package:get/get_state_manager/src/simple/get_controllers.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:una_social_app/helpers/logger_helper.dart';
import 'package:una_social_app/models/personale.dart';
// È buona pratica importare i tipi specifici se li si usa esplicitamente,
// anche se supabase_flutter potrebbe riesportarli.
// Ad esempio, se si fa riferimento a `Presence` nel codice:
// import 'package:realtime_client/src/types.dart' show Presence; // Percorso effettivo potrebbe variare

class PersonaleController extends GetxController {
  final supabase = Supabase.instance.client;
  var personale = Rxn<Personale>();
  var connectedUsers = 0.obs;
  var appVersion = ''.obs;
  var message = ''.obs;

  RealtimeChannel? _onlineUsersChannel;
  bool _isPresenceChannelReady = false;

  // Manteniamo _activeUserIds, popolato da JOIN/LEAVE.
  // L'evento SYNC tenterà di riconciliare questo set con lo stato completo da presenceState().
  final Set<String> _activeUserIds = {};

  @override
  void onInit() {
    logInfo('PersonaleController: onInit()');
    super.onInit();
    _loadUserData().then((_) {
      if (supabase.auth.currentUser != null) {
        _subscribeToOnlineUsers();
      } else {
        logInfo("PersonaleController.onInit: Utente non loggato, non mi iscrivo a presence.");
      }
    });
    _loadAppVersion();

    supabase.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      logInfo("PersonaleController.onAuthStateChange: Evento $event");
      if (event == AuthChangeEvent.signedIn) {
        _activeUserIds.clear(); // Pulisci ID attivi per nuovo login
        if (personale.value == null) {
          // Evita caricamenti ridondanti se dati già presenti
          _loadUserData().then((_) {
            if (supabase.auth.currentUser != null) _subscribeToOnlineUsers();
          });
        } else {
          if (supabase.auth.currentUser != null) _subscribeToOnlineUsers();
        }
      } else if (event == AuthChangeEvent.signedOut) {
        _unsubscribeFromOnlineUsers(); // Questo pulirà _activeUserIds e aggiornerà il contatore
        personale.value = null;
        message.value = 'Utente disconnesso.';
      }
    });
  }

  @override
  void onClose() {
    logInfo('PersonaleController: onClose()');
    _unsubscribeFromOnlineUsers();
    super.onClose();
  }

  void _subscribeToOnlineUsers() {
    logInfo('PersonaleController: _subscribeToOnlineUsers()');
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      logInfo("  AUTH: Utente non autenticato, impossibile iscriversi.");
      _isPresenceChannelReady = false;
      _activeUserIds.clear();
      _updateConnectedUsersCountFromSet(); // Aggiorna il contatore (a 0)
      return;
    }

    // Se il canale esiste già e il flag indica che è pronto, non fare nulla se non un log e un potenziale refresh.
    if (_onlineUsersChannel != null && _isPresenceChannelReady) {
      logInfo("  CANALE: Già sottoscritto e PRONTO. Stampo stato attuale e tento riconciliazione.");
      _debugPrintFullPresenceState();
      _reconcileActiveUserIdsFromListSinglePresenceState(); // Assicura coerenza
      // _updateConnectedUsersCountFromSet(); // reconcile... chiama già update...
      return;
    }

    // Se il canale esiste ma non è pronto (es. _isPresenceChannelReady è false),
    // è meglio rimuoverlo e ricrearlo per garantire uno stato pulito.
    if (_onlineUsersChannel != null && !_isPresenceChannelReady) {
      logInfo("  CANALE: Esistente ma non pronto. Rimuovo e ricreo.");
      supabase.removeChannel(_onlineUsersChannel!); // Non serve await
      _onlineUsersChannel = null;
    }

    logInfo("  CANALE: Creazione e sottoscrizione a 'online-users'.");
    _isPresenceChannelReady = false;
    _activeUserIds.clear(); // Pulisci prima di una nuova sottoscrizione
    _onlineUsersChannel = supabase.channel(
      'online-users',
      opts: const RealtimeChannelConfig(ack: true, self: true), // self:true è importante
    );

    _onlineUsersChannel!.onPresenceSync((payload) {
      // payload qui è RealtimePresenceSyncPayload
      logInfo('  EVENTO: Presence SYNC ricevuto.');
      if (!_isPresenceChannelReady) {
        logInfo("    CANALE: Canale PRONTO dopo SYNC.");
        _isPresenceChannelReady = true;
      }
      // Al SYNC, tentiamo di riconciliare _activeUserIds con lo stato completo.
      _reconcileActiveUserIdsFromListSinglePresenceState();
      _debugPrintFullPresenceState(); // Stampa lo stato per investigazione
    }).onPresenceJoin((payload) {
      // payload è RealtimePresenceJoinPayload
      logInfo('  EVENTO: Presence JOIN. Nuove presenze: ${payload.newPresences.length}');
      bool changed = false;
      for (final Presence newPresence in payload.newPresences) {
        // payload.newPresences è List<Presence>
        final pLoad = newPresence.payload; // Presence.payload è Map<String, dynamic>
        if (pLoad.containsKey('user_id') && pLoad['user_id'] is String) {
          final newUserId = pLoad['user_id'] as String;
          if (newUserId.isNotEmpty && _activeUserIds.add(newUserId)) {
            changed = true; // Aggiunto nuovo ID
          }
        }
      }
      if (!_isPresenceChannelReady && payload.newPresences.isNotEmpty) {
        logInfo("    CANALE: Canale PRONTO dopo JOIN con dati.");
        _isPresenceChannelReady = true;
      }
      if (changed) _updateConnectedUsersCountFromSet();
    }).onPresenceLeave((payload) {
      // payload è RealtimePresenceLeavePayload
      logInfo('  EVENTO: Presence LEAVE. Uscite: ${payload.leftPresences.length}');
      bool changed = false;
      for (final Presence leftPresence in payload.leftPresences) {
        // payload.leftPresences è List<Presence>
        final pLoad = leftPresence.payload; // Presence.payload
        if (pLoad.containsKey('user_id') && pLoad['user_id'] is String) {
          final oldUserId = pLoad['user_id'] as String;
          if (oldUserId.isNotEmpty && _activeUserIds.remove(oldUserId)) {
            changed = true; // Rimosso ID
          }
        }
      }
      if (changed) _updateConnectedUsersCountFromSet();
    });

    _onlineUsersChannel!.subscribe((status, [error]) async {
      logInfo("  CANALE: Stato sottoscrizione 'online-users': $status.");
      if (status == RealtimeSubscribeStatus.subscribed) {
        logInfo('    CANALE: Sottoscrizione avvenuta. Traccio presenza...');
        try {
          await _onlineUsersChannel!.track({
            'user_id': userId, // userId è garantito non nullo qui
            'online_at': DateTime.now().toIso8601String(),
          });
          logInfo('    CANALE: Presenza utente (ID: $userId) tracciata.');
          // L'evento JOIN per 'self' (dovuto a self:true) popolerà _activeUserIds.
        } catch (e) {
          logInfo('    CANALE ERRORE track: $e\n');
          _isPresenceChannelReady = false; // Se track fallisce, il canale potrebbe essere instabile
        }
      } else if (status == RealtimeSubscribeStatus.channelError || status == RealtimeSubscribeStatus.timedOut) {
        logInfo('    CANALE ERRORE sottoscrizione: $error, status: $status.');
        message.value = 'Errore Realtime: $error';
        _isPresenceChannelReady = false;
        _activeUserIds.clear();
        _updateConnectedUsersCountFromSet();
      } else if (status == RealtimeSubscribeStatus.closed) {
        logInfo('    CANALE: Sottoscrizione CHIUSA.');
        _isPresenceChannelReady = false;
        _activeUserIds.clear();
        _updateConnectedUsersCountFromSet();
      }
    });
  }

  // Metodo per aggiornare il contatore basato sulla dimensione di _activeUserIds
  void _updateConnectedUsersCountFromSet() {
    final newCount = _activeUserIds.length;
    if (connectedUsers.value != newCount) {
      connectedUsers.value = newCount;
    }
    logInfo('  CONTEGGIO (from _activeUserIds Set): Utenti connessi: ${connectedUsers.value}');
  }

  // Metodo per riconciliare _activeUserIds usando List<SinglePresenceState>
  // dove ogni SinglePresenceState ha una proprietà 'presences' che è List<Presence>.
  void _reconcileActiveUserIdsFromListSinglePresenceState() {
    if (_onlineUsersChannel == null || !_isPresenceChannelReady) {
      logInfo('  RICONCILIAZIONE (List<SinglePresenceState>): Canale non pronto o nullo.');
      return;
    }

    logInfo('  RICONCILIAZIONE (List<SinglePresenceState>): Tentativo...');
    try {
      // Otteniamo la lista. Il tipo statico è List<SinglePresenceState> secondo il compilatore.
      // Accederemo alle sue proprietà dinamicamente basandoci sui log precedenti.
      final List<dynamic> presenceStateList = _onlineUsersChannel!.presenceState();
      logInfo('    RICONCILIAZIONE: presenceState() ha restituito Lista di ${presenceStateList.length} elementi.');

      final Set<String> idsExtractedFromState = {};

      if (presenceStateList.isEmpty) {
        // Se lo stato completo è vuoto, _activeUserIds dovrebbe essere vuoto.
        // Non è detto che _activeUserIds sia già vuoto se un JOIN è appena arrivato.
      } else {
        for (final dynamic singleStateItem_dynamic in presenceStateList) {
          try {
            final dynamic presencesListProperty = singleStateItem_dynamic.presences;

            if (presencesListProperty != null && presencesListProperty is List) {
              for (final dynamic presenceItem_dynamic in presencesListProperty) {
                if (presenceItem_dynamic != null) {
                  final dynamic payloadProperty = presenceItem_dynamic.payload;
                  if (payloadProperty != null && payloadProperty is Map<String, dynamic>) {
                    final Map<String, dynamic> payloadMap = payloadProperty;
                    if (payloadMap.containsKey('user_id') && payloadMap['user_id'] is String) {
                      final userIdFound = payloadMap['user_id'] as String;
                      if (userIdFound.isNotEmpty) {
                        idsExtractedFromState.add(userIdFound);
                      }
                    }
                  } else {
                    logInfo('      RICONCILIAZIONE AVVISO: presenceItem_dynamic.payload non è una Map valida o è null. Payload: $payloadProperty');
                  }
                }
              }
            } else {
              logInfo('      RICONCILIAZIONE AVVISO: singleStateItem_dynamic.presences non è una Lista valida o è null. Valore di .presences: $presencesListProperty');
            }
          } catch (e) {
            logInfo('      RICONCILIAZIONE ERRORE INTERNO loop: Elaborazione singleStateItem fallita. Errore: $e\nItem: $singleStateItem_dynamic');
          }
        }
      }

      // Confronta e sincronizza _activeUserIds con idsExtractedFromState
      if (!_areSetsEqual(idsExtractedFromState, _activeUserIds)) {
        logInfo('    RICONCILIAZIONE: Discrepanza! Sincronizzo _activeUserIds con stato da presenceState().');
        logInfo('      _activeUserIds (da JOIN/LEAVE) prima: $_activeUserIds');
        logInfo('      idsExtractedFromState (da presenceState()): $idsExtractedFromState');
        _activeUserIds.clear();
        _activeUserIds.addAll(idsExtractedFromState);
        logInfo('      _activeUserIds dopo sincronizzazione: $_activeUserIds');
      } else {
        logInfo('    RICONCILIAZIONE: Nessuna discrepanza tra _activeUserIds e idsExtractedFromState. Stato coerente.');
      }

      // Aggiorna il conteggio finale basato su _activeUserIds (che ora dovrebbe essere sincronizzato)
      _updateConnectedUsersCountFromSet();
    } catch (e) {
      logInfo('  RICONCILIAZIONE ERRORE ESTERNO (List<SinglePresenceState>): $e');
    }
  }

  bool _areSetsEqual<T>(Set<T> set1, Set<T> set2) {
    if (set1.length != set2.length) return false;
    for (final item in set1) {
      if (!set2.contains(item)) return false;
    }
    return true;
  }

  void _debugPrintFullPresenceState() {
    if (_onlineUsersChannel == null || !_isPresenceChannelReady) {
      logInfo('  DEBUG_FULL_PRESENCE_STATE: Canale non pronto o nullo.');
      return;
    }
    try {
      final List<dynamic> stateListRaw = _onlineUsersChannel!.presenceState();
      final List<dynamic> stateList = stateListRaw; // Ora sappiamo che è una lista

      logInfo('  DEBUG_FULL_PRESENCE_STATE: presenceState() -> Lista di ${stateList.length} elementi:');
      for (int i = 0; i < stateList.length; i++) {
        final singleState = stateList[i];
        logInfo('    [$i] Tipo Oggetto: $singleState.runtimeType');
        logInfo('        Valore (toString): ${singleState.toString()}');

        // Tentativi di accesso dinamico (SOLO PER DEBUG)
        dynamic dynState = singleState;
        try {
          logInfo('        (dyn.key se esiste): ${dynState.key}');
        } catch (_) {
          logInfo('        (dyn.key non accessibile)');
        }
        try {
          final dynPresences = dynState.presences;
          logInfo('        (dyn.presences se esiste, tipo: ${dynPresences.runtimeType}): $dynPresences');
          if (dynPresences is List && dynPresences.isNotEmpty) {
            for (var k = 0; k < dynPresences.length; k++) {
              final itemInPresences = dynPresences[k];
              logInfo('          (dyn.presences[$k], tipo: ${itemInPresences.runtimeType}): $itemInPresences');
              if (itemInPresences != null) {
                try {
                  logInfo('            (dyn.presences[$k].payload): ${itemInPresences.payload}');
                } catch (_) {
                  logInfo('            (dyn.presences[$k].payload non accessibile)');
                }
              }
            }
          } else if (dynPresences != null) {
            // Se non è una lista ma esiste (improbabile per 'presences')
            try {
              logInfo('          (dyn.presences.payload se dyn.presences è un oggetto con payload): ${dynPresences.payload}');
            } catch (_) {
              logInfo('          (dyn.presences.payload non accessibile)');
            }
          }
        } catch (_) {
          logInfo('        (dyn.presences non accessibile o errore ulteriore)');
        }
      }
      if (stateList.isEmpty) {
        logInfo('    La lista di presenceState è vuota.');
      }
    } catch (e) {
      logInfo('  DEBUG_FULL_PRESENCE_STATE: Errore durante la stampa: $e');
    }
  }

  Future<void> _unsubscribeFromOnlineUsers() async {
    logInfo('PersonaleController: _unsubscribeFromOnlineUsers()');
    if (_onlineUsersChannel != null) {
      logInfo("  CANALE: Tentativo di unsubscribe da 'online-users'.");
      _isPresenceChannelReady = false;
      try {
        await _onlineUsersChannel!.unsubscribe();
        logInfo("  CANALE: Unsubscribe completato.");
      } catch (e) {
        logInfo("  CANALE ERRORE unsubscribe: $e");
      } finally {
        // supabase.removeChannel(_onlineUsersChannel!); // Rimuovere il canale qui è più pulito
        _onlineUsersChannel = null;
      }
      _activeUserIds.clear();
      _updateConnectedUsersCountFromSet();
    } else {
      logInfo("  CANALE: Nessun canale da cui fare unsubscribe.");
      if (_activeUserIds.isNotEmpty || connectedUsers.value != 0) {
        _activeUserIds.clear();
        _updateConnectedUsersCountFromSet();
      }
    }
  }

  Future<void> _loadUserData() async {
    logInfo('PersonaleController: _loadUserData()');
    message.value = 'Caricamento dati utente...';
    final user = supabase.auth.currentUser;

    if (user == null) {
      message.value = 'Utente non autenticato.';
      logInfo('  AUTH: Utente non autenticato.');
      if (personale.value != null) personale.value = null;
      return;
    }
    final email = user.email!;
    logInfo('  AUTH: Caricamento dati per: $email (ID: ${user.id})');

    try {
      final List<dynamic> response = await supabase.from('personale').select().eq('email_principale', email).limit(1);

      if (response.isNotEmpty) {
        final Map<String, dynamic> userData = response.first as Map<String, dynamic>;
        personale.value = Personale.fromJson(userData);
        logInfo("AUTH: Personale model caricato: ${personale.value?.fullName}");
        message.value = 'Dati utente caricati.';
      } else {
        logInfo("AUTH: Nessun record Personale per: $email");
        if (personale.value != null) personale.value = null;
        message.value = 'Profilo personale non trovato.';
      }
    } catch (err) {
      message.value = 'Errore caricamento dati utente.';
      logInfo('  AUTH ERRORE: $err');
      if (personale.value != null) personale.value = null;
    }
    logInfo('  AUTH: Fine _loadUserData. Personale: ${personale.value != null ? "caricato" : "null"}. Msg: "${message.value}"');
  }

  Future<void> _loadAppVersion() async {
    logInfo('PersonaleController: _loadAppVersion()');
    try {
      final info = await PackageInfo.fromPlatform();
      appVersion.value = info.version + (info.buildNumber.isNotEmpty && info.buildNumber != "0" ? "+${info.buildNumber}" : "");
    } catch (e) {
      logInfo("  APP: Errore versione app: $e");
      appVersion.value = "N/A";
    }
  }

  Future<void> reload() async {
    logInfo('PersonaleController: reload()');
    message.value = 'Ricaricamento...';
    await _loadUserData();

    if (supabase.auth.currentUser != null) {
      if (_onlineUsersChannel == null || !_isPresenceChannelReady) {
        logInfo("  APP: Utente loggato, canale non pronto/nullo. (Ri)sottoscrivo.");
        _subscribeToOnlineUsers();
      } else {
        logInfo("  APP: Utente loggato, canale già attivo. Stampo stato per debug e tento riconciliazione.");
        _debugPrintFullPresenceState();
        _reconcileActiveUserIdsFromListSinglePresenceState();
      }
    } else {
      logInfo("  APP: Utente non loggato. Assicuro disiscrizione.");
      await _unsubscribeFromOnlineUsers();
    }
    message.value = 'Ricaricamento completato.';
  }
}
