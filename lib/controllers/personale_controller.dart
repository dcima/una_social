// Controller GetX
// ignore_for_file: avoid_print

import 'package:get/get_rx/src/rx_types/rx_types.dart';
import 'package:get/get_state_manager/src/simple/get_controllers.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:una_social_app/models/personale.dart'; // Ensure path is correct

class PersonaleController extends GetxController {
  final supabase = Supabase.instance.client;
  var personale = Rxn<Personale>();
  var connectedUsers = 0.obs;
  var appVersion = ''.obs;
  var message = ''.obs;

  RealtimeChannel? _onlineUsersChannel;
  bool _isPresenceChannelReady = false; // Il nostro flag per la prontezza del canale Presence

  @override
  void onInit() {
    super.onInit();
    _loadUserData().then((_) {
      if (supabase.auth.currentUser != null) {
        _subscribeToOnlineUsers();
      }
    });
    _loadAppVersion();
  }

  @override
  void onClose() {
    _unsubscribeFromOnlineUsers();
    super.onClose();
  }

  void _subscribeToOnlineUsers() {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      print("AUTH: Utente non autenticato, impossibile iscriversi.");
      return;
    }

    // Se il canale è già considerato pronto dal nostro flag, non fare nulla.
    if (_onlineUsersChannel != null && _isPresenceChannelReady) {
      print("CANALE: Già sottoscritto e pronto per 'online-users'.");
      return;
    }

    // Se il canale esiste ma non è pronto, o se è il primo tentativo,
    // pulisci il vecchio canale se esiste, per sicurezza.
    if (_onlineUsersChannel != null) {
      print("CANALE: Rimozione canale 'online-users' esistente (non pronto o per risottoscrizione).");
      supabase.removeChannel(_onlineUsersChannel!);
      _onlineUsersChannel = null;
      _isPresenceChannelReady = false; // Resetta il flag
      connectedUsers.value = 0; // Resetta il contatore
    }

    print("CANALE: Creazione e sottoscrizione al canale 'online-users'.");
    _onlineUsersChannel = supabase.channel(
      'online-users',
      opts: const RealtimeChannelConfig(ack: true, self: true),
    );

    _onlineUsersChannel!.onPresenceSync((payload) {
      print('EVENTO: Presence SYNC ricevuto.');
      // Questo è un buon momento per considerare il canale pronto per la presenza
      if (!_isPresenceChannelReady) {
        print("CANALE: Canale considerato PRONTO per la presenza dopo il primo SYNC.");
        _isPresenceChannelReady = true;
      }
      _updateConnectedUsersCount();
    }).onPresenceJoin((payload) {
      print('EVENTO: Presence JOIN ricevuto. Nuove presenze: ${payload.newPresences.length}');
      if (!_isPresenceChannelReady) {
        // Per sicurezza, anche se SYNC dovrebbe arrivare prima
        print("CANALE: Canale considerato PRONTO per la presenza dopo JOIN (insolito).");
        _isPresenceChannelReady = true;
      }
      _updateConnectedUsersCount();
    }).onPresenceLeave((payload) {
      print('EVENTO: Presence LEAVE ricevuto. Presenze uscite: ${payload.leftPresences.length}');
      _updateConnectedUsersCount();
    });

    _onlineUsersChannel!.subscribe((status, [error]) async {
      print("CANALE: Stato sottoscrizione cambiato a: $status.");
      if (status == RealtimeSubscribeStatus.subscribed) {
        print('CANALE: Sottoscrizione avvenuta. Tentativo di tracciare la presenza...');
        try {
          await _onlineUsersChannel!.track({
            // Chiamata a track
            'user_id': userId,
            'online_at': DateTime.now().toIso8601String(),
          });
          print('CANALE: Presenza utente tracciata con successo.');
          // Non impostiamo _isPresenceChannelReady = true qui necessariamente.
          // Aspettiamo onPresenceSync o il successo del primo _updateConnectedUsersCount
          // per avere una conferma più forte che la presenza è operativa.
          // Tuttavia, il track riuscito è un forte segnale.
          // Potremmo già fare un primo update qui.
          _updateConnectedUsersCount();
        } catch (e, s) {
          print('CANALE ERRORE durante il track: $e');
          print(s);
          // Se il track fallisce, il canale potrebbe non essere veramente pronto per la presenza.
          // _isPresenceChannelReady rimarrà false (o lo impostiamo a false se era true).
          _isPresenceChannelReady = false;
        }
      } else if (status == RealtimeSubscribeStatus.channelError || status == RealtimeSubscribeStatus.timedOut) {
        print('CANALE ERRORE: Sottoscrizione fallita: $error, status: $status.');
        message.value = 'Errore Realtime (connessione utenti): $error';
        _isPresenceChannelReady = false; // Canale non pronto
        connectedUsers.value = 0; // Resetta il conteggio
      } else if (status == RealtimeSubscribeStatus.closed) {
        print('CANALE: Sottoscrizione CHIUSA.');
        _isPresenceChannelReady = false; // Canale non più pronto
        connectedUsers.value = 0; // Resetta il conteggio
      }
    });
  }

  void _updateConnectedUsersCount() {
    // Usa il nostro flag _isPresenceChannelReady
    if (_onlineUsersChannel == null || !_isPresenceChannelReady) {
      print('CONTEGGIO: Impossibile aggiornare, canale non pronto (flag _isPresenceChannelReady: $_isPresenceChannelReady).');
      // Se il canale non è pronto, il conteggio potrebbe essere 0 o non affidabile.
      // Non resettare a 0 qui a meno che non siamo certi che il canale sia definitivamente chiuso.
      // La logica in subscribe (on close/error) dovrebbe gestire il reset a 0.
      return;
    }

    try {
      final List<dynamic> presencesListRaw = _onlineUsersChannel!.presenceState();
      // print('DEBUG CONTEGGIO: presenceState() ha restituito ${presencesListRaw.length} elementi.');

      final Set<String> uniqueUserIds = {};

      for (final presenceItemRaw in presencesListRaw) {
        String? currentPresenceRef;
        List<dynamic>? metasForRef;

        // Accesso dinamico alle proprietà di SinglePresenceState (o equivalente)
        try {
          currentPresenceRef = (presenceItemRaw as dynamic).key as String?;
          metasForRef = (presenceItemRaw as dynamic).presences as List<dynamic>?;
        } catch (e) {
          print('CONTEGGIO ERRORE accesso key/presences: Impossibile accedere a key/presences su ${presenceItemRaw.runtimeType}. Errore: $e');
          continue;
        }

        if (currentPresenceRef == null || metasForRef == null) {
          // print('CONTEGGIO AVVISO: currentPresenceRef o metasForRef sono null.');
          continue;
        }

        for (final metaItemRaw in metasForRef) {
          Map<String, dynamic>? userPayload;
          // Accesso dinamico al payload di PresenceMeta (o equivalente)
          try {
            userPayload = (metaItemRaw as dynamic).payload as Map<String, dynamic>?;
          } catch (e) {
            print('CONTEGGIO ERRORE accesso payload: Impossibile accedere a payload su ${metaItemRaw.runtimeType}. Errore: $e');
            continue;
          }

          if (userPayload != null && userPayload.containsKey('user_id') && userPayload['user_id'] is String) {
            uniqueUserIds.add(userPayload['user_id'] as String);
          } else {
            uniqueUserIds.add(currentPresenceRef); // Fallback
          }
        }
      }

      // Se siamo arrivati qui e uniqueUserIds è stato popolato, il canale è effettivamente operativo per la presenza.
      // Questo è un altro punto dove potremmo settare _isPresenceChannelReady = true se non lo fosse già.
      if (!_isPresenceChannelReady && presencesListRaw.isNotEmpty) {
        print("CANALE: Canale CONFERMATO PRONTO dopo un _updateConnectedUsersCount con dati.");
        _isPresenceChannelReady = true;
      }

      connectedUsers.value = uniqueUserIds.length;
      print('CONTEGGIO: Utenti connessi aggiornati: ${connectedUsers.value}');
    } catch (e, s) {
      print('CONTEGGIO ERRORE grave durante l\'aggiornamento: $e');
      print('Stacktrace per errore conteggio: $s');
      // Se c'è un errore qui, potrebbe significare che il canale non è veramente pronto.
      // _isPresenceChannelReady = false; // Considera di resettare il flag
    }
  }

  Future<void> _unsubscribeFromOnlineUsers() async {
    if (_onlineUsersChannel != null) {
      print("CANALE: Tentativo di annullamento iscrizione da 'online-users'.");
      _isPresenceChannelReady = false; // Il canale non sarà più pronto
      try {
        await _onlineUsersChannel!.unsubscribe();
        print("CANALE: Chiamata a unsubscribe() completata.");
      } catch (e, s) {
        print("CANALE ERRORE durante unsubscribe: $e");
        print(s);
      } finally {
        print("CANALE: Chiamata a supabase.removeChannel().");
        await supabase.removeChannel(_onlineUsersChannel!);
        _onlineUsersChannel = null;
        print("CANALE: Canale 'online-users' rimosso e azzerato.");
      }
      connectedUsers.value = 0; // Resetta il contatore
    }
  }

  // ... findPersonaleByEmailValueRpc, _loadUserData, _loadAppVersion, reload
  // dovrebbero usare il flag _isPresenceChannelReady per i controlli se necessario,
  // o assicurarsi che _subscribeToOnlineUsers/_unsubscribeFromOnlineUsers siano chiamati correttamente.

  Future<Personale?> findPersonaleByEmailValueRpc(String targetEmailValue) async {
    // (Invariato, non dipende direttamente dallo stato del canale presence)
    print('RPC: Ricerca email via RPC: $targetEmailValue');
    try {
      final response = await supabase.rpc(
        'search_personale_by_email_value',
        params: {'target_email': targetEmailValue},
      ).maybeSingle();

      if (response == null) {
        print('RPC: Nessun record trovato o più record trovati.');
        return null;
      }
      print('RPC: Record trovato: $response');
      return Personale.fromJson(response);
    } on PostgrestException catch (error) {
      if (error.code == 'PGRST116') {
        if (error.message.contains("0 rows")) {
          print('RPC ERRORE (PGRST116 - 0 rows): Nessun record trovato.');
        } else {
          print('RPC ERRORE (PGRST116 - multiple rows): Più record trovati per l\'email: $targetEmailValue.');
        }
      } else {
        print('RPC ERRORE Postgrest (non PGRST116): ${error.code} - ${error.message}');
      }
      return null;
    } catch (err, stackTrace) {
      print('RPC ERRORE generico: $err');
      print('Stack trace: $stackTrace');
      return null;
    }
  }

  Future<void> _loadUserData() async {
    // (Invariato, ma la sua chiamata a _unsubscribeFromOnlineUsers resetterà il flag)
    message.value = '';
    final user = supabase.auth.currentUser;

    if (user == null) {
      message.value = 'Utente non autenticato.';
      print('AUTH: Utente non autenticato.');
      personale.value = null;
      await _unsubscribeFromOnlineUsers(); // Questo imposterà _isPresenceChannelReady = false e connectedUsers = 0
      return;
    }
    personale.value = null;
    final email = user.email!;
    print('AUTH: Caricamento dati per utente: $email');
    final stopwatch = Stopwatch()..start();

    try {
      final record = await findPersonaleByEmailValueRpc(email);
      stopwatch.stop();
      print('RPC: Tempo esecuzione query: ${stopwatch.elapsed}');

      if (record != null) {
        personale.value = record;
        print('AUTH: Personale model caricato: ${personale.value}');
        message.value = '';
      } else {
        message.value = 'Nessun profilo trovato per l\'email: $email';
        print('AUTH: Nessun record trovato per l\'email: $email');
      }
    } catch (err, stackTrace) {
      message.value = 'Errore imprevisto in _loadUserData: $err';
      print('AUTH ERRORE imprevisto: $err');
      print('Stack trace: $stackTrace');
      personale.value = null;
    }
    print('AUTH: Fine _loadUserData, personale.value: ${personale.value}');
  }

  Future<void> _loadAppVersion() async {
    // (Invariato)
    try {
      final info = await PackageInfo.fromPlatform();
      appVersion.value = info.version;
    } catch (e) {
      print("APP: Errore caricamento versione app: $e");
      appVersion.value = "N/A";
    }
  }

  Future<void> reload() async {
    // (Usa il flag _isPresenceChannelReady per decidere se risottoscrivere)
    print("APP: Reload richiesto...");
    await _loadUserData(); // Gestisce l'unsubscribe se l'utente si scollega

    if (supabase.auth.currentUser != null && (_onlineUsersChannel == null || !_isPresenceChannelReady)) {
      // USA il nostro flag
      print("APP: Utente loggato, canale non pronto o nullo. Tentativo di sottoscrizione...");
      _subscribeToOnlineUsers();
    } else if (supabase.auth.currentUser == null && (_onlineUsersChannel != null || _isPresenceChannelReady)) {
      // Se l'utente non è loggato ma il canale è segnato come pronto o esiste, pulisci.
      print("APP: Utente non loggato, ma canale/flag indica attività. Tentativo di unsubscribe...");
      await _unsubscribeFromOnlineUsers();
    }
  }
}
