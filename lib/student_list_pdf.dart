import 'dart:io';
import 'dart:math';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:calendrier_etude/models/student_group.dart';
import 'package:calendrier_etude/services/database_service.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class StudentsByDayScreen extends StatelessWidget {
  final List<String> daysOfWeek = [
    'Lundi',
    'Mardi',
    'Mercredi',
    'Jeudi',
    'Vendredi',
    'Samedi',
    'Dimanche'
  ];

  String _formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy', 'fr_FR').format(date);
  }

  // Helper method to organize students by group
  Map<String, List<StudentGroupInfo>> _organizeByGroup(
      List<StudentGroupInfo> students) {
    Map<String, List<StudentGroupInfo>> groupedStudents = {};

    // Sort students by group name first
    students.sort((a, b) => a.groupName.compareTo(b.groupName));

    for (var student in students) {
      if (!groupedStudents.containsKey(student.groupName)) {
        groupedStudents[student.groupName] = [];
      }
      groupedStudents[student.groupName]!.add(student);
    }

    return groupedStudents;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Étudiants par Jour'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_outlined),
            tooltip: 'Exporter en PDF',
            onPressed: () => _generatePDF(context),
          ),
        ],
      ),
      body: FutureBuilder<Map<String, List<StudentGroupInfo>>>(
        future: DatabaseService().getStudentsByDay(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erreur: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return Center(child: Text('Aucun étudiant trouvé'));
          }

          final double cellWidth = MediaQuery.of(context).size.width * 0.25;

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              child: Theme(
                data: Theme.of(context).copyWith(
                  dividerColor: Colors.black,
                ),
                child: DataTable(
                  border: TableBorder.all(
                    color: Colors.black,
                    width: 1,
                    style: BorderStyle.solid,
                  ),
                  columnSpacing: 0,
                  headingRowHeight: 60,
                  dataRowMinHeight: 80,
                  dataRowMaxHeight: 160,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black),
                  ),
                  columns: daysOfWeek
                      .map((day) => DataColumn(
                            label: Container(
                              width: cellWidth,
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              decoration: BoxDecoration(
                                border: Border(
                                  right: BorderSide(color: Colors.black),
                                ),
                              ),
                              child: Text(
                                day,
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ))
                      .toList(),
                  rows: _buildGroupedTableRows(snapshot.data!, cellWidth),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  List<DataRow> _buildGroupedTableRows(
      Map<String, List<StudentGroupInfo>> studentsByDay, double cellWidth) {
    List<DataRow> allRows = [];

    // Find the maximum number of groups and students per group across all days
    int maxRows = 0;
    for (var dayStudents in studentsByDay.values) {
      var groupedStudents = _organizeByGroup(dayStudents);
      int dayRows = 0;
      for (var groupStudents in groupedStudents.values) {
        dayRows += groupStudents.length + 1; // +1 for group header
      }
      maxRows = maxRows < dayRows ? dayRows : maxRows;
    }

    // Build rows
    for (int rowIndex = 0; rowIndex < maxRows; rowIndex++) {
      allRows.add(DataRow(
        cells: daysOfWeek.map((day) {
          final students = studentsByDay[day] ?? [];
          final groupedStudents = _organizeByGroup(students);

          // Track current position in the day's data
          int currentPosition = 0;

          for (var entry in groupedStudents.entries) {
            String groupName = entry.key;
            List<StudentGroupInfo> groupStudents = entry.value;

            // Group header position
            if (currentPosition == rowIndex) {
              return DataCell(
                Container(
                  width: cellWidth,
                  padding: EdgeInsets.all(8),
                  color: Colors.grey[200],
                  child: Text(
                    groupName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      backgroundColor: Colors.grey[200],
                    ),
                  ),
                ),
              );
            }

            // Student positions
            if (rowIndex > currentPosition &&
                rowIndex <= currentPosition + groupStudents.length) {
              final studentInfo = groupStudents[rowIndex - currentPosition - 1];
              return DataCell(
                Container(
                  width: cellWidth,
                  padding: EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        studentInfo.student.nom,
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 4),
                      Text('${studentInfo.lycee}'),
                      SizedBox(height: 4),
                      Text(
                        'Non payées: ${studentInfo.unpaidSessions}',
                        style: TextStyle(
                          color: studentInfo.unpaidSessions >= 4
                              ? Colors.red
                              : Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            currentPosition += groupStudents.length + 1;
          }

          return DataCell(Container(width: cellWidth));
        }).toList(),
      ));
    }

    return allRows;
  }

  Future<void> _generatePDF(BuildContext context) async {
    try {
      final pdf = pw.Document();
      final studentsByDay = await DatabaseService().getStudentsByDay();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          build: (pw.Context context) {
            return [
              pw.Header(
                level: 0,
                child: pw.Text(
                    'Liste des Étudiants par Jour ${_formatDate(DateTime.now())}',
                    style: pw.TextStyle(fontSize: 20)),
              ),
              pw.SizedBox(height: 20),
              pw.Table(
                border: pw.TableBorder.all(),
                children: [
                  pw.TableRow(
                    children: daysOfWeek
                        .map((day) => pw.Container(
                              padding: pw.EdgeInsets.all(8),
                              child: pw.Text(day,
                                  style: pw.TextStyle(
                                      fontWeight: pw.FontWeight.bold)),
                            ))
                        .toList(),
                  ),
                  ..._buildGroupedPDFTableRows(studentsByDay),
                ],
              ),
            ];
          },
        ),
      );

      Directory? directory;
      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) {
          directory = await getExternalStorageDirectory();
        }
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      if (directory != null) {
        final int randomNumber = Random().nextInt(100000);
        final String path =
            '${directory.path}/etudiants_par_jour_$randomNumber.pdf';
        final file = File(path);
        await file.writeAsBytes(await pdf.save());

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF sauvegardé: $path'),
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        throw Exception('Could not access storage directory');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  List<pw.TableRow> _buildGroupedPDFTableRows(
      Map<String, List<StudentGroupInfo>> studentsByDay) {
    List<pw.TableRow> allRows = [];

    // Calculate maximum rows needed
    int maxRows = 0;
    for (var dayStudents in studentsByDay.values) {
      var groupedStudents = _organizeByGroup(dayStudents);
      int dayRows = 0;
      for (var groupStudents in groupedStudents.values) {
        dayRows += groupStudents.length + 1;
      }
      maxRows = maxRows < dayRows ? dayRows : maxRows;
    }

    // Build rows
    for (int rowIndex = 0; rowIndex < maxRows; rowIndex++) {
      allRows.add(pw.TableRow(
        children: daysOfWeek.map((day) {
          final students = studentsByDay[day] ?? [];
          final groupedStudents = _organizeByGroup(students);

          int currentPosition = 0;

          for (var entry in groupedStudents.entries) {
            String groupName = entry.key;
            List<StudentGroupInfo> groupStudents = entry.value;

            if (currentPosition == rowIndex) {
              return pw.Container(
                padding: pw.EdgeInsets.all(8),
                color: PdfColors.grey200,
                child: pw.Text(
                  groupName,
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
              );
            }

            if (rowIndex > currentPosition &&
                rowIndex <= currentPosition + groupStudents.length) {
              final studentInfo = groupStudents[rowIndex - currentPosition - 1];
              return pw.Container(
                padding: pw.EdgeInsets.all(8),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      studentInfo.student.nom,
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(studentInfo.lycee),
                    pw.Text('Non payées: ${studentInfo.unpaidSessions}',
                        style: pw.TextStyle(
                            color: studentInfo.unpaidSessions >= 4
                                ? PdfColors.red
                                : PdfColors.green))
                  ],
                ),
              );
            }

            currentPosition += groupStudents.length + 1;
          }

          return pw.Container(padding: pw.EdgeInsets.all(8));
        }).toList(),
      ));
    }

    return allRows;
  }
}
