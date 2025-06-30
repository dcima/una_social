class Laurea {
  final String universita;
  final int idLaurea;
  final String annoAccademicoQuery;
  final String? titoloLaurea;
  final String? immagineCorso;
  final String? durata;
  final String? sedeDidattica;
  final String? lingua;
  final String? tipoAccesso;
  final String? urlPaginaCorsoEsplora;

  Laurea({
    required this.universita,
    required this.idLaurea,
    required this.annoAccademicoQuery,
    this.titoloLaurea,
    this.immagineCorso,
    this.durata,
    this.sedeDidattica,
    this.lingua,
    this.tipoAccesso,
    this.urlPaginaCorsoEsplora,
  });

  factory Laurea.fromJson(Map<String, dynamic> json) {
    return Laurea(
      universita: json['universita'] as String,
      idLaurea: json['id_laurea'] is int ? json['id_laurea'] as int : int.parse(json['id_laurea'].toString()),
      annoAccademicoQuery: json['anno_accademico_query'] as String,
      titoloLaurea: json['titolo_laurea'] as String?,
      immagineCorso: json['immagine_corso'] as String?,
      durata: json['durata'] as String?,
      sedeDidattica: json['sede_didattica'] as String?,
      lingua: json['lingua'] as String?,
      tipoAccesso: json['tipo_accesso'] as String?,
      urlPaginaCorsoEsplora: json['url_pagina_corso_esplora'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'universita': universita,
      'id_laurea': idLaurea,
      'anno_accademico_query': annoAccademicoQuery,
      'titolo_laurea': titoloLaurea,
      'immagine_corso': immagineCorso,
      'durata': durata,
      'sede_didattica': sedeDidattica,
      'lingua': lingua,
      'tipo_accesso': tipoAccesso,
      'url_pagina_corso_esplora': urlPaginaCorsoEsplora,
    };
  }
}
