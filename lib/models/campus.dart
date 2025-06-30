class Campus {
  final String universita;
  final int idCampus;
  final String? nomeCampus;

  Campus({
    required this.universita,
    required this.idCampus,
    this.nomeCampus,
  });

  factory Campus.fromJson(Map<String, dynamic> json) {
    return Campus(
      universita: json['universita'] as String,
      idCampus: json['id_campus'] is int ? json['id_campus'] as int : int.parse(json['id_campus'].toString()),
      nomeCampus: json['nome_campus'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'universita': universita,
      'id_campus': idCampus,
      'nome_campus': nomeCampus,
    };
  }
}
