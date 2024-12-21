import 'package:calendrier_etude/models/etudiant.dart';
import 'package:flutter/material.dart';

class SessionHistoryScreen extends StatefulWidget {
  final Etudiant etudiant;

  SessionHistoryScreen({required this.etudiant});

  @override
  _SessionHistoryScreenState createState() => _SessionHistoryScreenState();
}

class _SessionHistoryScreenState extends State<SessionHistoryScreen> {
  void _paySessions() {
    setState(() {
      widget.etudiant.unpaidSessions = (widget.etudiant.unpaidSessions - 4)
          .clamp(0, double.infinity)
          .toInt();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Historique des séances')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Séances impayées: ${widget.etudiant.unpaidSessions}',
                style: TextStyle(fontSize: 18)),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _paySessions,
              child: Text('Payer 4 séances'),
            ),
            SizedBox(height: 20),
            Text('Historique des séances (à implémenter)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            // Add session history UI here
          ],
        ),
      ),
    );
  }
}
