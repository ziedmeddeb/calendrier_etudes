import 'dart:io';
import 'dart:math';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:calendrier_etude/models/student_group.dart';
import 'package:calendrier_etude/services/database_service.dart';
import 'package:flutter/material.dart';

enum UnpaidFilter { all, moreThan1, moreThan4 }

class StudentsByDayScreen extends StatefulWidget {
  const StudentsByDayScreen({Key? key}) : super(key: key);

  @override
  State<StudentsByDayScreen> createState() => _StudentsByDayScreenState();
}

class _StudentsByDayScreenState extends State<StudentsByDayScreen> {
  final List<String> daysOfWeek = [
    'Lundi',
    'Mardi',
    'Mercredi',
    'Jeudi',
    'Vendredi',
    'Samedi',
    'Dimanche'
  ];

  UnpaidFilter _filter = UnpaidFilter.all;

  String _formatDate(DateTime date) =>
      DateFormat('dd/MM/yyyy', 'fr_FR').format(date);

  String get _pdfTitle {
    switch (_filter) {
      case UnpaidFilter.all:
        return 'Liste générale des étudiants';
      case UnpaidFilter.moreThan1:
        return 'Étudiants avec au moins 1 séance impayée';
      case UnpaidFilter.moreThan4:
        return 'Étudiants avec au moins 4 séances impayées';
    }
  }

  Map<String, List<StudentGroupInfo>> _applyFilter(
      Map<String, List<StudentGroupInfo>> data) {
    if (_filter == UnpaidFilter.all) return data;
    final threshold = _filter == UnpaidFilter.moreThan1 ? 1 : 4;
    return data.map((day, students) => MapEntry(
          day,
          students.where((s) => s.unpaidSessions >= threshold).toList(),
        ));
  }

  Map<String, List<StudentGroupInfo>> _organizeByGroup(
      List<StudentGroupInfo> students) {
    final Map<String, List<StudentGroupInfo>> grouped = {};
    students.sort((a, b) => a.groupName.compareTo(b.groupName));
    for (var student in students) {
      grouped.putIfAbsent(student.groupName, () => []).add(student);
    }
    return grouped;
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
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: FutureBuilder<Map<String, List<StudentGroupInfo>>>(
              future: DatabaseService().getStudentsByDay(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Erreur: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: Text('Aucun étudiant trouvé'));
                }

                final filtered = _applyFilter(snapshot.data!);
                final cellWidth = MediaQuery.of(context).size.width * 0.25;

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    child: Theme(
                      data: Theme.of(context)
                          .copyWith(dividerColor: Colors.black),
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
                        decoration:
                            BoxDecoration(border: Border.all(color: Colors.black)),
                        columns: daysOfWeek
                            .map((day) => DataColumn(
                                  label: Container(
                                    width: cellWidth,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8),
                                    decoration: const BoxDecoration(
                                      border: Border(
                                          right: BorderSide(color: Colors.black)),
                                    ),
                                    child: Text(day,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold)),
                                  ),
                                ))
                            .toList(),
                        rows: _buildGroupedTableRows(filtered, cellWidth),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      child: Row(
        children: [
          const Text('Afficher : ',
              style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Expanded(
            child: SegmentedButton<UnpaidFilter>(
              segments: const [
                ButtonSegment(
                  value: UnpaidFilter.all,
                  label: Text('Tous'),
                  icon: Icon(Icons.list),
                ),
                ButtonSegment(
                  value: UnpaidFilter.moreThan1,
                  label: Text('>= 1 impayé'),
                  icon: Icon(Icons.warning_amber_outlined),
                ),
                ButtonSegment(
                  value: UnpaidFilter.moreThan4,
                  label: Text('>= 4 impayés'),
                  icon: Icon(Icons.error_outline),
                ),
              ],
              selected: {_filter},
              onSelectionChanged: (selection) =>
                  setState(() => _filter = selection.first),
            ),
          ),
        ],
      ),
    );
  }

  List<DataRow> _buildGroupedTableRows(
      Map<String, List<StudentGroupInfo>> studentsByDay, double cellWidth) {
    int maxRows = 0;
    for (var dayStudents in studentsByDay.values) {
      final grouped = _organizeByGroup(dayStudents);
      int dayRows = 0;
      for (var groupStudents in grouped.values) {
        dayRows += groupStudents.length + 1;
      }
      if (dayRows > maxRows) maxRows = dayRows;
    }

    return List.generate(maxRows, (rowIndex) {
      return DataRow(
        cells: daysOfWeek.map((day) {
          final students = studentsByDay[day] ?? [];
          final grouped = _organizeByGroup(students);
          int pos = 0;

          for (var entry in grouped.entries) {
            final groupStudents = entry.value;

            if (pos == rowIndex) {
              return DataCell(Container(
                width: cellWidth,
                padding: const EdgeInsets.all(8),
                color: Colors.grey[200],
                child: Text(entry.key,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ));
            }

            if (rowIndex > pos && rowIndex <= pos + groupStudents.length) {
              final info = groupStudents[rowIndex - pos - 1];
              return DataCell(Container(
                width: cellWidth,
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(info.student.nom,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(info.lycee),
                    const SizedBox(height: 4),
                    Text(
                      'Non payées: ${info.unpaidSessions}',
                      style: TextStyle(
                        color: info.unpaidSessions >= 4
                            ? Colors.red
                            : Colors.green,
                      ),
                    ),
                  ],
                ),
              ));
            }

            pos += groupStudents.length + 1;
          }

          return DataCell(Container(width: cellWidth));
        }).toList(),
      );
    });
  }

  Future<void> _generatePDF(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final pdf = pw.Document();
      final raw = await DatabaseService().getStudentsByDay();
      final studentsByDay = _applyFilter(raw);

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          build: (pw.Context ctx) {
            return [
              pw.Header(
                level: 0,
                child: pw.Text(
                  '${_pdfTitle} — ${_formatDate(DateTime.now())}',
                  style: pw.TextStyle(fontSize: 18),
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Table(
                border: pw.TableBorder.all(),
                children: [
                  pw.TableRow(
                    children: daysOfWeek
                        .map((day) => pw.Container(
                              padding: const pw.EdgeInsets.all(8),
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
        final randomNumber = Random().nextInt(100000);
        final filterSuffix = _filter == UnpaidFilter.all
            ? 'tous'
            : _filter == UnpaidFilter.moreThan1
                ? 'impayés_1'
                : 'impayés_4';
        final path =
            '${directory.path}/etudiants_${filterSuffix}_$randomNumber.pdf';
        await File(path).writeAsBytes(await pdf.save());

        if (mounted) {
          messenger.showSnackBar(SnackBar(
            content: Text('PDF sauvegardé: $path'),
            duration: const Duration(seconds: 3),
          ));
        }
      } else {
        throw Exception('Impossible d\'accéder au répertoire de stockage');
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ));
      }
    }
  }

  List<pw.TableRow> _buildGroupedPDFTableRows(
      Map<String, List<StudentGroupInfo>> studentsByDay) {
    int maxRows = 0;
    for (var dayStudents in studentsByDay.values) {
      final grouped = _organizeByGroup(dayStudents);
      int dayRows = 0;
      for (var groupStudents in grouped.values) {
        dayRows += groupStudents.length + 1;
      }
      if (dayRows > maxRows) maxRows = dayRows;
    }

    return List.generate(maxRows, (rowIndex) {
      return pw.TableRow(
        children: daysOfWeek.map((day) {
          final students = studentsByDay[day] ?? [];
          final grouped = _organizeByGroup(students);
          int pos = 0;

          for (var entry in grouped.entries) {
            final groupStudents = entry.value;

            if (pos == rowIndex) {
              return pw.Container(
                padding: const pw.EdgeInsets.all(8),
                color: PdfColors.grey200,
                child: pw.Text(entry.key,
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              );
            }

            if (rowIndex > pos && rowIndex <= pos + groupStudents.length) {
              final info = groupStudents[rowIndex - pos - 1];
              return pw.Container(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(info.student.nom,
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text(info.lycee),
                    pw.Text(
                      'Non payées: ${info.unpaidSessions}',
                      style: pw.TextStyle(
                        color: info.unpaidSessions >= 4
                            ? PdfColors.red
                            : PdfColors.green,
                      ),
                    ),
                  ],
                ),
              );
            }

            pos += groupStudents.length + 1;
          }

          return pw.Container(padding: const pw.EdgeInsets.all(8));
        }).toList(),
      );
    });
  }
}
