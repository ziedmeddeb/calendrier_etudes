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
      version: 5,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 4) {
      await db.execute('ALTER TABLE seances ADD COLUMN name TEXT DEFAULT "Séance"');
    }
    if (oldVersion < 5) {
      await db.execute('ALTER TABLE etudiants ADD COLUMN isGratuit INTEGER DEFAULT 0');
    }
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
        isGratuit INTEGER DEFAULT 0,
        FOREIGN KEY(groupeId) REFERENCES groupes(id)
      )
    ''');

    await db.execute('''
  CREATE TABLE seances(
    id TEXT PRIMARY KEY,
    date TEXT NOT NULL,
    etudiantId TEXT NOT NULL,
    present INTEGER NOT NULL,
    name TEXT DEFAULT 'Séance'
  )
''');

    await db.execute('''
      CREATE TABLE custom_seances(
        id TEXT PRIMARY KEY,
        groupeId TEXT,
        startTime TEXT,
        endTime TEXT,
        name TEXT DEFAULT 'Séance',
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

  // In DatabaseService class

  Future<List<Seance>> getSeancesByDate(DateTime date) async {
    final db = await database;

    // Create a range that covers exactly the hour we want
    final startDateTime = DateTime(
      date.year,
      date.month,
      date.day,
      date.hour,
    );

    final endDateTime = startDateTime.add(Duration(hours: 1));

    final startStr = startDateTime.toIso8601String();
    final endStr = endDateTime.toIso8601String();

    print('Debug: Query time range:');
    print('Start: $startStr');
    print('End: $endStr');

    // First, let's see what's in the database
    final allSeances = await db.query('seances');
    print('Debug: All seances in database:');
    for (var seance in allSeances) {
      print('Seance date: ${seance['date']}');
    }

    // Now perform our filtered query
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
    SELECT * FROM seances 
    WHERE datetime(date) >= datetime(?) 
    AND datetime(date) < datetime(?)
  ''', [startStr, endStr]);

    print('Debug: Found ${maps.length} seances for this time slot');
    for (var seance in maps) {
      print('Found seance: ${seance['date']}');
    }

    return List.generate(maps.length, (i) {
      return Seance.fromMap(maps[i]);
    });
  }

  Future<void> insertSeance(Seance seance) async {
    final db = await database;

    // Normalize the date to store only hour precision
    final normalizedDate = DateTime(
      seance.date.year,
      seance.date.month,
      seance.date.day,
      seance.date.hour,
    );

    Map<String, dynamic> seanceMap = seance.toMap();
    seanceMap['date'] = normalizedDate.toIso8601String();

    print('Debug: Inserting seance with date: ${seanceMap['date']}');

    await db.insert(
      'seances',
      seanceMap,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> cleanupSeanceDates() async {
    final db = await database;

    print('Debug: Starting date cleanup');

    final List<Map<String, dynamic>> maps = await db.query('seances');
    print('Found ${maps.length} seances to clean');

    for (var map in maps) {
      try {
        final DateTime originalDate = DateTime.parse(map['date']);

        // Normalize to hour precision
        final normalizedDate = DateTime(
          originalDate.year,
          originalDate.month,
          originalDate.day,
          originalDate.hour,
        );

        final normalizedStr = normalizedDate.toIso8601String();

        print('Cleaning seance ${map['id']}: ${map['date']} -> $normalizedStr');

        await db.update(
          'seances',
          {'date': normalizedStr},
          where: 'id = ?',
          whereArgs: [map['id']],
        );
      } catch (e) {
        print('Error cleaning up date for seance ${map['id']}: $e');
      }
    }

    print('Debug: Cleanup completed');
  }
// // When inserting a seance, make sure to store the full datetime
//   Future<void> insertSeance(Seance seance) async {
//     final db = await database;

//     // Format the date with time
//     final String formattedDateTime =
//         "${seance.date.year.toString().padLeft(4, '0')}-${seance.date.month.toString().padLeft(2, '0')}-${seance.date.day.toString().padLeft(2, '0')} ${seance.date.hour.toString().padLeft(2, '0')}:${seance.date.minute.toString().padLeft(2, '0')}:00";

//     Map<String, dynamic> seanceMap = seance.toMap();
//     seanceMap['date'] = formattedDateTime;

//     await db.insert(
//       'seances',
//       seanceMap,
//       conflictAlgorithm: ConflictAlgorithm.replace,
//     );
//   }

// // When inserting a seance, make sure to format the date consistently
//   Future<void> insertSeance(Seance seance) async {
//     final db = await database;

//     // Format the date consistently
//     final String formattedDate =
//         "${seance.date.year.toString().padLeft(4, '0')}-${seance.date.month.toString().padLeft(2, '0')}-${seance.date.day.toString().padLeft(2, '0')}";

//     Map<String, dynamic> seanceMap = seance.toMap();
//     seanceMap['date'] = formattedDate;

//     await db.insert(
//       'seances',
//       seanceMap,
//       conflictAlgorithm: ConflictAlgorithm.replace,
//     );
//   }
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
    print('Debug: Inserting custom seance with name: ${customSeance.name}');

    // Explicitly include all fields in the insert
    final map = {
      'id': customSeance.id,
      'groupeId': customSeance.groupeId,
      'startTime': customSeance.startTime.toIso8601String(),
      'endTime': customSeance.endTime.toIso8601String(),
      'name': customSeance.name,
    };

    print('Debug: Inserting map: $map');

    await db.insert(
      'custom_seances',
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Verify the insertion
    final inserted = await db.query(
      'custom_seances',
      where: 'id = ?',
      whereArgs: [customSeance.id],
    );
    print('Debug: Inserted record: ${inserted.first}');
  }

  Future<List<CustomSeance>> getCustomSeances() async {
    final db = await database;

    // First, let's check the table structure
    final tableInfo = await db.rawQuery('PRAGMA table_info(custom_seances)');
    print('Debug: Table structure:');
    print(tableInfo);

    final List<Map<String, dynamic>> maps = await db.query('custom_seances');
    print('Debug: Raw custom seances data: $maps');

    return List.generate(maps.length, (i) {
      final customSeance = CustomSeance.fromMap(maps[i]);
      print('Debug: Created CustomSeance with name: ${customSeance.name}');
      return customSeance;
    });
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

  Future<void> updateSeance(Seance seance, String groupid) async {
    final db = await database;

    // First update the seance
    await db.update(
      'seances',
      seance.toMap(),
      where: 'id = ?',
      whereArgs: [seance.id],
    );

    // Get the student to find their group
    final student = await getEtudiantById(seance.etudiantId);
    if (student != null) {
      // Also update any matching custom session
      await updateCustomSessionName(seance.date, groupid, seance.name);
    }
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

  Future<void> addNameColumnToTables() async {
    final db = await database;

    // Check and add name column to seances table
    var seancesColumns = await db.rawQuery('PRAGMA table_info(seances)');
    bool hasNameColumnSeances =
        seancesColumns.any((column) => column['name'] == 'name');

    if (!hasNameColumnSeances) {
      await db
          .execute('ALTER TABLE seances ADD COLUMN name TEXT DEFAULT "Séance"');
    }

    // Check and add name column to custom_seances table
    var customSeancesColumns =
        await db.rawQuery('PRAGMA table_info(custom_seances)');
    bool hasNameColumnCustom =
        customSeancesColumns.any((column) => column['name'] == 'name');

    if (!hasNameColumnCustom) {
      await db.execute(
          'ALTER TABLE custom_seances ADD COLUMN name TEXT DEFAULT "Séance"');
    }
  }

  Future<List<Seance>> getAllSeancesInRange(
      DateTime start, DateTime end) async {
    final db = await database;

    final startStr = start.toIso8601String();
    final endStr = end.toIso8601String();

    final List<Map<String, dynamic>> maps = await db.rawQuery('''
    SELECT * FROM seances 
    WHERE datetime(date) >= datetime(?) 
    AND datetime(date) <= datetime(?)
  ''', [startStr, endStr]);

    return List.generate(maps.length, (i) {
      return Seance.fromMap(maps[i]);
    });
  }

  Future<void> createHiddenSeancesTable() async {
    final db = await database;
    await db.execute('''
    CREATE TABLE IF NOT EXISTS hidden_seances(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      date TEXT,
      groupe_id TEXT,
      UNIQUE(date, groupe_id)
    )
  ''');
  }

  Future<void> hideSeance(DateTime date, String groupeId) async {
    final db = await database;
    final normalizedDate =
        DateTime(date.year, date.month, date.day, date.hour).toIso8601String();

    await db.insert(
      'hidden_seances',
      {
        'date': normalizedDate,
        'groupe_id': groupeId,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getHiddenSeances() async {
    final db = await database;
    return await db.query('hidden_seances');
  }

  Future<void> deleteSeance(String etudiantId, DateTime date) async {
    final db = await database;

    try {
      // Normalize the date to hour precision
      final normalizedDate = DateTime(
        date.year,
        date.month,
        date.day,
        date.hour,
      );
      final dateStr = normalizedDate.toIso8601String();

      print(
          'Debug: Attempting to delete seance for student $etudiantId on date $dateStr');

      // Get the seance before deleting to check if it was marked as present
      final List<Map<String, dynamic>> seances = await db.query(
        'seances',
        where: 'etudiantId = ? AND date = ?',
        whereArgs: [etudiantId, dateStr],
      );

      if (seances.isNotEmpty) {
        final seance = seances.first;
        final wasPresent = seance['present'] == 1;

        // Use a transaction to ensure both operations complete together
        await db.transaction((txn) async {
          // Delete the seance
          await txn.delete(
            'seances',
            where: 'etudiantId = ? AND date = ?',
            whereArgs: [etudiantId, dateStr],
          );

          print('Debug: Seance deleted successfully');

          // If the student was marked as present, decrement their unpaid sessions
          if (wasPresent) {
            // Get the student's current unpaid sessions count
            final List<Map<String, dynamic>> studentResult = await txn.query(
              'etudiants',
              columns: ['unpaidSessions', 'groupeId', 'isGratuit'],
              where: 'id = ?',
              whereArgs: [etudiantId],
            );

            if (studentResult.isNotEmpty) {
              final isGratuit = studentResult.first['isGratuit'] == 1;
              if (!isGratuit) {
                final currentUnpaidSessions =
                    studentResult.first['unpaidSessions'] as int;
                final groupId = studentResult.first['groupeId'] as String;

                // Update the student's unpaid sessions
                await txn.update(
                  'etudiants',
                  {
                    'unpaidSessions':
                        currentUnpaidSessions > 0 ? currentUnpaidSessions - 1 : 0,
                    'groupeId': groupId // Preserve the original group ID
                  },
                  where: 'id = ?',
                  whereArgs: [etudiantId],
                );

                print('Debug: Updated unpaid sessions for student $etudiantId');
              }
            }
          }
        });
      } else {
        print('Debug: No seance found to delete');
      }
    } catch (e) {
      print('Error in deleteSeance: $e');
      throw e; // Re-throw the error for handling in the UI
    }
  }

  Future<void> deleteAllSeances() async {
    final db = await database;
    await db.delete('seances');
    await db.delete('hidden_seances');
    await db.delete('payments');
  }

  Future<void> resetEtudiantUnpaidSessions() async {
    final db = await database;
    await db.update(
      'etudiants',
      {
        'unpaidSessions': 0,
        // Ensure we keep the original group ID
      },
    );
  }

  Future<String?> getCustomSessionName(DateTime date, String groupId) async {
    final db = await database;

    final List<Map<String, dynamic>> customSessions = await db.query(
      'custom_seances',
      where: 'groupeId = ? AND date(startTime) = date(?)',
      whereArgs: [
        groupId,
        date.toIso8601String(),
      ],
    );

    if (customSessions.isNotEmpty) {
      return customSessions.first['name'] as String?;
    }
    return null;
  }

  /// Swaps two students between groups atomically, preserving all history.
  Future<void> swapEtudiants(String etudiantAId, String groupeAId,
      String etudiantBId, String groupeBId) async {
    final db = await database;
    await db.transaction((txn) async {
      // Move A → B's group
      await txn.update(
        'etudiants',
        {'groupeId': groupeBId},
        where: 'id = ? AND groupeId = ?',
        whereArgs: [etudiantAId, groupeAId],
      );
      // Move B → A's group
      await txn.update(
        'etudiants',
        {'groupeId': groupeAId},
        where: 'id = ? AND groupeId = ?',
        whereArgs: [etudiantBId, groupeBId],
      );
    });
  }

  /// Transfers a student from one group to another, preserving all history.
  Future<void> transferEtudiantToGroupe(
      String etudiantId, String fromGroupeId, String toGroupeId) async {
    final db = await database;
    await db.update(
      'etudiants',
      {'groupeId': toGroupeId},
      where: 'id = ? AND groupeId = ?',
      whereArgs: [etudiantId, fromGroupeId],
    );
  }

  Future<void> updateCustomSessionName(
      DateTime date, String groupId, String newName) async {
    final db = await database;

    // Find any custom session that matches this date and group
    final List<Map<String, dynamic>> customSessions = await db.query(
      'custom_seances',
      where: 'groupeId = ? AND date(startTime) = date(?)',
      whereArgs: [
        groupId,
        date.toIso8601String(),
      ],
    );

    // If we found a matching custom session, update its name
    if (customSessions.isNotEmpty) {
      await db.update(
        'custom_seances',
        {'name': newName},
        where: 'id = ?',
        whereArgs: [customSessions.first['id']],
      );
    }
  }

  Future<Map<String, dynamic>> exportAllTablesForSync() async {
    final db = await database;
    final groupes = await db.query('groupes');
    final etudiants = await db.query('etudiants');
    final seances = await db.query('seances');
    final customSeances = await db.query('custom_seances');
    final payments = await db.query('payments');

    List<Map<String, dynamic>> hiddenSeances = [];
    try {
      hiddenSeances = await db.query('hidden_seances');
    } catch (_) {
      hiddenSeances = [];
    }

    return {
      'groupes': groupes,
      'etudiants': etudiants,
      'seances': seances,
      'custom_seances': customSeances,
      'payments': payments,
      'hidden_seances': hiddenSeances,
    };
  }

  Future<void> importAllTablesFromSync(Map<String, dynamic> payload) async {
    final db = await database;

    await db.transaction((txn) async {
      await txn.delete('seances');
      await txn.delete('custom_seances');
      await txn.delete('payments');
      await txn.delete('etudiants');
      await txn.delete('groupes');

      try {
        await txn.delete('hidden_seances');
      } catch (_) {}

      await _insertRows(txn, 'groupes', payload['groupes']);
      await _insertRows(txn, 'etudiants', payload['etudiants']);
      await _insertRows(txn, 'seances', payload['seances']);
      await _insertRows(txn, 'custom_seances', payload['custom_seances']);
      await _insertRows(txn, 'payments', payload['payments']);

      try {
        await _insertRows(txn, 'hidden_seances', payload['hidden_seances']);
      } catch (_) {}
    });
  }

  Future<void> _insertRows(
      Transaction txn, String tableName, dynamic rawRows) async {
    if (rawRows is! List) return;

    for (final row in rawRows) {
      if (row is Map) {
        await txn.insert(
          tableName,
          Map<String, dynamic>.from(row),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    }
  }

  Future<DateTime> getLatestLocalUpdateTime() async {
    final data = await exportAllTablesForSync();
    DateTime latest = DateTime.fromMillisecondsSinceEpoch(0);

    for (final entry in data.entries) {
      final rows = entry.value;
      if (rows is! List) continue;

      for (final row in rows) {
        if (row is! Map) continue;

        final date = _tryParseDate(row['date']) ??
            _tryParseDate(row['startTime']) ??
            _tryParseDate(row['endTime']);

        if (date != null && date.isAfter(latest)) {
          latest = date;
        }
      }
    }

    return latest;
  }

  DateTime? _tryParseDate(dynamic value) {
    if (value is! String) return null;
    try {
      return DateTime.parse(value);
    } catch (_) {
      return null;
    }
  }

  /// Dashboard: total unpaid sessions for non-gratuit students
  Future<int> getTotalUnpaidSessions() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(unpaidSessions), 0) as total FROM etudiants WHERE isGratuit = 0',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Dashboard: total paid sessions from payments table
  Future<int> getTotalPaidSessions() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(numberOfSessions), 0) as total FROM payments',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
