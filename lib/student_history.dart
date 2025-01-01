import 'package:calendrier_etude/models/groupe.dart';
import 'package:calendrier_etude/models/paiement_hisotrique.dart';
import 'package:calendrier_etude/paiement_historique_screen.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'models/etudiant.dart';
import 'services/database_service.dart'; // Make sure you import the DatabaseService class
import 'models/seance.dart'; // Import your Seance model

class StudentHistoryScreen extends StatefulWidget {
  final Groupe group;
  final Etudiant etudiant;

  StudentHistoryScreen({required this.group, required this.etudiant});

  @override
  _StudentHistoryScreenState createState() => _StudentHistoryScreenState();
}

class _StudentHistoryScreenState extends State<StudentHistoryScreen> {
  late Future<Etudiant> etudiantFuture;

  @override
  void initState() {
    super.initState();
    // Fetch the Etudiant data from the database using the group ID
    _refreshPayments();
  }

  void _refreshPayments() {
    etudiantFuture = DatabaseService()
        .getEtudiantById(widget.etudiant.id)
        .then((etudiant) => etudiant!);
  }

  // Function to show confirmation dialog
  Future<void> _showConfirmationDialog(Etudiant etudiant) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirmer le paiement'),
          content: Text('Êtes-vous sûr de vouloir payer pour 4 séances?'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              child: Text('Annuler'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
                _payForSessions(etudiant); // Proceed with payments
              },
              child: Text('Confirmer'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _payForSessions(Etudiant etudiant) async {
    if (etudiant.unpaidSessions != null) {
      // Create and save the payment record
      final payment = Payment(
        etudiantId: etudiant.id,
        numberOfSessions: 4,
        date: DateTime.now(),
      );
      await DatabaseService().insertPayment(payment);

      // Update unpaid sessions
      etudiant.unpaidSessions = etudiant.unpaidSessions! - 4;

      // Update the Etudiant in the database
      await DatabaseService().updateEtudiant(etudiant, widget.group.id);

      // Show a snack bar
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Paiement effectué pour 4 séances'),
      ));

      // Reload the updated Etudiant data
      Etudiant? updatedEtudiant =
          await DatabaseService().getEtudiantById(etudiant.id);

      // Update the state with the latest Etudiant data
      setState(() {
        etudiantFuture = Future.value(updatedEtudiant!);
      });
    }
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Historique de l\'étudiant'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () => setState(() => _refreshPayments()),
          ),
        ],
      ),
      body: FutureBuilder<Etudiant>(
        future: etudiantFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData) {
            return Center(child: Text('Étudiant non trouvé.'));
          } else {
            final etudiant = snapshot.data!;

            return Column(
              children: [
                Text('Séances non payées: ${etudiant.unpaidSessions ?? 0}'),
                ElevatedButton(
                  onPressed: () => _showConfirmationDialog(etudiant),
                  child: Text('Payer 4 Séances'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PaymentHistoryScreen(
                          etudiant: etudiant,
                          group: widget.group,
                        ),
                      ),
                    );
                  },
                  child: Text('Voir Historique Paiements'),
                ),
                Expanded(
                  child: FutureBuilder<List<Seance>>(
                    future:
                        DatabaseService().getSeancesByEtudiantId(etudiant.id),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(child: CircularProgressIndicator());
                      } else if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return Center(child: Text('Pas de séances.'));
                      } else {
                        final seances = snapshot.data!;

                        return ListView.builder(
                          itemCount: seances.length,
                          itemBuilder: (context, index) {
                            final seance = seances[index];
                            return ListTile(
                              title: Text('Date: ${_formatDate(seance.date)}'),
                              subtitle: Text(
                                  'Present: ${seance.present ? "Oui" : "Non"}'),
                            );
                          },
                        );
                      }
                    },
                  ),
                ),
              ],
            );
          }
        },
      ),
    );
  }
}
