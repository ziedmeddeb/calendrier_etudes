import 'package:calendrier_etude/models/groupe.dart';
import 'package:calendrier_etude/models/seance.dart';
import 'package:calendrier_etude/services/absence_service.dart';
import 'package:flutter/foundation.dart';

class AbsenceController with ChangeNotifier {
  final AbsenceService _absenceService;

  AbsenceController(this._absenceService);

  Future<void> ajouterSeance(Seance seance) async {
    try {
      await _absenceService.insertSeance(seance);
      print('Seance added successfully: ${seance.id}');
      notifyListeners();
    } catch (e) {
      print('Error adding seance: $e');
    }
  }

  // New method to update the entire seance
  Future<void> updateSeance(Seance seance) async {
    try {
      await _absenceService.updateSeance(seance);
      print('Seance updated successfully: ${seance.id}');
      notifyListeners();
    } catch (e) {
      print('Error updating seance: $e');
      rethrow;
    }
  }

  Future<void> marquerPresence(
      String seanceId, String etudiantId, bool present, Groupe groupe) async {
    try {
      // Fetch the current seance
      final seance = await _absenceService.getSeance(seanceId, groupe);

      // Find and update the specific student's presence
      final presence =
          seance.presences.firstWhere((p) => p.etudiantId == etudiantId);
      presence.present = present;

      // Update the seance in the database
      await _absenceService.updateSeance(seance);

      notifyListeners();
    } catch (e) {
      print('Error marking presence: $e');
    }
  }
}
