class Group {
  final int id;
  final String descrizione;

  Group({
    required this.id,
    required this.descrizione,
  });

  factory Group.fromJson(Map<String, dynamic> json) {
    return Group(
      id: json['id'] is int ? json['id'] as int : int.parse(json['id'].toString()),
      descrizione: json['descrizione'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'descrizione': descrizione,
    };
  }
}
