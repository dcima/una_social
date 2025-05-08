// models/personale.dart

// ignore_for_file: avoid_print

import 'dart:convert'; // Mantenuto per potenziale uso futuro

class Personale {
  final String uuid; // Nuovo campo, da SQL
  final String universita;
  final int id; // SQL 'bigint null', ma manteniamo int con fallback per coerenza
  final String cognome;
  final String nome;
  final int struttura; // SQL 'bigint null', ma manteniamo int con fallback
  final String? photoUrl;
  final String? cv;
  final List<Map<String, String>> emails; // jsonb null -> List (può essere vuota)
  final String? noteBiografiche;
  final String? rss;
  final List<String> ruoli; // jsonb null -> List (può essere vuota)
  final List<Map<String, String>> telefoni; // jsonb null -> List (può essere vuota)
  final String? web;

  Personale({
    required this.uuid, // Aggiunto required
    required this.universita,
    required this.id,
    required this.cognome,
    required this.nome,
    required this.struttura,
    this.photoUrl,
    this.cv,
    required this.emails,
    this.noteBiografiche,
    this.rss,
    required this.ruoli,
    required this.telefoni,
    this.web,
  });

  String get fullName => '$nome $cognome';

  factory Personale.fromJson(Map<String, dynamic> json) {
    // Helper function to safely cast lists of strings (per 'ruoli')
    List<String> safeStringList(dynamic value) {
      if (value == null) return []; // Gestisce null esplicitamente
      if (value is List) {
        return value.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList();
      } else if (value is String) {
        try {
          final decoded = jsonDecode(value);
          if (decoded is List) {
            return decoded.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList();
          }
        } catch (e) {
          print("Attenzione: Impossibile decodificare la stringa JSON per safeStringList: $value - $e");
        }
      }
      return [];
    }

    // Helper function to safely cast lists of maps (per 'emails' e 'telefoni')
    List<Map<String, String>> safeMapList(dynamic value) {
      if (value == null) return []; // Gestisce null esplicitamente
      if (value is List) {
        return value.where((item) => item is Map).map((item) {
          final Map<dynamic, dynamic> dynamicMap = item as Map;
          return dynamicMap.map((key, val) => MapEntry(key.toString(), val?.toString() ?? ''));
        })
            // Opzionale: filtra se il valore è vuoto. Considera se necessario per la tua logica.
            // .where((map) => (map['valore'] ?? '').isNotEmpty)
            .toList();
      }
      // Non tentiamo di decodificare stringhe JSON qui, ci aspettiamo che Supabase/DB
      // deserializzi correttamente i campi jsonb in List<Map> o List<dynamic>.
      return [];
    }

    return Personale(
      // uuid è 'not null' nel DB, quindi ci aspettiamo sia sempre presente nel JSON dal DB.
      // Se il JSON potesse non averlo, dovresti renderlo String? e gestire json['uuid'] as String?
      uuid: json['uuid'] as String? ?? '', // Fallback se per qualche motivo fosse null, ma db dice not null
      universita: json['università'] as String? ?? '', // SQL 'text null'
      id: (json['id'] as num?)?.toInt() ?? 0, // SQL 'bigint null'
      cognome: json['cognome'] as String? ?? '', // SQL 'text null'
      nome: json['nome'] as String? ?? '', // SQL 'text null'
      struttura: (json['struttura'] as num?)?.toInt() ?? 0, // SQL 'bigint null'
      photoUrl: json['photoUrl'] as String?, // SQL '"photoUrl" text null'
      cv: json['cv'] as String?, // SQL 'cv text null'
      emails: safeMapList(json['emails']), // SQL 'emails jsonb null'
      noteBiografiche: json['noteBiografiche'] as String?, // SQL '"noteBiografiche" text null'
      rss: json['rss'] as String?, // SQL 'rss text null'
      ruoli: safeStringList(json['ruoli']), // SQL 'ruoli jsonb null'
      telefoni: safeMapList(json['telefoni']), // SQL 'telefoni jsonb null'
      web: json['web'] as String?, // SQL 'web text null'
    );
  }

  Map<String, dynamic> toJson() => {
        'uuid': uuid, // Aggiunto
        'università': universita,
        'id': id,
        'cognome': cognome,
        'nome': nome,
        'struttura': struttura,
        'photoUrl': photoUrl,
        'cv': cv,
        // Per i campi JSONB, assicurati che siano serializzati come stringhe JSON
        // se il backend si aspetta una stringa JSON, altrimenti lasciali come liste/mappe
        // se il driver/ORM del database gestisce la conversione.
        // Supabase dovrebbe gestire List<Map> e List<String> direttamente per jsonb.
        'emails': emails,
        'noteBiografiche': noteBiografiche,
        'rss': rss,
        'ruoli': ruoli,
        'telefoni': telefoni,
        'web': web,
      };

  @override
  String toString() {
    return 'Personale(uuid: $uuid, id: $id, nome: $nome, cognome: $cognome, universita: $universita, struttura: $struttura, emails: $emails, ruoli: $ruoli, telefoni: $telefoni, photoUrl: $photoUrl, cv: $cv, web: $web, noteBiografiche: $noteBiografiche, rss: $rss)';
  }
}
