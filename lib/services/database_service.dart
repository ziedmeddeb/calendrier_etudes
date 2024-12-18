import 'package:calendrier_etude/models/etudiant_presence.dart';
import 'package:calendrier_etude/models/seance.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/material.dart';
import '../models/groupe.dart';
import '../models/etudiant.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

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
      version: 3, // Incremented version
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Create groupes table
    await db.execute('''
      CREATE TABLE groupes(
        id TEXT PRIMARY KEY,
        nom TEXT,
        jour TEXT,
        heureDebut TEXT,
        heureFin TEXT
      )
    ''');

    // Create etudiants table
    await db.execute('''
      CREATE TABLE etudiants(
        id TEXT PRIMARY KEY,
        nom TEXT,
        lycee TEXT,
        present INTEGER,
        groupeId TEXT,
        FOREIGN KEY(groupeId) REFERENCES groupes(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE seances (
        id TEXT PRIMARY KEY,
        date TEXT,
        etudiantId TEXT,
        present INTEGER
      )
    ''');
  }

  Future<void> insertGroupe(Groupe groupe, BuildContext context) async {
    final db = await database;
    await db.insert(
      'groupes',
      groupe.toMap(context),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    for (var etudiant in groupe.etudiants) {
      await insertEtudiant(etudiant, groupe.id);
    }
  }

  Future<void> insertEtudiant(Etudiant etudiant, String groupeId) async {
    final db = await database;
    await db.insert(
      'etudiants',
      etudiant.toMap(groupeId),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Groupe>> getGroupes(BuildContext context) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('groupes');
    List<Groupe> groupes = [];
    for (var map in maps) {
      List<Etudiant> etudiants = await getEtudiants(map['id']);
      groupes.add(Groupe.fromMap(map, etudiants));
    }
    return groupes;
  }

  Future<List<Etudiant>> getEtudiants(String groupeId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'etudiants',
      where: 'groupeId = ?',
      whereArgs: [groupeId],
    );
    return List.generate(maps.length, (i) {
      return Etudiant.fromMap(maps[i]);
    });
  }

  Future<void> updateEtudiant(Etudiant etudiant, String groupeId) async {
    final db = await database;
    await db.update(
      'etudiants',
      etudiant.toMap(groupeId),
      where: 'id = ?',
      whereArgs: [etudiant.id],
    );
  }

  Future<void> deleteGroupe(String groupeId) async {
    final db = await database;
    await db.delete(
      'groupes',
      where: 'id = ?',
      whereArgs: [groupeId],
    );
    await db.delete(
      'etudiants',
      where: 'groupeId = ?',
      whereArgs: [groupeId],
    );
  }

  Future<void> insertSeance(Seance seance) async {
    final db = await database;
    await db.insert(
      'seances',
      seance.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateSeance(Seance seance) async {
    final db = await database;
    await db.update(
      'seances',
      seance.toMap(),
      where: 'id = ?',
      whereArgs: [seance.id],
    );
    await db.delete(
      'seance_etudiants',
      where: 'seanceId = ?',
      whereArgs: [seance.id],
    );
  }

  Future<List<Seance>> getSeancesByDate(DateTime date) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'seances',
      where: 'date = ?',
      whereArgs: [date.toIso8601String()],
    );

    return List.generate(maps.length, (i) {
      return Seance.fromMap(maps[i]);
    });
  }

  Future<void> deleteDatabaseAndRecreate() async {
    // Get the path to the database
    String path = join(await getDatabasesPath(), 'app_database.db');

    // Delete the database
    await deleteDatabase(path);
    print('Database deleted.');

    // Reopen the database, which will recreate it
    _database = await _initDatabase();
    print('Database recreated.');
  }
}
