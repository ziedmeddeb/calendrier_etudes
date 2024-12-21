import 'package:calendrier_etude/history.dart';
import 'package:calendrier_etude/models/etudiant.dart';
import 'package:flutter/material.dart';

class StudentDetailsScreen extends StatelessWidget {
  final Etudiant etudiant;

  StudentDetailsScreen({required this.etudiant});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Détails de ${etudiant.nom}')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nom: ${etudiant.nom}', style: TextStyle(fontSize: 18)),
            Text('Lycée: ${etudiant.lycee}', style: TextStyle(fontSize: 18)),
            Text('Séances impayées: ${etudiant.unpaidSessions}',
                style: TextStyle(fontSize: 18)),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        SessionHistoryScreen(etudiant: etudiant),
                  ),
                );
              },
              child: Text('Voir l\'historique des séances'),
            ),
          ],
        ),
      ),
    );
  }
}
