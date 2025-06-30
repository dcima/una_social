class Ambito {
  final String universita;
  final int idAmbito;
  final String? nomeAmbito;

  Ambito({
    required this.universita,
    required this.idAmbito,
    this.nomeAmbito,
  });

  factory Ambito.fromJson(Map<String, dynamic> json) {
    return Ambito(
      universita: json['universita'] as String,
      idAmbito: json['id_ambito'] is int ? json['id_ambito'] as int : int.parse(json['id_ambito'].toString()),
      nomeAmbito: json['nome_ambito'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'universita': universita,
      'id_ambito': idAmbito,
      'nome_ambito': nomeAmbito,
    };
  }
}
