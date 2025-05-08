// models/personale.dart

// ignore_for_file: avoid_print

import 'dart:convert'; // Mantenuto per potenziale uso futuro

class Personale {
  final String uuid;
  final String universita;
  final int id;
  final String cognome;
  final String nome;
  final int struttura;
  final String? photoUrl;
  final String? cv;
  final List<Map<String, String>> emails;
  final String? noteBiografiche;
  final String? rss;
  final List<String> ruoli;
  final List<Map<String, String>> telefoni;
  final String? web;

  Personale({
    required this.uuid,
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
    List<String> safeStringList(dynamic value) {
      if (value == null) return [];
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

    List<Map<String, String>> safeMapList(dynamic value) {
      if (value == null) return [];
      if (value is List) {
        return value
            .whereType<Map>() // CORREZIONE APPLICATA QUI
            .map((item) {
          // 'item' è ora di tipo Map.
          // Per accedere a chiavi e valori in modo dinamico e convertirli a String,
          // possiamo castarlo a Map<dynamic, dynamic> se necessario,
          // o l'IDE potrebbe inferirlo correttamente.
          final Map<dynamic, dynamic> dynamicMap = item; // Cast 'as Map' non più necessario
          return dynamicMap.map((key, val) => MapEntry(key.toString(), val?.toString() ?? ''));
        }).toList();
      }
      return [];
    }

    return Personale(
      uuid: json['uuid'] as String? ?? '',
      universita: json['università'] as String? ?? '',
      id: (json['id'] as num?)?.toInt() ?? 0,
      cognome: json['cognome'] as String? ?? '',
      nome: json['nome'] as String? ?? '',
      struttura: (json['struttura'] as num?)?.toInt() ?? 0,
      photoUrl: json['photoUrl'] as String?,
      cv: json['cv'] as String?,
      emails: safeMapList(json['emails']),
      noteBiografiche: json['noteBiografiche'] as String?,
      rss: json['rss'] as String?,
      ruoli: safeStringList(json['ruoli']),
      telefoni: safeMapList(json['telefoni']),
      web: json['web'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'uuid': uuid,
        'università': universita,
        'id': id,
        'cognome': cognome,
        'nome': nome,
        'struttura': struttura,
        'photoUrl': photoUrl,
        'cv': cv,
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
