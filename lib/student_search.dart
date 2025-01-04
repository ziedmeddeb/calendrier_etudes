import 'package:calendrier_etude/edit_student_screen.dart';
import 'package:calendrier_etude/student_history.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'controllers/groupe_controller.dart';
import 'models/etudiant.dart';
import 'models/groupe.dart';

class StudentSearchScreen extends StatefulWidget {
  @override
  _StudentSearchScreenState createState() => _StudentSearchScreenState();
}

class _StudentSearchScreenState extends State<StudentSearchScreen> {
  String searchQuery = '';
  List<Etudiant> filteredStudents = [];

  @override
  Widget build(BuildContext context) {
    final groupeController = Provider.of<GroupeController>(context);

    // Get all students from all groups
    List<Etudiant> allStudents = [];
    for (Groupe groupe in groupeController.groupes) {
      allStudents.addAll(groupe.etudiants);
    }

    // Filter students based on search query
    filteredStudents = searchQuery.isEmpty
        ? allStudents
        : allStudents
            .where((student) =>
                student.nom.toLowerCase().contains(searchQuery.toLowerCase()))
            .toList();
    filteredStudents
        .sort((a, b) => a.nom.toLowerCase().compareTo(b.nom.toLowerCase()));

    return Scaffold(
      appBar: AppBar(
        title: Text('Rechercher un Étudiant'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                labelText: 'Rechercher',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  searchQuery = value;
                });
              },
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: filteredStudents.length,
              separatorBuilder: (context, index) => Divider(),
              itemBuilder: (context, index) {
                final student = filteredStudents[index];
                // Find the group this student belongs to
                final groupe = groupeController.groupes.firstWhere(
                  (g) => g.etudiants.contains(student),
                  orElse: () =>
                      throw Exception('Student not found in any group'),
                );

                return ListTile(
                    leading: CircleAvatar(
                      child: Text(student.nom[0]),
                    ),
                    title: Text(' ${student.nom}'),
                    subtitle: Text('Groupe: ${groupe.nom} - ${groupe.jour}'),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(
                        icon: Icon(Icons.history),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => StudentHistoryScreen(
                              etudiant: student,
                              group: groupe,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.edit),
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => EditStudentScreen(
                                groupeId: groupe.id,
                                etudiant: student,
                              ),
                            ),
                          );
                        },
                      )
                    ]));
              },
            ),
          ),
        ],
      ),
    );
  }

  // void _showStudentDetails(
  //     BuildContext context, Etudiant student, Groupe groupe) {
  //   showDialog(
  //     context: context,
  //     builder: (BuildContext context) {
  //       return AlertDialog(
  //         title: Text(' ${student.nom}'),
  //         content: SingleChildScrollView(
  //           child: Column(
  //             crossAxisAlignment: CrossAxisAlignment.start,
  //             mainAxisSize: MainAxisSize.min,
  //             children: [
  //               Text('Groupe: ${groupe.nom}'),
  //               Text('Jour: ${groupe.jour}'),
  //               Text(
  //                   'Horaire: ${groupe.heureDebut.format(context)} - ${groupe.heureFin.format(context)}'),
  //               SizedBox(height: 16),
  //               Text('Historique des présences:',
  //                   style: TextStyle(fontWeight: FontWeight.bold)),
  //               ...student.historique
  //                   .map((presence) => Padding(
  //                         padding: const EdgeInsets.symmetric(vertical: 4.0),
  //                         child: Text(
  //                             '${presence.date} - ${presence.present ? "Présent" : "Absent"}'),
  //                       ))
  //                   .toList(),
  //             ],
  //           ),
  //         ),
  //         actions: [
  //           TextButton(
  //             child: Text('Fermer'),
  //             onPressed: () {
  //               Navigator.of(context).pop();
  //             },
  //           ),
  //         ],
  //       );
  //     },
  //   );
  // }
}
