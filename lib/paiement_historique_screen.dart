import 'package:calendrier_etude/models/etudiant.dart';
import 'package:calendrier_etude/models/groupe.dart';
import 'package:calendrier_etude/models/paiement_hisotrique.dart';
import 'package:calendrier_etude/services/database_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

class PaymentHistoryScreen extends StatefulWidget {
  final Etudiant etudiant;
  final Groupe group;

  PaymentHistoryScreen({required this.etudiant, required this.group});

  @override
  _PaymentHistoryScreenState createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends State<PaymentHistoryScreen> {
  late Future<List<Payment>> paymentsFuture;
  final TextEditingController _sessionsController = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _refreshPayments();
  }

  void _refreshPayments() {
    paymentsFuture =
        DatabaseService().getPaymentsByEtudiantId(widget.etudiant.id);
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

  Future<void> _showCancelConfirmationDialog(Payment payment) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirmer l\'annulation'),
          content: Text('Voulez-vous vraiment annuler ce paiement ? \n'
              'Cela ajoutera ${payment.numberOfSessions} séances non payées à l\'étudiant.'),
          actions: <Widget>[
            TextButton(
              child: Text('Non'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text('Oui'),
              onPressed: () async {
                Navigator.of(context).pop();
                await _cancelPayment(payment);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _cancelPayment(Payment payment) async {
    try {
      await DatabaseService().deletePayment(payment.id);
      setState(() => _refreshPayments());

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Paiement annulé avec succès'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de l\'annulation du paiement: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: Text('Historique des Paiements'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () => setState(() => _refreshPayments()),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddPaymentDialog,
        child: Icon(Icons.add),
        tooltip: 'Ajouter un paiement',
      ),
      body: FutureBuilder<List<Payment>>(
        future: paymentsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erreur: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('Aucun historique de paiement.'));
          }

          final payments = snapshot.data!;

          return ListView.builder(
            itemCount: payments.length,
            itemBuilder: (context, index) {
              final payment = payments[index];
              return Card(
                margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                child: ListTile(
                  leading: Icon(Icons.payment),
                  title: Text('${payment.numberOfSessions} séances payées'),
                  subtitle: Text('Date: ${dateFormat.format(payment.date)}'),
                  trailing: IconButton(
                    icon: Icon(Icons.cancel, color: Colors.red),
                    onPressed: () => _showCancelConfirmationDialog(payment),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _sessionsController.dispose();
    super.dispose();
  }
}
