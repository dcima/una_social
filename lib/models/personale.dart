// models/personale.dart

// ignore_for_file: avoid_print

import 'dart:convert';

class Personale {
  final String uuid;
  final String ente;
  final int id;
  final String cognome;
  final String nome;
  final String struttura;
  final String emailPrincipale;
  final String? photoUrl;
  final String? cv;
  // Queste liste conterranno Map con chiavi 't' e 'v'
  final List<Map<String, String>>? altreEmails;
  final List<Map<String, String>>? telefoni;
  final String? noteBiografiche;
  final String? rss;
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
    List<String>? safeStringList(dynamic value) {
      if (value == null) return null;
      List<String> result = [];
      if (value is List) {
        result = value.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList();
      } else if (value is String) {
        if (value.isEmpty) return null;
        try {
          final decoded = jsonDecode(value);
          if (decoded is List) {
            result = decoded.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList();
          } else {
            print("Attenzione (Personale.fromJson): La stringa JSON decodificata per safeStringList non è una lista: $value");
          }
        } catch (e) {
          print("Attenzione (Personale.fromJson): Impossibile decodificare la stringa JSON per safeStringList: '$value' - $e");
        }
      } else {
        print("Attenzione (Personale.fromJson): Tipo non supportato per safeStringList: ${value.runtimeType}, Valore: $value");
      }
      return result.isEmpty ? null : result;
    }

    List<Map<String, String>>? safeMapList(dynamic value) {
      if (value == null) return null;

      List<dynamic> listToProcess;
      if (value is List) {
        listToProcess = value;
      } else if (value is String) {
        if (value.isEmpty) return null;
        try {
          final decoded = jsonDecode(value);
          if (decoded is List) {
            listToProcess = decoded;
          } else {
            print("Attenzione (Personale.fromJson): La stringa JSON decodificata per safeMapList non è una lista: $value");
            return []; // Return empty list on decode error
          }
        } catch (e) {
          print("Attenzione (Personale.fromJson): Impossibile decodificare la stringa JSON per safeMapList: '$value' - $e");
          return []; // Return empty list on parse error
        }
      } else {
        print("Attenzione (Personale.fromJson): Tipo non supportato per safeMapList: ${value.runtimeType}, Valore: $value");
        return []; // Return empty list for unsupported types
      }

      List<Map<String, String>> result = [];
      for (final item in listToProcess) {
        if (item is Map) {
          final Map<String, String> entry = {};
          // USARE LE CHIAVI 't' e 'v' COME SONO NEL JSON/DB
          if (item.containsKey('t') && item['t'] != null) {
            entry['t'] = item['t'].toString();
          } else {
            entry['t'] = ''; // Default a stringa vuota se 't' manca o è null
          }

          if (item.containsKey('v') && item['v'] != null) {
            entry['v'] = item['v'].toString();
          } else {
            // Se 'v' è cruciale e manca/null, considera di saltare l'entry o loggare
            // print("Attenzione (Personale.fromJson): Valore 'v' mancante o null per l'item: $item");
            // entry['v'] = ''; // Oppure imposta a vuoto se consentito
            continue; // Salta questa entry se 'v' è mancante e obbligatorio
          }
          // Aggiungi solo se 'v' (valore) non è vuoto, se questa è la logica desiderata
          if (entry['v']!.isNotEmpty) {
            result.add(entry);
          }
        } else {
          print("Attenzione (Personale.fromJson): Elemento ignorato in safeMapList (non è una Map): ${item?.runtimeType}, Valore: $item");
        }
      }
      return result.isEmpty ? null : result;
    }

    return Personale(
      uuid: json['uuid'] as String? ?? '',
      ente: json['ente'] as String? ?? '',
      id: (json['id'] as num?)?.toInt() ?? 0,
      cognome: json['cognome'] as String? ?? '',
      nome: json['nome'] as String? ?? '',
      struttura: json['struttura'] as String? ?? '',
      emailPrincipale: json['email_principale'] as String? ?? '',
      photoUrl: json['photo_url'] as String?,
      cv: json['cv'] as String?,
      altreEmails: safeMapList(json['altre_emails']), // Conterrà Map{'t':..., 'v':...}
      noteBiografiche: json['note_biografiche'] as String?,
      rss: json['rss'] as String?,
      ruoli: safeStringList(json['ruoli']),
      telefoni: safeMapList(json['telefoni']), // Conterrà Map{'t':..., 'v':...}
      web: json['web'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    // Helper per assicurare che la lista di map sia nel formato corretto per il DB
    // (le chiavi devono essere 't' e 'v')
    List<Map<String, String>>? ensureDbMapListFormat(List<Map<String, String>>? list) {
      if (list == null || list.isEmpty) return null;
      return list
          .where((item) => item['v'] != null && item['v']!.isNotEmpty) // Filtra se 'v' è vuoto
          .map((item) => {
                't': item['t'] ?? '', // Assicura che 't' esista
                'v': item['v']!, // 'v' è già stato controllato
              })
          .toList();
    }

    final Map<String, dynamic> data = {
      'uuid': uuid,
      'ente': ente,
      'id': id,
      'cognome': cognome,
      'nome': nome,
      'struttura': struttura,
      'email_principale': emailPrincipale,
      'photo_url': photoUrl,
      'cv': cv,
      'altre_emails': ensureDbMapListFormat(altreEmails), // Usa 't' e 'v'
      'note_biografiche': noteBiografiche,
      'rss': rss,
      'ruoli': ruoli?.isEmpty ?? true ? null : ruoli,
      'telefoni': ensureDbMapListFormat(telefoni), // Usa 't' e 'v'
      'web': web,
    };
    data.removeWhere((key, value) => value == null); // Rimuove chiavi con valori null
    return data;
  }

  @override
  String toString() {
    return 'Personale(uuid: $uuid, id: $id, nome: $nome, cognome: $cognome, ente: $ente, email: $emailPrincipale, altreEmails: $altreEmails, telefoni: $telefoni)';
  }
}
