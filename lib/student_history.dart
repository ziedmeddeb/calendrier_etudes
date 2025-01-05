import 'package:calendrier_etude/models/groupe.dart';
import 'package:calendrier_etude/models/paiement_hisotrique.dart';
import 'package:calendrier_etude/paiement_historique_screen.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
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
  final TextEditingController _sessionsController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
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

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDate),
      );

      if (pickedTime != null) {
        setState(() {
          _selectedDate = DateTime(
            picked.year,
            picked.month,
            picked.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  Future<void> _showCancelConfirmationDialog(
      String etudiantId, DateTime date) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirmer la suppression'),
          content: const Text('Voulez-vous vraiment supprimer cette séance ? '),
          actions: <Widget>[
            TextButton(
              child: const Text('Non'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Oui'),
              onPressed: () async {
                Navigator.of(context).pop();
                await _deleteSeance(etudiantId, date);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteSeance(String etudiantId, DateTime date) async {
    try {
      await DatabaseService().deleteSeance(etudiantId, date);
      setState(() => _refreshPayments());

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Séance supprimée avec succès'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erreur lors de la suppression de la séance'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showAddPaymentDialog() async {
    final student = await DatabaseService().getEtudiantById(widget.etudiant.id);
    if (student == null) return;

    _sessionsController.clear();
    _selectedDate = DateTime.now();

    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Ajouter un paiement'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Séances non payées: ${student.unpaidSessions}',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: _sessionsController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Nombre de séances',
                      hintText: 'Entrez le nombre de séances',
                    ),
                  ),
                  SizedBox(height: 16),
                  ListTile(
                    title: Text(
                        'Date: ${DateFormat('dd/MM/yyyy HH:mm').format(_selectedDate)}'),
                    trailing: Icon(Icons.calendar_today),
                    onTap: () async {
                      await _selectDate(context);
                      setState(() {});
                    },
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  child: Text('Annuler'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                TextButton(
                  child: Text('Ajouter'),
                  onPressed: () async {
                    if (_sessionsController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Veuillez entrer le nombre de séances'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    final numberOfSessions =
                        int.tryParse(_sessionsController.text);
                    if (numberOfSessions == null || numberOfSessions <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Nombre de séances invalide'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    try {
                      await DatabaseService().insertPayment(
                        Payment(
                          id: const Uuid().v4(),
                          etudiantId: widget.etudiant.id,
                          numberOfSessions: numberOfSessions,
                          date: _selectedDate,
                        ),
                      );

                      Navigator.of(context).pop();
                      setState(() => _refreshPayments());

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Paiement ajouté avec succès'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content:
                              Text('Erreur lors de l\'ajout du paiement: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Historique: ${widget.etudiant.nom} ',
          style: TextStyle(fontSize: 17),
        ),
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
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    'Séances non payées: ${etudiant.unpaidSessions ?? 0}',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () => _showConfirmationDialog(etudiant),
                      child: Text('Payer 4 Séances'),
                    ),
                    ElevatedButton(
                      onPressed: () => _showAddPaymentDialog(),
                      child: Text('Payer'),
                    ),
                  ],
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

                        return Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                'Nombre total de séances: ${seances.length}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                            ),
                            Expanded(
                              child: ListView.separated(
                                itemCount: seances.length,
                                separatorBuilder: (context, index) => Divider(
                                  height: 1,
                                  color: Colors.grey[300],
                                ),
                                itemBuilder: (context, index) {
                                  final seance = seances[index];
                                  return ListTile(
                                    title: Text(
                                      'Date: ${_formatDate(seance.date)}',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w500),
                                    ),
                                    subtitle: Text(
                                      'Present: ${seance.present ? "Oui" : "Non"}',
                                      style: TextStyle(
                                        color: seance.present
                                            ? Colors.green
                                            : Colors.red,
                                      ),
                                    ),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.cancel,
                                          color: Colors.red),
                                      onPressed: () =>
                                          _showCancelConfirmationDialog(
                                        etudiant.id,
                                        seance.date,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
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
