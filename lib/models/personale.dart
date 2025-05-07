// models/personale.dart

// ignore_for_file: avoid_print

import 'dart:convert';

class Personale {
  final String universita; // Added
  final int id; // Changed to int
  final String cognome; // Added
  final String nome; // Added
  final int struttura; // Added
  final String? photoUrl; // Kept
  final String? cv; // Added
  final List<String> emails; // Changed to List<String>
  final String? noteBiografiche; // Added
  final String? rss; // Added
  final List<String> ruoli; // Added, changed to List<String>
  final List<String> telefoni; // Added, changed to List<String>
  final String? web; // Added

  Personale({
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

  // Convenient getter for full name
  String get fullName => '$nome $cognome';

  factory Personale.fromJson(Map<String, dynamic> json) {
    // Helper function to safely cast lists
    List<String> safeStringList(dynamic value) {
      if (value is List) {
        // If it's already a list, process it
        return value.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList();
      } else if (value is String) {
        // If it's a string, try to decode it as JSON
        try {
          final decoded = jsonDecode(value);
          if (decoded is List) {
            // If decoding results in a list, process it
            return decoded.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList();
          }
        } catch (e) {
          // JSON decoding failed, treat as empty or handle error
          print("Warning: Could not decode string as JSON list: $value - $e");
          return [];
        }
      }
      // Return empty list for null or other unexpected types
      return [];
    }

    // Add a print statement here for debugging the type
    print("DEBUG: Type of json['telefoni']: ${json['telefoni'].runtimeType}");
    print("DEBUG: Value of json['telefoni']: ${json['telefoni']}");

    return Personale(
      universita: json['università'] as String? ?? '',
      id: json['id'] as int,
      cognome: json['cognome'] as String? ?? '',
      nome: json['nome'] as String? ?? '',
      struttura: json['struttura'] as int? ?? 0,
      photoUrl: json['photoUrl'] as String?,
      cv: json['cv'] as String?,
      emails: safeStringList(json['emails']), // Keep using for emails too
      noteBiografiche: json['noteBiografiche'] as String?,
      rss: json['rss'] as String?,
      ruoli: safeStringList(json['ruoli']), // Keep using for ruoli too
      telefoni: safeStringList(json['telefoni']), // Use the updated helper
      web: json['web'] as String?,
    );
  }

  // Optional: Add a toJson method if you need to serialize
  Map<String, dynamic> toJson() => {
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
    // Make debugging easier
    return 'Personale(id: $id, nome: $nome, cognome: $cognome, universita: $universita, struttura: $struttura, emails: $emails, ruoli: $ruoli, telefoni: $telefoni, photoUrl: $photoUrl, cv: $cv, web: $web, noteBiografiche: $noteBiografiche, rss: $rss)';
  }
}
