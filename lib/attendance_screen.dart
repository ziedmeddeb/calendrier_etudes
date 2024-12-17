import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'controllers/groupe_controller.dart';
import 'models/groupe.dart';
import 'models/etudiant.dart';

class AttendanceScreen extends StatelessWidget {
  final Groupe groupe;

  AttendanceScreen({required this.groupe});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Présence - ${groupe.nom}')),
      body: ListView.builder(
        itemCount: groupe.etudiants.length,
        itemBuilder: (context, index) {
          final etudiant = groupe.etudiants[index];
          return ListTile(
            title: Text(etudiant.nom),
            trailing: Consumer<GroupeController>(
              builder: (context, groupeController, child) {
                return Checkbox(
                  value: etudiant.present,
                  onChanged: (bool? value) {
                    groupeController.marquerPresence(
                        groupe.id, etudiant.id, value!);
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}
