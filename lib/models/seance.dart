import 'package:calendrier_etude/models/groupe.dart';

class Seance {
  String id;
  DateTime date;
  Groupe groupe;

  Seance({required this.id, required this.date, required this.groupe});
}
