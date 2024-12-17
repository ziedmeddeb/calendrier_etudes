import 'package:calendrier_etude/models/absence.dart';
import 'package:calendrier_etude/services/absence_service.dart';
import 'package:flutter/material.dart';

class AbsenceController with ChangeNotifier {
  final AbsenceService _absenceService;

  AbsenceController(this._absenceService);

  List<Absence> get absences => _absenceService.getAbsences();

  void ajouterAbsence(Absence absence) {
    _absenceService.ajouterAbsence(absence);
    notifyListeners();
  }
}
