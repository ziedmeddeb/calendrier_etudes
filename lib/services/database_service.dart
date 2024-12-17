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
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE groupes(
        id TEXT PRIMARY KEY,
        nom TEXT,
        jour TEXT,
        heureDebut TEXT,
        heureFin TEXT
      )
    ''');
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
}
