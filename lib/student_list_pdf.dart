import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:calendrier_etude/models/student_group.dart';
import 'package:calendrier_etude/services/database_service.dart';
import 'package:flutter/material.dart';

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

          return Padding(
            padding: EdgeInsets.all(8.0),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width,
                      ),
                      child: DataTable(
                        columnSpacing: 20,
                        headingRowHeight: 60,
                        dataRowMinHeight: 80,
                        dataRowMaxHeight: 120,
                        columns: [
                          ...daysOfWeek.map((day) => DataColumn(
                                label: Container(
                                  width: MediaQuery.of(context).size.width / 8,
                                  child: Text(
                                    day,
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              )),
                        ],
                        rows: _buildTableRows(snapshot.data!),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<DataRow> _buildTableRows(
      Map<String, List<StudentGroupInfo>> studentsByDay) {
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
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      info.student.nom,
                      style: TextStyle(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    Text(
                      '${info.groupName} - ${info.lycee}',
                      overflow: TextOverflow.ellipsis,
                    ),
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
          return DataCell(Container());
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
                child: pw.Text('Liste des Étudiants par Jour ${DateTime.now()}',
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
        final String path = '${directory.path}/etudiants_par_jour.pdf';
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
