import 'package:flutter/material.dart';
import '../models/seance.dart';
import '../models/groupe.dart';
import '../services/database_service.dart';

class SeanceController with ChangeNotifier {
  final DatabaseService _databaseService = DatabaseService();

  Future<void> ajouterSeance(Seance seance) async {
    await _databaseService.insertSeance(seance);
    notifyListeners();
  }

  Future<void> marquerPresence(
      String seanceId, String etudiantId, bool present, Groupe groupe) async {
    final seance = await _databaseService.getSeance(seanceId, groupe);
    final presence =
        seance.presences.firstWhere((p) => p.etudiantId == etudiantId);
    presence.present = present;
    await _databaseService.updateSeance(seance);
    notifyListeners();
  }
}
