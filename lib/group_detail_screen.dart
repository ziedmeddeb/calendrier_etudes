import 'package:calendrier_etude/student_history.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'controllers/groupe_controller.dart';
import 'models/groupe.dart';
import 'models/etudiant.dart';
import 'add_student_screen.dart';
import 'edit_student_screen.dart';
import 'edit_group_screen.dart';
import 'services/database_service.dart'; // Ensure the DatabaseService is imported

class GroupDetailScreen extends StatelessWidget {
  final Groupe groupe;

  GroupDetailScreen({required this.groupe});

  @override
  Widget build(BuildContext context) {
    final groupeController = Provider.of<GroupeController>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Détails du Groupe'),
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditGroupScreen(groupe: groupe),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Text('Nom du Groupe: ${groupe.nom}'),
          Text('Jour: ${groupe.jour}'),
          Text('Heure de Début: ${groupe.heureDebut.format(context)}'),
          Text('Heure de Fin: ${groupe.heureFin.format(context)}'),
          Expanded(
            child: FutureBuilder<List<Etudiant>>(
              future: _fetchEtudiants(groupe.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(child: Text('No students found.'));
                } else {
                  final etudiants = snapshot.data!;
                  return ListView.separated(
                    itemCount: etudiants.length,
                    itemBuilder: (context, index) {
                      final etudiant = etudiants[index];
                      return ListTile(
                        title: RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: '${etudiant.nom} - ',
                                style: TextStyle(color: Colors.black),
                              ),
                              TextSpan(
                                text: '${etudiant.lycee}',
                                style: TextStyle(color: Colors.red),
                              ),
                            ],
                          ),
                        ),
                        subtitle: Text(
                            'Séances non payées: ${etudiant.unpaidSessions ?? 0}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.history),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => StudentHistoryScreen(
                                      etudiant: etudiant,
                                      group: groupe,
                                    ),
                                  ),
                                );
                              },
                            ),
                            IconButton(
                              icon: Icon(Icons.edit),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => EditStudentScreen(
                                      groupeId: groupe.id,
                                      etudiant: etudiant,
                                    ),
                                  ),
                                );
                              },
                            ),
                            IconButton(
                              icon: Icon(Icons.delete),
                              onPressed: () {
                                groupeController.supprimerEtudiantDuGroupe(
                                    groupe.id, etudiant.id);
                              },
                            ),
                          ],
                        ),
                      );
                    },
                    separatorBuilder: (context, index) => Divider(),
                  );
                }
              },
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) =>
                        AddStudentScreen(groupeId: groupe.id)),
              );
            },
            child: Text('Ajouter Étudiant'),
          ),
        ],
      ),
    );
  }

  // Fetch updated list of Etudiants from the database
  Future<List<Etudiant>> _fetchEtudiants(String groupId) async {
    final etudiants = await DatabaseService().getEtudiants(groupId);
    for (var etudiant in etudiants) {
      final updatedEtudiant =
          await DatabaseService().getEtudiantById(etudiant.id);
      etudiant = updatedEtudiant!;
    }
    // Sort alphabetically by name
    etudiants
        .sort((a, b) => a.nom.toLowerCase().compareTo(b.nom.toLowerCase()));
    return etudiants;
  }
}
