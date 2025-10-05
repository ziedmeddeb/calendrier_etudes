class Seance {
  final String id;
  final DateTime date;
  final String etudiantId;
  bool present;
  final String name;

  Seance({
    required this.id,
    required this.date,
    required this.etudiantId,
    required this.present,
    this.name = 'Séance',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date':
          "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}",
      'etudiantId': etudiantId,
      'present': present ? 1 : 0,
      'name': name,
    };
  }

  factory Seance.fromMap(Map<String, dynamic> map) {
    return Seance(
      id: map['id'],
      date: DateTime.parse(map['date']),
      etudiantId: map['etudiantId'],
      present: map['present'] == 1,
      name: map['name'] ?? 'Séance',
    );
  }
}
