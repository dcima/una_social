// lib/models/esterni.dart
import 'dart:convert';
import 'package:una_social/models/i_user_profile.dart';

class Esterni implements IUserProfile {
  final String id;
  final String? authUuid;
  final String? cognome;
  final String? nome;

  @override
  final String? emailPrincipale;

  // --- MODIFICA CHIAVE ---
  // Il tipo corretto per rappresentare una lista di oggetti {"t": "...", "v": "..."}
  // è una lista di mappe.
  final List<Map<String, dynamic>>? altreEmails;
  final List<Map<String, dynamic>>? telefoni;

  @override
  final String? photoUrl;

  Esterni({
    required this.id,
    this.authUuid,
    this.cognome,
    this.nome,
    this.emailPrincipale,
    this.altreEmails,
    this.telefoni,
    this.photoUrl,
  });

  factory Esterni.fromJson(Map<String, dynamic> json) {
    final altreEmailsData = json['altre_emails'];
    final telefoniData = json['telefoni'];

    return Esterni(
      id: json['id'] as String,
      authUuid: json['auth_uuid'] as String?,
      cognome: json['cognome'] as String?,
      nome: json['nome'] as String?,
      emailPrincipale: json['email_principale'] as String?,
      // Gestiamo il cast in modo sicuro, convertendo una List<dynamic>
      // in una List<Map<String, dynamic>>.
      altreEmails: altreEmailsData is List ? List<Map<String, dynamic>>.from(altreEmailsData) : null,
      telefoni: telefoniData is List ? List<Map<String, dynamic>>.from(telefoniData) : null,
      photoUrl: json['photo_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'auth_uuid': authUuid,
      'cognome': cognome,
      'nome': nome,
      'email_principale': emailPrincipale,
      'altre_emails': altreEmails,
      'telefoni': telefoni,
      'photo_url': photoUrl,
    };
  }

  // Metodo copyWith aggiornato con i tipi corretti
  Esterni copyWith({
    String? id,
    String? authUuid,
    String? cognome,
    String? nome,
    String? emailPrincipale,
    List<Map<String, dynamic>>? altreEmails,
    List<Map<String, dynamic>>? telefoni,
    String? photoUrl,
  }) {
    return Esterni(
      id: id ?? this.id,
      authUuid: authUuid ?? this.authUuid,
      cognome: cognome ?? this.cognome,
      nome: nome ?? this.nome,
      emailPrincipale: emailPrincipale ?? this.emailPrincipale,
      altreEmails: altreEmails ?? this.altreEmails,
      telefoni: telefoni ?? this.telefoni,
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }

  @override
  String toString() {
    return 'Esterni(${jsonEncode(toJson())})';
  }
}
