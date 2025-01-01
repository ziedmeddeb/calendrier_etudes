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

class GroupDetailScreen extends StatefulWidget {
  final Groupe groupe;
  GroupDetailScreen({required this.groupe});

  @override
  _GroupDetailScreenState createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  late Future<List<Etudiant>> _etudiantsFuture;

  @override
  void initState() {
    super.initState();
    _etudiantsFuture = _fetchEtudiants(widget.groupe.id);
  }

  Future<List<Etudiant>> _fetchEtudiants(String groupId) async {
    final etudiants = await DatabaseService().getEtudiants(groupId);
    for (var etudiant in etudiants) {
      final updatedEtudiant =
          await DatabaseService().getEtudiantById(etudiant.id);
      etudiant = updatedEtudiant!;
    }
    etudiants
        .sort((a, b) => a.nom.toLowerCase().compareTo(b.nom.toLowerCase()));
    return etudiants;
  }

  Future<void> _navigateToHistory(Etudiant etudiant) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StudentHistoryScreen(
          etudiant: etudiant,
          group: widget.groupe,
        ),
      ),
    );
    // Refresh data after returning
    setState(() {
      _etudiantsFuture = _fetchEtudiants(widget.groupe.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final groupeController = Provider.of<GroupeController>(context);
    final int totalStudents = widget.groupe.etudiants.length;
    return Scaffold(
      appBar: AppBar(
        title: Text('Détails du Groupe'),
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditGroupScreen(groupe: widget.groupe),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Text('Nom du Groupe: ${widget.groupe.nom}'),
          Text('Jour: ${widget.groupe.jour}'),
          Text('Nombre étudiants: ${totalStudents}'),
          Text('Heure de Début: ${widget.groupe.heureDebut.format(context)}'),
          Text('Heure de Fin: ${widget.groupe.heureFin.format(context)}'),
          Expanded(
            child: FutureBuilder<List<Etudiant>>(
              future: _etudiantsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(child: Text('No students found.'));
                }

                final etudiants = snapshot.data!;
                return ListView.separated(
                  itemCount: etudiants.length,
                  separatorBuilder: (context, index) => Divider(),
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
                            onPressed: () => _navigateToHistory(etudiant),
                          ),
                          IconButton(
                            icon: Icon(Icons.edit),
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => EditStudentScreen(
                                    groupeId: widget.groupe.id,
                                    etudiant: etudiant,
                                  ),
                                ),
                              );
                              setState(() {
                                _etudiantsFuture =
                                    _fetchEtudiants(widget.groupe.id);
                              });
                            },
                          ),
                          IconButton(
                            icon: Icon(Icons.delete),
                            onPressed: () {
                              groupeController.supprimerEtudiantDuGroupe(
                                  widget.groupe.id, etudiant.id);
                            },
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) =>
                        AddStudentScreen(groupeId: widget.groupe.id)),
              );
              setState(() {
                _etudiantsFuture = _fetchEtudiants(widget.groupe.id);
              });
            },
            child: Text('Ajouter Étudiant'),
          ),
        ],
      ),
    );
  }
}
