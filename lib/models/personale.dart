// models/personale.dart

// ignore_for_file: avoid_print // Utile per debug, considera un logger per produzione

import 'dart:convert';

class Personale {
  final String uuid;
  String ente;
  final int id; // Questo 'id' è specifico dell'ente, non l'UUID primario
  final String cognome;
  final String nome;
  String struttura; // Questo 'struttura' è l'ID della struttura all'interno dell'ente
  final String emailPrincipale;
  String? photoUrl;
  final String? cv;
  // Per campi JSONB: altreEmails e telefoni sono liste di mappe con chiavi 't' (tipo) e 'v' (valore)
  final List<Map<String, String>>? altreEmails;
  final List<Map<String, String>>? telefoni;
  final String? noteBiografiche;
  final String? rss;
  // Per campo JSONB: ruoli è una lista di stringhe
  final List<String>? ruoli;
  final String? web;

  Personale({
    required this.uuid,
    required this.ente,
    required this.id,
    required this.cognome,
    required this.nome,
    required this.struttura,
    required this.emailPrincipale,
    this.photoUrl,
    this.cv,
    this.altreEmails,
    this.noteBiografiche,
    this.rss,
    this.ruoli,
    this.telefoni,
    this.web,
  });

  String get fullName => '$nome $cognome';

  factory Personale.fromJson(Map<String, dynamic> json) {
    // Helper per deserializzare un campo JSONB che si prevede sia un array di stringhe
    List<String>? safeStringList(dynamic value) {
      if (value == null) return null;
      List<String> result = [];
      if (value is List) {
        result = value.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList();
      } else if (value is String) {
        // Caso in cui il JSONB viene restituito come stringa
        if (value.isEmpty) return null;
        try {
          final decoded = jsonDecode(value);
          if (decoded is List) {
            result = decoded.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList();
          } else {
            //print("Attenzione (Personale.fromJson): La stringa JSON decodificata per safeStringList non è una lista: $value");
          }
        } catch (e) {
          //print("Attenzione (Personale.fromJson): Impossibile decodificare la stringa JSON per safeStringList: '$value' - $e");
        }
      } else {
        //print("Attenzione (Personale.fromJson): Tipo non supportato per safeStringList: ${value.runtimeType}, Valore: $value");
      }
      return result.isEmpty ? null : result;
    }

    // Helper per deserializzare un campo JSONB che si prevede sia un array di oggetti {t: type, v: value}
    List<Map<String, String>>? safeMapList(dynamic value) {
      if (value == null) return null;

      List<dynamic> listToProcess;
      if (value is List) {
        listToProcess = value;
      } else if (value is String) {
        // Caso in cui il JSONB viene restituito come stringa
        if (value.isEmpty) return null;
        try {
          final decoded = jsonDecode(value);
          if (decoded is List) {
            listToProcess = decoded;
          } else {
            //print("Attenzione (Personale.fromJson): La stringa JSON decodificata per safeMapList non è una lista: $value");
            return null; // O [] se si preferisce una lista vuota in caso di errore
          }
        } catch (e) {
          //print("Attenzione (Personale.fromJson): Impossibile decodificare la stringa JSON per safeMapList: '$value' - $e");
          return null; // O []
        }
      } else {
        //print("Attenzione (Personale.fromJson): Tipo non supportato per safeMapList: ${value.runtimeType}, Valore: $value");
        return null; // O []
      }

      List<Map<String, String>> result = [];
      for (final item in listToProcess) {
        if (item is Map) {
          // Assicurarsi che le chiavi siano trattate come stringhe, anche se il JSON le ha come Symbol, ecc.
          final Map<String, dynamic> itemMap = Map<String, dynamic>.from(item);
          final Map<String, String> entry = {};

          entry['t'] = itemMap['t']?.toString() ?? '';

          if (itemMap.containsKey('v') && itemMap['v'] != null) {
            entry['v'] = itemMap['v'].toString();
            // Aggiungi solo se 'v' (valore) non è vuoto, se questa è la logica desiderata
            if (entry['v']!.isNotEmpty) {
              result.add(entry);
            }
          } else {
            // Se 'v' è cruciale e manca/null, si potrebbe decidere di non aggiungere l'entry.
            // L'attuale logica aggiunge l'entry se 'v' è presente e non null,
            // e la successiva condizione 'if (entry['v']!.isNotEmpty)' filtra quelle con valore vuoto.
            // Questo significa che {"t":"tipo", "v":""} verrebbe scartato.
            // //print("Attenzione (Personale.fromJson): Valore 'v' mancante, null o vuoto per l'item: $itemMap");
          }
        } else {
          //print("Attenzione (Personale.fromJson): Elemento ignorato in safeMapList (non è una Map): ${item?.runtimeType}, Valore: $item");
        }
      }
      return result.isEmpty ? null : result;
    }

    return Personale(
      // Per i campi NOT NULL nel DB, i fallback (?? '') sono una misura di robustezza
      // per la deserializzazione da sorgenti JSON potenzialmente incomplete.
      uuid: json['uuid'] as String? ?? '', // uuid è NOT NULL
      ente: json['ente'] as String? ?? '', // ente è NOT NULL
      id: (json['id'] as num?)?.toInt() ?? 0, // id è NOT NULL
      cognome: json['cognome'] as String? ?? '', // cognome è NOT NULL
      nome: json['nome'] as String? ?? '', // nome è NOT NULL
      struttura: json['struttura'] as String? ?? '', // struttura è NOT NULL
      emailPrincipale: json['email_principale'] as String? ?? '', // email_principale è NOT NULL

      photoUrl: json['photo_url'] as String?,
      cv: json['cv'] as String?,
      altreEmails: safeMapList(json['altre_emails']),
      noteBiografiche: json['note_biografiche'] as String?,
      rss: json['rss'] as String?,
      ruoli: safeStringList(json['ruoli']),
      telefoni: safeMapList(json['telefoni']),
      web: json['web'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    // Helper per serializzare List<Map<String,String>> nel formato JSONB atteso {"t": ..., "v": ...}
    List<Map<String, String>>? formatMapListForDb(List<Map<String, String>>? list) {
      if (list == null || list.isEmpty) return null;
      return list
          .where((item) => item['v'] != null && item['v']!.isNotEmpty) // Non salvare entry con valore vuoto
          .map((item) => {
                't': item['t'] ?? '', // Assicura che 't' esista, defaulta a stringa vuota
                'v': item['v']!, // 'v' è già stato controllato per non essere null/vuoto
              })
          .toList();
    }

    final Map<String, dynamic> data = {
      'uuid': uuid, // uuid è gestito dal DB con default gen_random_uuid() in inserimento se non fornito
      'ente': ente,
      'id': id,
      'cognome': cognome,
      'nome': nome,
      'struttura': struttura,
      'email_principale': emailPrincipale,
      'photo_url': photoUrl,
      'cv': cv,
      'altre_emails': formatMapListForDb(altreEmails),
      'note_biografiche': noteBiografiche,
      'rss': rss,
      // Per 'ruoli', se la lista è vuota, viene inviato null al DB.
      // Se si volesse salvare un array JSON vuoto [] invece di NULL, la logica sarebbe:
      // 'ruoli': ruoli ?? [], // Invia [] se ruoli è null, altrimenti la lista.
      // Ma l'attuale è spesso preferito:
      'ruoli': ruoli?.isEmpty ?? true ? null : ruoli,
      'telefoni': formatMapListForDb(telefoni),
      'web': web,
    };
    // Rimuove le chiavi con valori null prima di inviare al DB.
    // Questo è utile perché le colonne NULLABLE nel DB accetteranno l'assenza del campo.
    data.removeWhere((key, value) => value == null);
    return data;
  }

  @override
  String toString() {
    return 'Personale(uuid: $uuid, id: $id, nome: $nome, cognome: $cognome, ente: $ente, struttura: $struttura, email: $emailPrincipale, ruoli: $ruoli, altreEmails: $altreEmails, telefoni: $telefoni)';
  }
}
