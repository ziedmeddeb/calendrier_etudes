import 'package:uuid/uuid.dart';

class Payment {
  final String id;
  final String etudiantId;
  final int numberOfSessions;
  final DateTime date;

  Payment({
    String? id,
    required this.etudiantId,
    required this.numberOfSessions,
    required this.date,
  }) : id = id ?? Uuid().v4();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'etudiantId': etudiantId,
      'numberOfSessions': numberOfSessions,
      'date': date.toIso8601String(),
    };
  }

  factory Payment.fromMap(Map<String, dynamic> map) {
    return Payment(
      id: map['id'],
      etudiantId: map['etudiantId'],
      numberOfSessions: map['numberOfSessions'],
      date: DateTime.parse(map['date']),
    );
  }
}
