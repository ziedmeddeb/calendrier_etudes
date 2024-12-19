import 'package:flutter/material.dart';
import 'etudiant.dart';

class Groupe {
  String id;
  String nom;
  List<Etudiant> etudiants;
  String jour;
  TimeOfDay heureDebut;
  TimeOfDay heureFin;

  Groupe({
    required this.id,
    required this.nom,
    required this.etudiants,
    required this.jour,
    required this.heureDebut,
    required this.heureFin,
  });

  Map<String, dynamic> toMap(BuildContext context) {
    return {
      'id': id,
      'nom': nom,
      'jour': jour,
      'heureDebut': heureDebut.format(context),
      'heureFin': heureFin.format(context),
    };
  }

  static Groupe fromMap(Map<String, dynamic> map, List<Etudiant> etudiants) {
    return Groupe(
      id: map['id'],
      nom: map['nom'],
      etudiants: etudiants,
      jour: map['jour'],
      heureDebut: TimeOfDay(
        hour: int.parse(map['heureDebut'].split(':')[0]),
        minute: int.parse(map['heureDebut'].split(':')[1]),
      ),
      heureFin: TimeOfDay(
        hour: int.parse(map['heureFin'].split(':')[0]),
        minute: int.parse(map['heureFin'].split(':')[1]),
      ),
    );
  }

  @override
  String toString() {
    return 'Groupe{id: $id, nom: $nom, etudiants: $etudiants, jour: $jour, heureDebut: $heureDebut, heureFin: $heureFin}';
  }
}
