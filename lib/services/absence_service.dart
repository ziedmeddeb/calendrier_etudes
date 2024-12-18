import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/seance.dart';
import '../models/groupe.dart';
import '../models/etudiant_presence.dart';

class AbsenceService {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'app_database.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Create seances table
    await db.execute('''
      CREATE TABLE seances(
        id TEXT PRIMARY KEY,
        groupeId TEXT,
        date TEXT,
        FOREIGN KEY(groupeId) REFERENCES groupes(id)
      )
    ''');

    // Create seance_etudiants table
    await db.execute('''
      CREATE TABLE seance_etudiants(
        seanceId TEXT,
        etudiantId TEXT,
        present INTEGER,
        PRIMARY KEY(seanceId, etudiantId),
        FOREIGN KEY(seanceId) REFERENCES seances(id),
        FOREIGN KEY(etudiantId) REFERENCES etudiants(id)
      )
    ''');
  }

  Future<void> insertSeance(Seance seance) async {
    final db = await database;
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
    final db = await database;

    // Delete existing presence records
    await db.delete(
      'seance_etudiants',
      where: 'seanceId = ?',
      whereArgs: [seance.id],
    );

    // Reinsert presence records
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

  Future<Seance> getSeance(String seanceId, Groupe groupe) async {
    final db = await database;

    // Fetch seance details
    final List<Map<String, dynamic>> seanceMaps = await db.query(
      'seances',
      where: 'id = ?',
      whereArgs: [seanceId],
    );

    if (seanceMaps.isEmpty) {
      throw Exception('Seance not found');
    }

    // Fetch presence details
    final List<Map<String, dynamic>> presenceMaps = await db.query(
      'seance_etudiants',
      where: 'seanceId = ?',
      whereArgs: [seanceId],
    );

    // Create presence objects
    final presences = presenceMaps
        .map((presenceMap) => EtudiantPresence(
            etudiantId: presenceMap['etudiantId'],
            present: presenceMap['present'] == 1))
        .toList();

    // Create and return seance with fetched data
    return Seance(
      id: seanceId,
      groupe: groupe,
      date: DateTime.parse(seanceMaps.first['date']),
      presences: presences,
    );
  }
}
