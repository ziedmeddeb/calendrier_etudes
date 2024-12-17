import 'package:flutter/material.dart';
import '../models/groupe.dart';
import '../models/etudiant.dart';
import '../services/database_service.dart';

class GroupeController with ChangeNotifier {
  final DatabaseService _databaseService = DatabaseService();

  List<Groupe> _groupes = [];

  List<Groupe> get groupes => _groupes;

  GroupeController(BuildContext context) {
    _loadGroupes(context);
  }

  Future<void> _loadGroupes(BuildContext context) async {
    _groupes = await _databaseService.getGroupes(context);
    notifyListeners();
  }

  Future<void> ajouterGroupe(Groupe groupe, BuildContext context) async {
    await _databaseService.insertGroupe(groupe, context);
    _groupes.add(groupe);
    notifyListeners();
  }

  Future<void> ajouterEtudiantAuGroupe(
      String groupeId, Etudiant etudiant) async {
    await _databaseService.insertEtudiant(etudiant, groupeId);
    final groupe = _groupes.firstWhere((g) => g.id == groupeId);
    groupe.etudiants.add(etudiant);
    notifyListeners();
  }

  Future<void> marquerPresence(
      String groupeId, String etudiantId, bool present) async {
    final groupe = _groupes.firstWhere((g) => g.id == groupeId);
    final etudiant = groupe.etudiants.firstWhere((e) => e.id == etudiantId);
    etudiant.present = present;
    await _databaseService.updateEtudiant(etudiant, groupeId);
    notifyListeners();
  }

  void supprimerEtudiantDuGroupe(String groupeId, String etudiantId) {
    final groupe = _groupes.firstWhere((g) => g.id == groupeId);
    groupe.etudiants.removeWhere((etudiant) => etudiant.id == etudiantId);
    notifyListeners();
  }

  void modifierEtudiantDuGroupe(String groupeId, Etudiant updatedEtudiant) {
    final groupe = _groupes.firstWhere((g) => g.id == groupeId);
    final index = groupe.etudiants
        .indexWhere((etudiant) => etudiant.id == updatedEtudiant.id);
    if (index != -1) {
      groupe.etudiants[index] = updatedEtudiant;
      notifyListeners();
    }
  }

  void modifierGroupe(Groupe updatedGroupe) {
    final index = _groupes.indexWhere((g) => g.id == updatedGroupe.id);
    if (index != -1) {
      _groupes[index] = updatedGroupe;
      notifyListeners();
    }
  }

  Future<void> supprimerGroupe(String groupeId) async {
    await _databaseService.deleteGroupe(groupeId);
    _groupes.removeWhere((groupe) => groupe.id == groupeId);
    notifyListeners();
  }
}
