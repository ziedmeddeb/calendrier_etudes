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

                    final numberOfSessions =
                        int.tryParse(_sessionsController.text);
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

  Future<void> _showCancelConfirmationDialog(Payment payment) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red.shade400, size: 22),
            const SizedBox(width: 8),
            const Text('Annuler le paiement'),
          ]),
          content: Text(
              'Voulez-vous vraiment annuler ce paiement ?\n'
              'Cela ajoutera ${payment.numberOfSessions} séances non payées à l\'étudiant.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Non'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red, foregroundColor: Colors.white),
              child: const Text('Annuler le paiement'),
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
        const SnackBar(
          content: Text('Paiement annulé avec succès'),
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
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('Paiements — ${widget.etudiant.nom}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() => _refreshPayments()),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddPaymentDialog,
        icon: const Icon(Icons.add),
        label: const Text('Ajouter'),
        tooltip: 'Ajouter un paiement',
      ),
      body: FutureBuilder<List<Payment>>(
        future: paymentsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erreur: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long_outlined,
                      size: 56, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text(
                    'Aucun paiement',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Appuyez sur + pour enregistrer un paiement',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                  ),
                ],
              ),
            );
          }

          final payments = snapshot.data!;
          final totalPaid =
              payments.fold<int>(0, (sum, p) => sum + p.numberOfSessions);

          return Column(
            children: [
              // Summary header
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_outline,
                              size: 14, color: Color(0xFF2563EB)),
                          const SizedBox(width: 6),
                          Text(
                            '$totalPaid séances payées au total',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: payments.length,
                  itemBuilder: (context, index) {
                    final payment = payments[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text(
                                  '${payment.numberOfSessions}',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF10B981),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${payment.numberOfSessions} séance${payment.numberOfSessions > 1 ? "s" : ""} payée${payment.numberOfSessions > 1 ? "s" : ""}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Icon(Icons.calendar_today_outlined,
                                          size: 11, color: Colors.grey.shade500),
                                      const SizedBox(width: 3),
                                      Text(
                                        dateFormat.format(payment.date),
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete_outline,
                                  color: Colors.red.shade400, size: 18),
                              onPressed: () =>
                                  _showCancelConfirmationDialog(payment),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ),
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

  @override
  void dispose() {
    _sessionsController.dispose();
    super.dispose();
  }
}
