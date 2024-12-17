import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'controllers/groupe_controller.dart';
import 'models/groupe.dart';
import 'add_group_screen.dart';
import 'group_detail_screen.dart';

class GroupManagementScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final groupeController = Provider.of<GroupeController>(context);

    return Scaffold(
      body: ListView.separated(
        itemCount: groupeController.groupes.length,
        itemBuilder: (context, index) {
          final groupe = groupeController.groupes[index];
          return ListTile(
            title: Text('${groupe.nom} - ${groupe.jour}'),
            trailing: IconButton(
              icon: Icon(Icons.delete),
              onPressed: () {
                groupeController.supprimerGroupe(groupe.id);
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
        separatorBuilder: (context, index) => Divider(),
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
}
