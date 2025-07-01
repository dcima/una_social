// models/struttura.dart

class Struttura {
  final String universita;
  final String id;
  final String? nome;
  final String? indirizzo;
  final String? numero;
  final String? citta;
  final String? cap;
  final String? longitudine;
  final String? latitudine;

  // Campi calcolati opzionali
  String get chiaveComposita => '$universita-$id'; // Un modo per rappresentare la PK

  double? get longitudineAsDouble {
    if (longitudine == null) return null;
    return double.tryParse(longitudine!);
  }

  double? get latitudineAsDouble {
    if (latitudine == null) return null;
    return double.tryParse(latitudine!);
  }

  Struttura({
    required this.universita,
    required this.id,
    this.nome,
    this.indirizzo,
    this.numero,
    this.citta,
    this.cap,
    this.longitudine,
    this.latitudine,
  });

  factory Struttura.fromJson(Map<String, dynamic> json) {
    return Struttura(
      universita: json['universita'] as String? ?? '', // Fallback per robustezza se il JSON è malformato
      id: (json['id']?.toString() ?? ''), // Fallback
      nome: json['nome'] as String?,
      indirizzo: json['indirizzo'] as String?,
      numero: json['numero'] as String?,
      citta: json['citta'] as String?,
      cap: json['cap'] as String?,
      longitudine: json['longitudine'] as String?,
      latitudine: json['latitudine'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'universita': universita,
      'id': id,
      'nome': nome,
      'indirizzo': indirizzo,
      'numero': numero,
      'citta': citta,
      'cap': cap,
      'longitudine': longitudine,
      'latitudine': latitudine,
    };
    // Rimuove le chiavi con valori null per un JSON più pulito
    // e per evitare di sovrascrivere colonne con NULL se non si vuole
    data.removeWhere((key, value) => value == null);
    return data;
  }

  // Utile per il debug e per le liste
  @override
  String toString() {
    return 'Struttura(universita: $universita, id: $id, nome: $nome, citta: $citta)';
  }

  // È buona prassi implementare hashCode e operator== se si prevede di
  // usare questi oggetti in Set, come chiavi in Map, o confrontarli.
  // La chiave primaria è (universita, id).
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Struttura && other.universita == universita && other.id == id;
  }

  @override
  int get hashCode => universita.hashCode ^ id.hashCode;

  // Metodo copyWith per creare facilmente una copia modificata (utile con stati immutabili)
  Struttura copyWith({
    String? universita,
    String? id,
    String? nome,
    String? indirizzo,
    String? numero,
    String? citta,
    String? cap,
    String? longitudine,
    String? latitudine,
  }) {
    return Struttura(
      universita: universita ?? this.universita,
      id: id ?? this.id,
      nome: nome ?? this.nome,
      indirizzo: indirizzo ?? this.indirizzo,
      numero: numero ?? this.numero,
      citta: citta ?? this.citta,
      cap: cap ?? this.cap,
      longitudine: longitudine ?? this.longitudine,
      latitudine: latitudine ?? this.latitudine,
    );
  }
}
