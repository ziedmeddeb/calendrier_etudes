import 'package:calendrier_etude/models/etudiant.dart';
import 'package:calendrier_etude/models/groupe.dart';
import 'package:calendrier_etude/models/paiement_hisotrique.dart';
import 'package:calendrier_etude/services/database_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PaymentHistoryScreen extends StatefulWidget {
  final Etudiant etudiant;
  final Groupe group;

  PaymentHistoryScreen({required this.etudiant, required this.group});

  @override
  _PaymentHistoryScreenState createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends State<PaymentHistoryScreen> {
  late Future<List<Payment>> paymentsFuture;

  @override
  void initState() {
    super.initState();
    _refreshPayments();
  }

  void _refreshPayments() {
    paymentsFuture =
        DatabaseService().getPaymentsByEtudiantId(widget.etudiant.id);
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
      // Supprimer le paiement
      await DatabaseService().deletePayment(payment.id);

      // Ajouter les séances non payées à l'étudiant
      await DatabaseService().addUnpaidSessions(
          payment.etudiantId, widget.group.id, payment.numberOfSessions);

      // Rafraîchir la liste des paiements
      setState(() {
        _refreshPayments();
      });

      // Montrer un message de succès
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Paiement annulé avec succès'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      // Gérer les erreurs
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
}
