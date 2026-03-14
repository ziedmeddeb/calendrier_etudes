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

  void supprimerEtudiantDuGroupe(String groupeId, String etudiantId) async {
    await _databaseService.deleteEtudiantFromGroupe(groupeId, etudiantId);
    final groupe = _groupes.firstWhere((g) => g.id == groupeId);
    groupe.etudiants.removeWhere((etudiant) => etudiant.id == etudiantId);
    notifyListeners();
  }

  void modifierEtudiantDuGroupe(
      String groupeId, Etudiant updatedEtudiant) async {
    await _databaseService.updateEtudiantInGroupe(groupeId, updatedEtudiant);
    final groupe = _groupes.firstWhere((g) => g.id == groupeId);
    final index = groupe.etudiants
        .indexWhere((etudiant) => etudiant.id == updatedEtudiant.id);
    if (index != -1) {
      groupe.etudiants[index] = updatedEtudiant;
      notifyListeners();
    }
  }

  void modifierGroupe(Groupe updatedGroupe, BuildContext context) async {
    await _databaseService.updateGroupe(updatedGroupe, context);
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

  /// Transfère un étudiant d'un groupe à un autre en préservant tout l'historique.
  Future<void> transfererEtudiant(
      String etudiantId, String fromGroupeId, String toGroupeId) async {
    await _databaseService.transferEtudiantToGroupe(
        etudiantId, fromGroupeId, toGroupeId);

    final fromGroupe = _groupes.firstWhere((g) => g.id == fromGroupeId,
        orElse: () => throw StateError('Groupe source introuvable'));
    final toGroupe = _groupes.firstWhere((g) => g.id == toGroupeId,
        orElse: () => throw StateError('Groupe destination introuvable'));

    final etudiantIndex =
        fromGroupe.etudiants.indexWhere((e) => e.id == etudiantId);
    if (etudiantIndex != -1) {
      final etudiant = fromGroupe.etudiants.removeAt(etudiantIndex);
      toGroupe.etudiants.add(etudiant);
    }
    notifyListeners();
  }

  /// Permute deux étudiants entre leurs groupes respectifs (échange de place).
  Future<void> permuterEtudiants(String etudiantAId, String groupeAId,
      String etudiantBId, String groupeBId) async {
    await _databaseService.swapEtudiants(
        etudiantAId, groupeAId, etudiantBId, groupeBId);

    final groupeA = _groupes.firstWhere((g) => g.id == groupeAId,
        orElse: () => throw StateError('Groupe A introuvable'));
    final groupeB = _groupes.firstWhere((g) => g.id == groupeBId,
        orElse: () => throw StateError('Groupe B introuvable'));

    final indexA = groupeA.etudiants.indexWhere((e) => e.id == etudiantAId);
    final indexB = groupeB.etudiants.indexWhere((e) => e.id == etudiantBId);

    if (indexA != -1 && indexB != -1) {
      final etudiantA = groupeA.etudiants.removeAt(indexA);
      final etudiantB = groupeB.etudiants.removeAt(indexB);
      groupeA.etudiants.add(etudiantB);
      groupeB.etudiants.add(etudiantA);
    }
    notifyListeners();
  }
}
