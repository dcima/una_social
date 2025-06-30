class DocenteInesistente {
  final String? nomeDocenteOriginale;

  DocenteInesistente({this.nomeDocenteOriginale});

  factory DocenteInesistente.fromJson(Map<String, dynamic> json) {
    return DocenteInesistente(
      nomeDocenteOriginale: json['nome_docente_originale'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nome_docente_originale': nomeDocenteOriginale,
    };
  }
}
