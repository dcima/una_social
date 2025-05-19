// Controller GetX
// ignore_for_file: avoid_print

import 'package:get/get_rx/src/rx_types/rx_types.dart';
import 'package:get/get_state_manager/src/simple/get_controllers.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:una_social_app/models/personale.dart'; // Assicurati che il path sia corretto
// We will avoid relying on the specific SinglePresenceState type for now

class PersonaleController extends GetxController {
  final supabase = Supabase.instance.client;
  var personale = Rxn<Personale>();
  var connectedUsers = 0.obs;
  var appVersion = ''.obs;
  var message = ''.obs;

  RealtimeChannel? _onlineUsersChannel;
  bool _isPresenceChannelReady = false;

  @override
  void onInit() {
    print('PersonaleController: onInit()');
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
    print('PersonaleController: onClose()');
    _unsubscribeFromOnlineUsers();
    super.onClose();
  }

  void _subscribeToOnlineUsers() {
    print('PersonaleController: _subscribeToOnlineUsers()');
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      print("AUTH: Utente non autenticato, impossibile iscriversi alla presence.");
      return;
    }

    if (_onlineUsersChannel != null && _isPresenceChannelReady) {
      print("CANALE: Già sottoscritto e pronto per 'online-users'.");
      return;
    }

    if (_onlineUsersChannel != null) {
      print("CANALE: Rimozione canale 'online-users' esistente.");
      supabase.removeChannel(_onlineUsersChannel!);
      _onlineUsersChannel = null;
      _isPresenceChannelReady = false;
      connectedUsers.value = 0;
    }

    print("CANALE: Creazione e sottoscrizione al canale 'online-users'.");
    _onlineUsersChannel = supabase.channel(
      'online-users',
      opts: const RealtimeChannelConfig(ack: true, self: true),
    );

    _onlineUsersChannel!.onPresenceSync((payload) {
      print('EVENTO: Presence SYNC ricevuto.');
      if (!_isPresenceChannelReady) {
        print("CANALE: Canale considerato PRONTO per la presence dopo il primo SYNC.");
        _isPresenceChannelReady = true;
      }
      _updateConnectedUsersCount();
    }).onPresenceJoin((payload) {
      print('EVENTO: Presence JOIN ricevuto. Nuove presenze: ${payload.newPresences.length}');
      if (!_isPresenceChannelReady) {
        print("CANALE: Canale considerato PRONTO per la presence dopo JOIN.");
        _isPresenceChannelReady = true;
      }
      _updateConnectedUsersCount();
    }).onPresenceLeave((payload) {
      print('EVENTO: Presence LEAVE ricevuto. Presenze uscite: ${payload.leftPresences.length}');
      _updateConnectedUsersCount();
    });

    _onlineUsersChannel!.subscribe((status, [error]) async {
      print("CANALE: Stato sottoscrizione 'online-users' cambiato a: $status.");
      if (status == RealtimeSubscribeStatus.subscribed) {
        print('CANALE: Sottoscrizione ad \'online-users\' avvenuta. Tentativo di tracciare la presenza...');
        try {
          await _onlineUsersChannel!.track({
            'user_id': userId,
            'online_at': DateTime.now().toIso8601String(),
          });
          print('CANALE: Presenza utente tracciata con successo su \'online-users\'.');
          _updateConnectedUsersCount();
        } catch (e, s) {
          print('CANALE ERRORE durante il track su \'online-users\': $e');
          print(s);
          _isPresenceChannelReady = false;
        }
      } else if (status == RealtimeSubscribeStatus.channelError || status == RealtimeSubscribeStatus.timedOut) {
        print('CANALE ERRORE: Sottoscrizione ad \'online-users\' fallita: $error, status: $status.');
        message.value = 'Errore Realtime (connessione utenti): $error';
        _isPresenceChannelReady = false;
        connectedUsers.value = 0;
      } else if (status == RealtimeSubscribeStatus.closed) {
        print('CANALE: Sottoscrizione ad \'online-users\' CHIUSA.');
        _isPresenceChannelReady = false;
        connectedUsers.value = 0;
      }
    });
  }

  // --- METHOD CORRECTED (Treating presenceState items as dynamic/Map) ---
  void _updateConnectedUsersCount() {
    print('PersonaleController: _updateConnectedUsersCount()');
    if (_onlineUsersChannel == null || !_isPresenceChannelReady) {
      print('CONTEGGIO: Impossibile aggiornare, canale \'online-users\' non pronto (flag: $_isPresenceChannelReady).');
      return;
    }

    try {
      // Get the presence state, treat return type as dynamic initially.
      final dynamic presenceStateResult = _onlineUsersChannel!.presenceState();
      print('DEBUG CONTEGGIO: presenceState() runtimeType: ${presenceStateResult.runtimeType}');

      // We expect a List (or JSArray on web which behaves like a List).
      if (presenceStateResult is! List && presenceStateResult is! Iterable) {
        print('CONTEGGIO ERRORE: presenceState() non ha restituito una lista/iterable. Trovato: ${presenceStateResult.runtimeType}');
        // Maybe reset count or handle appropriately
        // connectedUsers.value = 0;
        return;
      }

      // Convert to a standard Dart List<dynamic> for easier processing.
      // This should handle both native List and JSArray.
      final List<dynamic> presencesList = List<dynamic>.from(presenceStateResult as Iterable<dynamic>);

      final Set<String> uniqueUserIds = {};

      // Iterate over each element in the list. Treat each element as dynamic.
      for (final dynamic presenceItemRaw in presencesList) {
        // Attempt to treat the item as a Map. This is the most likely structure.
        if (presenceItemRaw is Map) {
          // Cast to Map<String, dynamic> for easier access, but be cautious.
          // Use null-aware checks for keys.
          final Map<String, dynamic> presenceItemMap = Map<String, dynamic>.from(presenceItemRaw);

          // Look for the list of payloads. The key is likely 'metas'.
          final dynamic metasRaw = presenceItemMap['metas'];

          if (metasRaw is List) {
            final List<dynamic> metas = metasRaw;
            for (final dynamic metaItem in metas) {
              if (metaItem is Map<String, dynamic>) {
                final Map<String, dynamic> userPayload = metaItem;
                if (userPayload.containsKey('user_id') && userPayload['user_id'] is String) {
                  uniqueUserIds.add(userPayload['user_id'] as String);
                } else {
                  final String? presenceKey = presenceItemMap['key'] as String?;
                  print('CONTEGGIO AVVISO: user_id non trovato o tipo errato nel payload. Payload: $userPayload. Presence Key: $presenceKey');
                }
              } else {
                print('CONTEGGIO AVVISO: Elemento in metas non è Map<String, dynamic>. Tipo trovato: ${metaItem.runtimeType}');
              }
            }
          } else {
            final String? presenceKey = presenceItemMap['key'] as String?;
            print('CONTEGGIO AVVISO: Chiave \'metas\' non trovata o non è una Lista nel presence item. Chiavi trovate: ${presenceItemMap.keys}. Presence Key: $presenceKey');
          }
        } else {
          // Log if an item in the main list isn't a Map.
          print('CONTEGGIO AVVISO: Elemento in presenceState list non è una Map. Tipo trovato: ${presenceItemRaw.runtimeType}');
        }
      }

      if (!_isPresenceChannelReady && presencesList.isNotEmpty) {
        print("CANALE: Canale CONFERMATO PRONTO dopo un _updateConnectedUsersCount con dati.");
        _isPresenceChannelReady = true;
      }

      connectedUsers.value = uniqueUserIds.length;
      print('CONTEGGIO: Utenti connessi aggiornati a: ${connectedUsers.value}');
    } catch (e, s) {
      print('CONTEGGIO ERRORE grave durante l\'aggiornamento del conteggio: $e');
      print('Stacktrace per errore conteggio: $s');
      // Handle specific errors like cast errors if they occur.
    }
  }
  // --- END OF CORRECTED METHOD ---

  Future<void> _unsubscribeFromOnlineUsers() async {
    print('PersonaleController: _unsubscribeFromOnlineUsers()');
    if (_onlineUsersChannel != null) {
      _isPresenceChannelReady = false;
      try {
        await _onlineUsersChannel!.unsubscribe();
      } catch (e, s) {
        print("CANALE ERRORE durante unsubscribe da 'online-users': $e - $s");
      } finally {
        supabase.removeChannel(_onlineUsersChannel!);
        _onlineUsersChannel = null;
      }
      connectedUsers.value = 0;
    }
  }

  Future<void> _loadUserData() async {
    print('PersonaleController: _loadUserData()');
    message.value = '';
    final user = supabase.auth.currentUser;
    personale.value = null;

    if (user == null) {
      message.value = 'Utente non autenticato.';
      print('AUTH: Utente non autenticato.');
      await _unsubscribeFromOnlineUsers();
      return;
    }
    final email = user.email!;

    try {
      final List<dynamic> response = await supabase.from('personale').select().eq('email_principale', email).limit(1);

      if (response.isNotEmpty) {
        print('response: $response');
        final Map<String, dynamic> userData = response.first as Map<String, dynamic>;
        personale.value = Personale.fromJson(userData);
        print('AUTH: Personale model caricato: ${personale.value?.fullName}');
        message.value = '';
      } else {
        print('AUTH: Nessun record Personale trovato per l\'email: $email');
        personale.value = null;
        message.value = 'Profilo personale non trovato.';
      }
    } catch (err, stackTrace) {
      message.value = 'Errore imprevisto in _loadUserData: $err';
      print('AUTH ERRORE imprevisto in _loadUserData: $err');
      print('Stack trace: $stackTrace');
      personale.value = null;
    }
    print('AUTH: Fine _loadUserData, personale.value è ${personale.value == null ? "null" : "caricato"}.');
  }

  Future<void> _loadAppVersion() async {
    print('PersonaleController: _loadAppVersion()');
    try {
      final info = await PackageInfo.fromPlatform();
      appVersion.value = info.version;
    } catch (e) {
      print("APP: Errore caricamento versione app: $e");
      appVersion.value = "N/A";
    }
  }

  Future<void> reload() async {
    print('PersonaleController: reload()');
    await _loadUserData();

    if (supabase.auth.currentUser != null) {
      if (_onlineUsersChannel == null || !_isPresenceChannelReady) {
        print("APP: Utente loggato, canale non pronto o nullo. Tentativo di sottoscrizione alla presence...");
        _subscribeToOnlineUsers();
      } else {
        print("APP: Utente loggato, canale presence già attivo e pronto.");
      }
    } else {
      if (_onlineUsersChannel != null || _isPresenceChannelReady) {
        print("APP: Utente non loggato, ma canale/flag indica attività. Tentativo di unsubscribe dalla presence...");
        await _unsubscribeFromOnlineUsers();
      } else {
        print("APP: Utente non loggato, canale presence già inattivo.");
      }
    }
  }
}
