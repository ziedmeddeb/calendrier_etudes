import 'package:calendrier_etude/models/groupe.dart';
import 'package:calendrier_etude/models/seance.dart';
import 'package:calendrier_etude/services/absence_service.dart';
import 'package:flutter/foundation.dart';

class AbsenceController with ChangeNotifier {
  final AbsenceService _absenceService;

  AbsenceController(this._absenceService);

  Future<void> ajouterSeance(Seance seance) async {
    await _absenceService.insertSeance(seance);
    notifyListeners();
  }

  Future<void> marquerPresence(
      String seanceId, String etudiantId, bool present, Groupe groupe) async {
    // Fetch the current seance
    final seance = await _absenceService.getSeance(seanceId, groupe);

    // Find and update the specific student's presence
    final presence =
        seance.presences.firstWhere((p) => p.etudiantId == etudiantId);
    presence.present = present;

    // Update the seance in the database
    await _absenceService.updateSeance(seance);
    notifyListeners();
  }
}
