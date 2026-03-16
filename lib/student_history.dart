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

  Future<void> _showConfirmationDialog(Etudiant etudiant) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(children: [
            Icon(Icons.payments_outlined, color: const Color(0xFF2563EB), size: 22),
            const SizedBox(width: 8),
            const Text('Confirmer le paiement'),
          ]),
          content: const Text('Enregistrer le paiement pour 4 séances ?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _payForSessions(etudiant);
              },
              child: const Text('Confirmer'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _payForSessions(Etudiant etudiant) async {
    final payment = Payment(
      etudiantId: etudiant.id,
      numberOfSessions: 4,
      date: DateTime.now(),
    );
    await DatabaseService().insertPayment(payment);

    etudiant.unpaidSessions = etudiant.unpaidSessions - 4;
    await DatabaseService().updateEtudiant(etudiant, widget.group.id);

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Paiement effectué pour 4 séances'),
    ));

    final Etudiant? updatedEtudiant =
        await DatabaseService().getEtudiantById(etudiant.id);

    setState(() {
      etudiantFuture = Future.value(updatedEtudiant!);
    });
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
          title: Row(children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red.shade400, size: 22),
            const SizedBox(width: 8),
            const Text('Supprimer la séance'),
          ]),
          content: const Text('Voulez-vous vraiment supprimer cette séance ?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Annuler'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red, foregroundColor: Colors.white),
              child: const Text('Supprimer'),
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
              title: const Row(children: [
                Icon(Icons.add_card_outlined, size: 20, color: Color(0xFF2563EB)),
                SizedBox(width: 8),
                Text('Ajouter un paiement'),
              ]),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, size: 14, color: Color(0xFF2563EB)),
                        const SizedBox(width: 6),
                        Text(
                          'Séances non payées: ${student.unpaidSessions}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF2563EB)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _sessionsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Nombre de séances',
                      hintText: 'Ex: 4',
                      prefixIcon: Icon(Icons.format_list_numbered_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      await _selectDate(context);
                      setState(() {});
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined, size: 16, color: Color(0xFF2563EB)),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat('dd/MM/yyyy HH:mm').format(_selectedDate),
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                          const Spacer(),
                          Icon(Icons.edit_outlined, size: 14, color: Colors.grey.shade500),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Annuler'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                ElevatedButton(
                  child: const Text('Ajouter'),
                  onPressed: () async {
                    if (_sessionsController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Veuillez entrer le nombre de séances'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                    final numberOfSessions = int.tryParse(_sessionsController.text);
                    if (numberOfSessions == null || numberOfSessions <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
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
                        const SnackBar(
                          content: Text('Paiement ajouté avec succès'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Erreur: $e'),
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
          widget.etudiant.nom,
          style: const TextStyle(fontSize: 17),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() => _refreshPayments()),
          ),
        ],
      ),
      body: FutureBuilder<Etudiant>(
        future: etudiantFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Erreur: ${snapshot.error}'));
          } else if (!snapshot.hasData) {
            return const Center(child: Text('Étudiant non trouvé.'));
          }

          final etudiant = snapshot.data!;
          final unpaid = etudiant.unpaidSessions;

          return Column(
            children: [
              // Header card
              Container(
                color: Theme.of(context).cardTheme.color,
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: unpaid >= 4
                                ? Colors.red.shade50
                                : unpaid > 0
                                    ? Colors.amber.shade50
                                    : Colors.green.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.account_balance_wallet_outlined,
                            color: unpaid >= 4
                                ? Colors.red.shade600
                                : unpaid > 0
                                    ? Colors.amber.shade700
                                    : Colors.green.shade600,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                unpaid > 0
                                    ? '$unpaid séance${unpaid > 1 ? "s" : ""} non payée${unpaid > 1 ? "s" : ""}'
                                    : 'À jour ✓',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: unpaid >= 4
                                      ? Colors.red.shade700
                                      : unpaid > 0
                                          ? Colors.amber.shade800
                                          : Colors.green.shade700,
                                ),
                              ),
                              Text(
                                'Solde impayé',
                                style: TextStyle(
                                    fontSize: 13, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () =>
                                _showConfirmationDialog(etudiant),
                            icon: const Icon(Icons.payments_outlined, size: 16),
                            label: const Text('Payer 4 séances'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              textStyle: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _showAddPaymentDialog(),
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Paiement libre'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              textStyle: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
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
                        icon: const Icon(Icons.receipt_long_outlined, size: 16),
                        label: const Text('Voir historique des paiements'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF2563EB),
                          side: const BorderSide(color: Color(0xFF2563EB)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          textStyle: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: FutureBuilder<List<Seance>>(
                  future:
                      DatabaseService().getSeancesByEtudiantId(etudiant.id),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    } else if (snapshot.hasError) {
                      return Center(child: Text('Erreur: ${snapshot.error}'));
                    } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.event_note_outlined,
                                size: 48, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            Text('Aucune séance',
                                style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey.shade500,
                                    fontWeight: FontWeight.w500)),
                          ],
                        ),
                      );
                    }

                    final seances = snapshot.data!;
                    return Column(
                      children: [
                        Container(
                          color: Theme.of(context).cardTheme.color,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          child: Row(
                            children: [
                              Text(
                                'HISTORIQUE DES SÉANCES',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.grey.shade500,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '${seances.length} séances',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF2563EB),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: seances.length,
                            itemBuilder: (context, index) {
                              final seance = seances[index];
                              return _buildSeanceTile(seance, etudiant.id);
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSeanceTile(Seance seance, String etudiantId) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      color: seance.present ? const Color(0xFFF0FDF4) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: seance.present
              ? const Color(0xFF10B981).withValues(alpha: 0.3)
              : Colors.grey.shade200,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: seance.present
                    ? const Color(0xFF10B981).withValues(alpha: 0.15)
                    : Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                seance.present ? Icons.check : Icons.close,
                color: seance.present
                    ? const Color(0xFF10B981)
                    : Colors.red.shade400,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatDate(seance.date),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    seance.present ? 'Présent(e)' : 'Absent(e)',
                    style: TextStyle(
                      fontSize: 12,
                      color: seance.present
                          ? const Color(0xFF059669)
                          : Colors.red.shade500,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.delete_outline, color: Colors.red.shade300, size: 18),
              onPressed: () =>
                  _showCancelConfirmationDialog(etudiantId, seance.date),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }
}
