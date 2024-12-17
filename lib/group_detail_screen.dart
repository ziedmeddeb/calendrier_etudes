import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'controllers/groupe_controller.dart';
import 'models/groupe.dart';
import 'models/etudiant.dart';
import 'add_student_screen.dart';
import 'edit_student_screen.dart';
import 'edit_group_screen.dart';

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
            child: ListView.separated(
              itemCount: groupe.etudiants.length,
              itemBuilder: (context, index) {
                final etudiant = groupe.etudiants[index];
                return ListTile(
                  title: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '${etudiant.nom} - ',
                          style: TextStyle(
                              color:
                                  Colors.black), // Couleur normale pour le nom
                        ),
                        TextSpan(
                          text: '${etudiant.lycee}',
                          style: TextStyle(
                              color: Colors.red), // Couleur rouge pour le lycée
                        ),
                      ],
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.edit),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => EditStudentScreen(
                                  groupeId: groupe.id, etudiant: etudiant),
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
}
