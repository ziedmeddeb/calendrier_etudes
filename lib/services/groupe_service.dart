import 'package:calendrier_etude/models/etudiant.dart';
import 'package:calendrier_etude/models/groupe.dart';

class GroupeService {
  List<Groupe> _groupes = [];

  List<Groupe> getGroupes() => _groupes;

  void ajouterGroupe(Groupe groupe) {
    _groupes.add(groupe);
  }

  void ajouterEtudiantAuGroupe(String groupeId, Etudiant etudiant) {
    _groupes
        .firstWhere((groupe) => groupe.id == groupeId)
        .etudiants
        .add(etudiant);
  }
}
