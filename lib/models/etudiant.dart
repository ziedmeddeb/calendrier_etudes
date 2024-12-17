class Etudiant {
  String id;
  String nom;
  String lycee;
  bool present;

  Etudiant(
      {required this.id,
      required this.nom,
      required this.lycee,
      this.present = false});

  Map<String, dynamic> toMap(String groupeId) {
    return {
      'id': id,
      'nom': nom,
      'lycee': lycee,
      'present': present ? 1 : 0,
      'groupeId': groupeId,
    };
  }

  static Etudiant fromMap(Map<String, dynamic> map) {
    return Etudiant(
      id: map['id'],
      nom: map['nom'],
      lycee: map['lycee'],
      present: map['present'] == 1,
    );
  }
}
