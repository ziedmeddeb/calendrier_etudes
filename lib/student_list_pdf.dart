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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Étudiants par Jour'),
        actions: [
          IconButton(
            icon: Icon(Icons.download),
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
                  dataRowMaxHeight: 120,
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
                  rows: _buildTableRows(snapshot.data!, cellWidth),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  List<DataRow> _buildTableRows(
      Map<String, List<StudentGroupInfo>> studentsByDay, double cellWidth) {
    int maxStudents = studentsByDay.values
        .map((students) => students.length)
        .fold(0, (max, length) => length > max ? length : max);

    return List.generate(maxStudents, (i) {
      return DataRow(
        cells: daysOfWeek.map((day) {
          final students = studentsByDay[day] ?? [];
          if (i < students.length) {
            final info = students[i];
            return DataCell(
              Container(
                width: cellWidth,
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border(
                    right: BorderSide(color: Colors.black),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      info.student.nom,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 4),
                    Text('${info.groupName} - ${info.lycee}'),
                    SizedBox(height: 4),
                    Text(
                      'Non payées: ${info.unpaidSessions}',
                      style: TextStyle(
                        color:
                            info.unpaidSessions > 0 ? Colors.red : Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          return DataCell(Container(
            width: cellWidth,
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(color: Colors.black),
              ),
            ),
          ));
        }).toList(),
      );
    });
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
                  ..._buildPDFTableRows(studentsByDay),
                ],
              ),
            ];
          },
        ),
      );

      // Get the downloads directory for Android
      Directory? directory;
      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Download');
        // Create directory if it doesn't exist
        if (!await directory.exists()) {
          directory = await getExternalStorageDirectory();
        }
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      if (directory != null) {
        final int randomNumber = Random()
            .nextInt(100000); // Generates a random number between 0 and 99999
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

  List<pw.TableRow> _buildPDFTableRows(
      Map<String, List<StudentGroupInfo>> studentsByDay) {
    int maxStudents = studentsByDay.values
        .map((students) => students.length)
        .fold(0, (max, length) => length > max ? length : max);

    return List.generate(maxStudents, (i) {
      return pw.TableRow(
        children: daysOfWeek.map((day) {
          final students = studentsByDay[day] ?? [];
          if (i < students.length) {
            final info = students[i];
            return pw.Container(
              padding: pw.EdgeInsets.all(8),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(info.student.nom,
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text('${info.groupName} - ${info.lycee}'),
                  pw.Text('Non payées: ${info.unpaidSessions}'),
                ],
              ),
            );
          }
          return pw.Container(
              padding: pw.EdgeInsets.all(8), child: pw.Text(''));
        }).toList(),
      );
    });
  }
}
