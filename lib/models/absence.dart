import 'package:calendrier_etude/models/etudiant.dart';
import 'package:calendrier_etude/models/seance.dart';

class Absence {
  String id;
  Etudiant etudiant;
  Seance seance;

  Absence({required this.id, required this.etudiant, required this.seance});
}
