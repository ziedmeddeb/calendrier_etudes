import 'package:calendrier_etude/models/absence.dart';

class AbsenceService {
  List<Absence> _absences = [];

  List<Absence> getAbsences() => _absences;

  void ajouterAbsence(Absence absence) {
    _absences.add(absence);
  }
}
