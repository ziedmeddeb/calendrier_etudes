class EtudiantPresence {
  String etudiantId;
  bool present;

  EtudiantPresence({required this.etudiantId, this.present = false});

  Map<String, dynamic> toMap() {
    return {
      'etudiantId': etudiantId,
      'present': present ? 1 : 0,
    };
  }

  static EtudiantPresence fromMap(Map<String, dynamic> map) {
    return EtudiantPresence(
      etudiantId: map['etudiantId'],
      present: map['present'] == 1,
    );
  }
}
