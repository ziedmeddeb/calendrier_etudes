class Etudiant {
  String id;
  String nom;
  String lycee;
  bool present;
  int unpaidSessions;

  Etudiant({
    required this.id,
    required this.nom,
    required this.lycee,
    this.present = false,
    this.unpaidSessions = 0,
  });

  Map<String, dynamic> toMap(String groupeId) {
    return {
      'id': id,
      'nom': nom,
      'lycee': lycee,
      'present': present ? 1 : 0,
      'groupeId': groupeId,
      'unpaidSessions': unpaidSessions,
    };
  }

  static Etudiant fromMap(Map<String, dynamic> map) {
    return Etudiant(
      id: map['id'],
      nom: map['nom'],
      lycee: map['lycee'],
      present: map['present'] == 1,
      unpaidSessions: map['unpaidSessions'],
    );
  }

  @override
  String toString() {
    return 'Etudiant{id: $id, nom: $nom, lycee: $lycee, present: $present,unpaidSessions: $unpaidSessions}';
  }
}
