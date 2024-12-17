import 'package:calendrier_etude/add_group_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'controllers/groupe_controller.dart';
import 'models/groupe.dart';
import 'group_detail_screen.dart';

class GroupManagementScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final groupeController = Provider.of<GroupeController>(context);

    return Scaffold(
      appBar: AppBar(title: Text('Gestion des Groupes')),
      body: ListView.separated(
        itemCount: groupeController.groupes.length,
        separatorBuilder: (context, index) => Divider(),
        itemBuilder: (context, index) {
          final groupe = groupeController.groupes[index];
          return ListTile(
            title: Text('${groupe.nom} - ${groupe.jour}'),
            trailing: IconButton(
              icon: Icon(Icons.delete),
              onPressed: () {
                _showDeleteConfirmationDialog(
                    context, groupeController, groupe.id);
              },
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => GroupDetailScreen(groupe: groupe)),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AddGroupScreen()),
          );
        },
        child: Icon(Icons.add),
      ),
    );
  }

  void _showDeleteConfirmationDialog(BuildContext context,
      GroupeController groupeController, String groupeId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirmer la suppression'),
          content: Text('Êtes-vous sûr de vouloir supprimer ce groupe ?'),
          actions: <Widget>[
            TextButton(
              child: Text('Annuler'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Supprimer'),
              onPressed: () {
                groupeController.supprimerGroupe(groupeId);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
