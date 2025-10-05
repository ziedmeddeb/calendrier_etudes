// lib/models/custom_seance.dart

class CustomSeance {
  final String id;
  final String groupeId;
  final DateTime startTime;
  final DateTime endTime;
  final String name;

  CustomSeance(
      {required this.id,
      required this.groupeId,
      required this.startTime,
      required this.endTime,
      this.name = 'Séance'});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'groupeId': groupeId,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'name': name,
    };
  }

  factory CustomSeance.fromMap(Map<String, dynamic> map) {
    return CustomSeance(
      id: map['id'],
      groupeId: map['groupeId'],
      startTime: DateTime.parse(map['startTime']),
      endTime: DateTime.parse(map['endTime']),
      name: map['name'] ?? 'Séance',
    );
  }
}
