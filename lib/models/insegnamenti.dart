class Insegnamento {
  final String universita;
  final String idInsegnamento;
  final String annoAccademico;
  final String progressivo;
  final String? nomeInsegnamento;
  final String? idDocente;
  final String? cfu;
  final String? idAmbito;
  final String? idCampus;
  final String? idSsd;
  final String? idLaurea;
  final String? idPadre;
  final String? idZio;

  Insegnamento({
    required this.universita,
    required this.idInsegnamento,
    required this.annoAccademico,
    required this.progressivo,
    this.nomeInsegnamento,
    this.idDocente,
    this.cfu,
    this.idAmbito,
    this.idCampus,
    this.idSsd,
    this.idLaurea,
    this.idPadre,
    this.idZio,
  });

  factory Insegnamento.fromJson(Map<String, dynamic> json) {
    return Insegnamento(
      universita: json['universita'] as String,
      idInsegnamento: json['id_insegnamento'] as String,
      annoAccademico: json['anno_accademico'] as String,
      progressivo: json['progressivo'] as String,
      nomeInsegnamento: json['nome_insegnamento'] as String?,
      idDocente: json['id_docente'] as String?,
      cfu: json['cfu'] as String?,
      idAmbito: json['id_ambito'] as String?,
      idCampus: json['id_campus'] as String?,
      idSsd: json['id_ssd'] as String?,
      idLaurea: json['id_laurea'] as String?,
      idPadre: json['id_padre'] as String?,
      idZio: json['id_zio'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'universita': universita,
      'id_insegnamento': idInsegnamento,
      'anno_accademico': annoAccademico,
      'progressivo': progressivo,
      'nome_insegnamento': nomeInsegnamento,
      'id_docente': idDocente,
      'cfu': cfu,
      'id_ambito': idAmbito,
      'id_campus': idCampus,
      'id_ssd': idSsd,
      'id_laurea': idLaurea,
      'id_padre': idPadre,
      'id_zio': idZio,
    };
  }
}
