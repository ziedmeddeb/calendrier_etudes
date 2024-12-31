import 'package:calendrier_etude/models/etudiant.dart';

class StudentGroupInfo {
  final Etudiant student;
  final String groupName;
  final String lycee;
  final int unpaidSessions;

  StudentGroupInfo({
    required this.student,
    required this.groupName,
    required this.lycee,
    required this.unpaidSessions,
  });
}
