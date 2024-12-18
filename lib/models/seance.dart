import 'groupe.dart';
import 'etudiant_presence.dart';

class Seance {
  String id;
  Groupe groupe;
  DateTime date;
  List<EtudiantPresence> presences;

  Seance({
    required this.id,
    required this.groupe,
    required this.date,
    required this.presences,
  });

  // Optional: Add toMap and fromMap methods for database serialization
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'groupeId': groupe.id,
      'date': date.toIso8601String(),
    };
  }

  static Seance fromMap(Map<String, dynamic> map, Groupe groupe) {
    return Seance(
      id: map['id'],
      groupe: groupe,
      date: DateTime.parse(map['date']),
      presences: [], // You might want to populate this separately
    );
  }
}
