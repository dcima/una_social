// controller: personale_controller.dart
// ignore_for_file: avoid_print, non_constant_identifier_names

import 'dart:async';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:una_social/helpers/logger_helper.dart';
import 'package:una_social/models/personale.dart';

class PersonaleController extends GetxController {
  final supabase = Supabase.instance.client;
  var personale = Rxn<Personale>();
  var connectedUsers = 0.obs;
  var appVersion = ''.obs;
  var message = ''.obs;
  var isLoading = false.obs; // Aggiunto per gestire lo stato di caricamento

  RealtimeChannel? _onlineUsersChannel;
  StreamSubscription<AuthState>? _authSubscription;
  final Set<String> _activeUserIds = {};

  @override
  void onInit() {
    logInfo('PersonaleController: onInit()');
    super.onInit();
    _loadAppVersion();

    // 1. RIMOSSA LOGICA DI CARICAMENTO DA onInit.
    // onInit ora imposta solo il listener, che è la fonte unica della verità per lo stato di autenticazione.
    _authSubscription = supabase.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      logInfo("PersonaleController.onAuthStateChange: Evento $event");
      _handleAuthStateChange(event);
    });

    // 2. GESTIONE DELLO STATO INIZIALE
    // Controlliamo lo stato corrente all'avvio dell'app. Potrebbe esserci già una sessione valida.
    if (supabase.auth.currentUser != null) {
      logInfo("PersonaleController.onInit: Rilevata sessione esistente. Avvio caricamento dati.");
      _handleAuthStateChange(AuthChangeEvent.initialSession);
    }
  }

  // 3. CENTRALIZZATA LA LOGICA DI GESTIONE DELLO STATO AUTH
  Future<void> _handleAuthStateChange(AuthChangeEvent event) async {
    // Usiamo una guardia per evitare esecuzioni multiple se gli eventi scattano rapidamente.
    if (isLoading.value) {
      logInfo("AUTH: Caricamento già in corso, ignoro nuovo evento '$event'.");
      return;
    }

    isLoading.value = true;

    if (event == AuthChangeEvent.signedIn || event == AuthChangeEvent.initialSession) {
      logInfo("AUTH: Utente loggato o sessione iniziale. Caricamento dati...");
      message.value = 'Autenticazione in corso...';

      await _loadUserData(); // Carica i dati del profilo
      _subscribeToOnlineUsers(); // Poi si iscrive al canale presence
    } else if (event == AuthChangeEvent.signedOut) {
      logInfo("AUTH: Utente disconnesso. Pulizia stato...");
      message.value = 'Disconnessione in corso...';

      await _unsubscribeFromOnlineUsers(); // Prima disiscrizione dal canale
      personale.value = null; // Poi pulizia dei dati locali
      _activeUserIds.clear();
      _updateConnectedUsersCount();

      message.value = 'Utente disconnesso.';
    }

    isLoading.value = false;
  }

  @override
  void onClose() {
    logInfo('PersonaleController: onClose()');
    // È fondamentale cancellare la sottoscrizione per evitare memory leak.
    _authSubscription?.cancel();
    _unsubscribeFromOnlineUsers();
    super.onClose();
  }

  // --- Gestione Dati Utente ---

  Future<void> _loadUserData() async {
    logInfo('PersonaleController: _loadUserData()');
    message.value = 'Caricamento profilo utente...';
    final user = supabase.auth.currentUser;

    if (user == null) {
      logInfo('  AUTH: Tentativo di caricamento dati senza utente autenticato. Interrompo.');
      personale.value = null;
      return;
    }

    try {
      final List<dynamic> response = await supabase.from('personale').select().eq('email_principale', user.email!).limit(1);

      if (response.isNotEmpty) {
        personale.value = Personale.fromJson(response.first as Map<String, dynamic>);
        logInfo("  AUTH: Profilo caricato per ${personale.value?.cognome}");
        message.value = 'Profilo utente caricato.';
      } else {
        logInfo("  AUTH: Nessun profilo trovato per: ${user.email}");
        personale.value = null;
        message.value = 'Profilo personale non trovato.';
      }
    } catch (err) {
      message.value = 'Errore caricamento dati utente.';
      logInfo('  AUTH ERRORE: $err');
      personale.value = null;
    }
  }

  // --- Gestione Canale Realtime Presence ---

  void _subscribeToOnlineUsers() {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      logInfo("PRESENCE: Utente non autenticato, impossibile iscriversi.");
      return;
    }

    // 4. SEMPLIFICATA LA LOGICA DI (RI)SOTTOSCRIZIONE
    // Se c'è già un canale, lo rimuoviamo prima di crearne uno nuovo.
    // Questo garantisce sempre uno stato pulito.
    if (_onlineUsersChannel != null) {
      logInfo("PRESENCE: Canale esistente trovato. Lo rimuovo per garantire una nuova sottoscrizione pulita.");
      _unsubscribeFromOnlineUsers();
    }

    _activeUserIds.clear(); // Pulisci sempre prima di una nuova sottoscrizione.

    logInfo("PRESENCE: Creazione e sottoscrizione a 'online-users'.");
    _onlineUsersChannel = supabase.channel('online-users');

    _onlineUsersChannel!.onPresenceSync((_) {
      logInfo('PRESENCE EVENT: SYNC');
      // Dopo un SYNC, lo stato completo è disponibile. Riconciliamo.
      _reconcileActiveUsers();
    }).onPresenceJoin((payload) {
      logInfo('PRESENCE EVENT: JOIN');
      for (final presence in payload.newPresences) {
        final userId = presence.payload['user_id'] as String?;
        if (userId != null) _activeUserIds.add(userId);
      }
      _updateConnectedUsersCount();
    }).onPresenceLeave((payload) {
      logInfo('PRESENCE EVENT: LEAVE');
      for (final presence in payload.leftPresences) {
        final userId = presence.payload['user_id'] as String?;
        if (userId != null) _activeUserIds.remove(userId);
      }
      _updateConnectedUsersCount();
    }).subscribe((status, [error]) async {
      logInfo("PRESENCE STATUS: $status");
      if (status == RealtimeSubscribeStatus.subscribed) {
        await _onlineUsersChannel!.track({
          'user_id': userId,
          'online_at': DateTime.now().toIso8601String(),
        });
        logInfo('PRESENCE: Presenza tracciata per utente $userId.');
      } else if (error != null) {
        logInfo('PRESENCE ERROR: $error');
        _activeUserIds.clear();
        _updateConnectedUsersCount();
      }
    });
  }

  Future<void> _unsubscribeFromOnlineUsers() async {
    if (_onlineUsersChannel != null) {
      logInfo("PRESENCE: Annullamento sottoscrizione dal canale 'online-users'.");
      await supabase.removeChannel(_onlineUsersChannel!);
      _onlineUsersChannel = null;
    }
  }

  void _updateConnectedUsersCount() {
    final newCount = _activeUserIds.length;
    if (connectedUsers.value != newCount) {
      connectedUsers.value = newCount;
    }
    logInfo('PRESENCE COUNT: Utenti connessi: $newCount');
  }

  void _reconcileActiveUsers() {
    if (_onlineUsersChannel == null) return;

    logInfo("PRESENCE: Riconciliazione stato utenti...");

    // CORREZIONE: il tipo restituito è List<SinglePresenceState>
    final List<SinglePresenceState> presenceStateList = _onlineUsersChannel!.presenceState();
    final Set<String> remoteUserIds = {};

    // Iteriamo sulla lista di SinglePresenceState
    for (final singleState in presenceStateList) {
      // Ogni singleState contiene una lista di presenze per un client
      for (final presence in singleState.presences) {
        // Estraiamo il payload da ogni presenza
        final userId = presence.payload['user_id'] as String?;
        if (userId != null && userId.isNotEmpty) {
          remoteUserIds.add(userId);
        }
      }
    }

    // Confrontiamo lo stato locale con quello remoto e sincronizziamo se necessario
    if (!_areSetsEqual(_activeUserIds, remoteUserIds)) {
      logInfo("PRESENCE: Discrepanza rilevata. Sincronizzo stato. Locale: $_activeUserIds, Remoto: $remoteUserIds");
      _activeUserIds.clear();
      _activeUserIds.addAll(remoteUserIds);
    }

    _updateConnectedUsersCount();
    logInfo("PRESENCE: Riconciliazione completata. Stato finale: $_activeUserIds");
  }

  // Aggiungi questo helper se non lo hai già, per confrontare i set
  bool _areSetsEqual<T>(Set<T> set1, Set<T> set2) {
    if (set1.length != set2.length) return false;
    for (final item in set1) {
      if (!set2.contains(item)) return false;
    }
    return true;
  }
  // --- Metodi Ausiliari e di Utility ---

  Future<void> _loadAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      appVersion.value = "${info.version}+${info.buildNumber}";
    } catch (e) {
      appVersion.value = "N/A";
    }
  }

  Future<void> reload() async {
    logInfo('PersonaleController: reload() richiesto.');
    await _handleAuthStateChange(AuthChangeEvent.userUpdated); // Simula un evento per forzare il ricaricamento
  }
}
