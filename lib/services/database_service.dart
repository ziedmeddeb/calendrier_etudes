import 'package:calendrier_etude/models/custom_seance.dart';
import 'package:calendrier_etude/models/etudiant_presence.dart';
import 'package:calendrier_etude/models/paiement_hisotrique.dart';
import 'package:calendrier_etude/models/seance.dart';
import 'package:calendrier_etude/models/student_group.dart';
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
        unpaidSessions INTEGER DEFAULT 0,
        FOREIGN KEY(groupeId) REFERENCES groupes(id)
      )
    ''');

    await db.execute('''
  CREATE TABLE seances(
    id TEXT PRIMARY KEY,
    date TEXT NOT NULL,
    etudiantId TEXT NOT NULL,
    present INTEGER NOT NULL
  )
''');

    await db.execute('''
      CREATE TABLE custom_seances(
        id TEXT PRIMARY KEY,
        groupeId TEXT,
        startTime TEXT,
        endTime TEXT,
        FOREIGN KEY (groupeId) REFERENCES groupes (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE payments(
        id TEXT PRIMARY KEY,
        etudiantId TEXT NOT NULL,
        numberOfSessions INTEGER NOT NULL,
        date TEXT NOT NULL,
        FOREIGN KEY(etudiantId) REFERENCES etudiants(id)
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
    print('update ${etudiant.toMap(groupeId)}');
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

  // Future<void> insertSeance(Seance seance) async {
  //   print("insertSeance");
  //   final db = await database;
  //   print(seance.toMap());
  //   await db.insert(
  //     'seances',
  //     seance.toMap(),
  //     conflictAlgorithm: ConflictAlgorithm.replace,
  //   );
  // }

  // Future<void> updateSeance(Seance seance) async {
  //   print("updateSeance");
  //   final db = await database;
  //   await db.update(
  //     'seances',
  //     seance.toMap(),
  //     where: 'id = ?',
  //     whereArgs: [seance.id],
  //   );
  //   await db.delete(
  //     'seance_etudiants',
  //     where: 'seanceId = ?',
  //     whereArgs: [seance.id],
  //   );
  // }

  Future<List<Seance>> getSeancesByDate(DateTime date) async {
    final db = await database;

    // Format the date to match SQLite date format (YYYY-MM-DD)
    final String formattedDate =
        "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

    print('Querying seances for date: $formattedDate'); // Debug log

    final List<Map<String, dynamic>> maps = await db.rawQuery(
      'SELECT * FROM seances WHERE date(date) = date(?)',
      [formattedDate],
    );

    print('Found ${maps.length} seances'); // Debug log

    return List.generate(maps.length, (i) {
      print('Seance ${i + 1}: ${maps[i]}'); // Debug log for each seance
      return Seance.fromMap(maps[i]);
    });
  }

// When inserting a seance, make sure to format the date consistently
  Future<void> insertSeance(Seance seance) async {
    final db = await database;

    // Format the date consistently
    final String formattedDate =
        "${seance.date.year.toString().padLeft(4, '0')}-${seance.date.month.toString().padLeft(2, '0')}-${seance.date.day.toString().padLeft(2, '0')}";

    Map<String, dynamic> seanceMap = seance.toMap();
    seanceMap['date'] = formattedDate;

    await db.insert(
      'seances',
      seanceMap,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
  // Future<List<Seance>> getSeances() async {
  //   final db = await database;
  //   final List<Map<String, dynamic>> maps = await db.query(
  //     'seances',
  //   );

  //   return List.generate(maps.length, (i) {
  //     return Seance.fromMap(maps[i]);
  //   });
  // }

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

  Future<void> updateAttendance(
      String etudiantId, bool present, DateTime date) async {
    final db = await database;
    await db.update(
      'seances',
      {'present': present ? 1 : 0},
      where: 'etudiantId = ? AND date = ?',
      whereArgs: [etudiantId, date.toIso8601String()],
    );
  }

  Future<List<Etudiant>> getAllEtudiants() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('etudiants');

    return List.generate(maps.length, (i) {
      return Etudiant.fromMap(maps[i]);
    });
  }

  Future<Etudiant?> getEtudiantById(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'etudiants',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return Etudiant.fromMap(maps.first);
  }

  Future<void> deleteEtudiantFromGroupe(
      String groupeId, String etudiantId) async {
    final db = await database;
    await db.delete(
      'etudiants',
      where: 'id = ? AND groupeId = ?',
      whereArgs: [etudiantId, groupeId],
    );
  }

  Future<void> updateEtudiantInGroupe(
      String groupeId, Etudiant updatedEtudiant) async {
    final db = await database;
    await db.update(
      'etudiants',
      updatedEtudiant.toMap(groupeId),
      where: 'id = ? AND groupeId = ?',
      whereArgs: [updatedEtudiant.id, groupeId],
    );
  }

  Future<void> updateGroupe(Groupe updatedGroupe, BuildContext context) async {
    final db = await database;
    await db.update(
      'groupes',
      updatedGroupe.toMap(context),
      where: 'id = ?',
      whereArgs: [updatedGroupe.id],
    );
  }

  Future<void> removeExternalStudent(String studentId) async {
    final db = await database;
    await db.delete(
      'seances',
      where: 'etudiantId = ?',
      whereArgs: [studentId],
    );
  }

  Future<void> insertCustomSeance(CustomSeance customSeance) async {
    final db = await database;
    await db.insert(
      'custom_seances',
      customSeance.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<CustomSeance>> getCustomSeances() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('custom_seances');
    return List.generate(maps.length, (i) => CustomSeance.fromMap(maps[i]));
  }

  Future<void> deleteCustomSeance(String id) async {
    final db = await database;
    await db.delete(
      'custom_seances',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Seance>> getSeancesByEtudiantId(String etudiantId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('seances',
        where: 'etudiantId = ?',
        whereArgs: [etudiantId],
        orderBy: 'date ASC' // Changed to ASC for oldest to newest
        );

    return List.generate(maps.length, (i) {
      return Seance.fromMap(maps[i]);
    });
  }

  // Future<String?> findStudentOriginalGroup(String studentId) async {
  //   final db = await database;
  //   final List<Map<String, dynamic>> result = await db.query(
  //     'etudiants',
  //     columns: ['groupeId'],
  //     where: 'id = ?',
  //     whereArgs: [studentId],
  //   );

  //   if (result.isNotEmpty) {
  //     return result.first['groupeId'] as String;
  //   }
  //   return null;
  // }

  // Future<void> updateEtudiantUnpaidSessions(Etudiant etudiant) async {
  //   final db = await database;
  //   await db.update(
  //     'etudiants',
  //     {'unpaidSessions': etudiant.unpaidSessions},
  //     where: 'id = ?',
  //     whereArgs: [etudiant.id],
  //   );
  // }

  Future<Seance?> getSeanceForStudentOnDate(
      String studentId, DateTime date) async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.query(
      'seances',
      where: 'etudiantId = ? AND date = ?',
      whereArgs: [studentId, date.toIso8601String()],
    );

    if (result.isNotEmpty) {
      return Seance.fromMap(result.first);
    }
    return null;
  }

  Future<void> updateSeance(Seance seance) async {
    final db = await database;
    await db.update(
      'seances',
      seance.toMap(),
      where: 'id = ?',
      whereArgs: [seance.id],
    );
  }

  Future<String?> findStudentOriginalGroup(String studentId) async {
    final db = await database;
    try {
      final List<Map<String, dynamic>> result = await db.query(
        'etudiants',
        where: 'id = ?',
        whereArgs: [studentId],
      );

      if (result.isNotEmpty) {
        final student = Etudiant.fromMap(result.first);
        return result.first['groupeId'] as String;
      }
      return null;
    } catch (e) {
      print('Error finding student original group: $e');
      return null;
    }
  }

  Future<void> updateEtudiantUnpaidSessions(
      Etudiant etudiant, String groupId) async {
    final db = await database;
    await db.update(
      'etudiants',
      {
        'unpaidSessions': etudiant.unpaidSessions,
        'groupeId': groupId // Ensure we keep the original group ID
      },
      where: 'id = ?',
      whereArgs: [etudiant.id],
    );
  }

  Future<Map<String, List<StudentGroupInfo>>> getStudentsByDay() async {
    final db = await database;
    final Map<String, List<StudentGroupInfo>> studentsByDay = {};

    // Get all groups
    final List<Map<String, dynamic>> groups = await db.query('groupes');

    for (var group in groups) {
      final String day = group['jour'] as String;
      if (!studentsByDay.containsKey(day)) {
        studentsByDay[day] = [];
      }

      // Get students for this group
      final students = await getEtudiants(group['id'] as String);
      for (var student in students) {
        studentsByDay[day]!.add(
          StudentGroupInfo(
            student: student,
            groupName: group['nom'] as String,
            lycee: student.lycee,
            unpaidSessions: student.unpaidSessions,
          ),
        );
      }
    }

    // Sort students within each day
    studentsByDay.forEach((day, students) {
      students.sort((a, b) =>
          a.student.nom.toLowerCase().compareTo(b.student.nom.toLowerCase()));
    });

    return studentsByDay;
  }

  Future<void> insertPayment(Payment payment) async {
    final db = await database;

    // Réduire le nombre de séances non payées de l'étudiant
    final student = await getEtudiantById(payment.etudiantId);
    if (student != null) {
      final newUnpaidSessions =
          student.unpaidSessions - payment.numberOfSessions;

      // Update student's unpaid sessions
      await db.update(
        'etudiants',
        {'unpaidSessions': newUnpaidSessions},
        where: 'id = ?',
        whereArgs: [payment.etudiantId],
      );
    }

    // Insert the payment record
    await db.insert(
      'payments',
      payment.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deletePayment(String paymentId) async {
    final db = await database;

    // Get payment details before deleting
    final List<Map<String, dynamic>> paymentMaps = await db.query(
      'payments',
      where: 'id = ?',
      whereArgs: [paymentId],
    );

    if (paymentMaps.isNotEmpty) {
      final payment = Payment.fromMap(paymentMaps.first);

      // Add back the unpaid sessions to the student
      final student = await getEtudiantById(payment.etudiantId);
      if (student != null) {
        final newUnpaidSessions =
            student.unpaidSessions + payment.numberOfSessions;
        await db.update(
          'etudiants',
          {'unpaidSessions': newUnpaidSessions},
          where: 'id = ?',
          whereArgs: [payment.etudiantId],
        );
      }

      // Delete the payment record
      await db.delete(
        'payments',
        where: 'id = ?',
        whereArgs: [paymentId],
      );
    }
  }

  Future<List<Payment>> getPaymentsByEtudiantId(String etudiantId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'payments',
      where: 'etudiantId = ?',
      whereArgs: [etudiantId],
      orderBy: 'date DESC',
    );
    return List.generate(maps.length, (i) => Payment.fromMap(maps[i]));
  }

  // Future<void> deletePayment(String paymentId) async {
  //   final db = await database;
  //   await db.delete(
  //     'payments',
  //     where: 'id = ?',
  //     whereArgs: [paymentId],
  //   );
  // }

  Future<void> addUnpaidSessions(
      String etudiantId, String groupId, int numberOfSessions) async {
    final db = await database;

    // Récupérer l'étudiant actuel
    final List<Map<String, dynamic>> result = await db.query(
      'etudiants',
      where: 'id = ?',
      whereArgs: [etudiantId],
    );

    if (result.isNotEmpty) {
      final currentUnpaidSessions = result.first['unpaidSessions'] as int? ?? 0;
      final newUnpaidSessions = currentUnpaidSessions + numberOfSessions;

      await db.update(
        'etudiants',
        {'unpaidSessions': newUnpaidSessions},
        where: 'id = ?',
        whereArgs: [etudiantId],
      );
    }
  }
}
