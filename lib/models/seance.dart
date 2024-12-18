import 'package:calendrier_etude/models/groupe.dart';

class Seance {
  String id;
  DateTime date;
  String etudiantId;
  bool present;

  Seance({
    required this.id,
    required this.date,
    required this.etudiantId,
    required this.present,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'etudiantId': etudiantId,
      'present': present ? 1 : 0,
    };
  }

  static Seance fromMap(Map<String, dynamic> map) {
    return Seance(
      id: map['id'],
      date: DateTime.parse(map['date']),
      etudiantId: map['etudiantId'],
      present: map['present'] == 1,
    );
  }
}
