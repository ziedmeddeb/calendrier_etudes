import 'package:sqflite/sqflite.dart';
import '../models/seance.dart';
import '../models/etudiant_presence.dart';
import '../models/groupe.dart';
import 'database_service.dart';

class AbsenceService {
  static final AbsenceService _instance = AbsenceService._internal();
  factory AbsenceService() => _instance;
  AbsenceService._internal();

  DatabaseService dbService = DatabaseService();

  Future<void> insertSeance(Seance seance) async {
    final db = await dbService.database;

    await db.insert(
      'seances',
      {
        'id': seance.id,
        'groupeId': seance.groupe.id,
        'date': seance.date.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    for (var presence in seance.presences) {
      await db.insert(
        'seance_etudiants',
        {
          'seanceId': seance.id,
          'etudiantId': presence.etudiantId,
          'present': presence.present ? 1 : 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<void> updateSeance(Seance seance) async {
    final db = await dbService.database;

    for (var presence in seance.presences) {
      await db.update(
        'seance_etudiants',
        {
          'present': presence.present ? 1 : 0,
        },
        where: 'seanceId = ? AND etudiantId = ?',
        whereArgs: [seance.id, presence.etudiantId],
      );
    }
  }

  Future<Seance> getSeance(String seanceId, Groupe groupe) async {
    final db = await dbService.database;

    final List<Map<String, dynamic>> seanceMaps = await db.query(
      'seances',
      where: 'id = ?',
      whereArgs: [seanceId],
    );

    if (seanceMaps.isEmpty) {
      throw Exception('Seance not found');
    }

    final List<Map<String, dynamic>> presenceMaps = await db.query(
      'seance_etudiants',
      where: 'seanceId = ?',
      whereArgs: [seanceId],
    );

    final presences = presenceMaps
        .map((presenceMap) => EtudiantPresence(
            etudiantId: presenceMap['etudiantId'],
            present: presenceMap['present'] == 1))
        .toList();

    return Seance(
      id: seanceId,
      groupe: groupe,
      date: DateTime.parse(seanceMaps.first['date']),
      presences: presences,
    );
  }
}
