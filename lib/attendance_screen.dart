import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'controllers/absence_controller.dart';
import 'models/groupe.dart';
import 'models/seance.dart';
import 'models/etudiant_presence.dart';

class AttendanceScreen extends StatefulWidget {
  final Groupe groupe;
  final Seance seance;

  const AttendanceScreen({Key? key, required this.groupe, required this.seance})
      : super(key: key);

  @override
  _AttendanceScreenState createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  late Seance _seance;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    // Create a deep copy of the seance to allow local modifications
    _seance = Seance(
      id: widget.seance.id,
      groupe: widget.seance.groupe,
      date: widget.seance.date,
      presences: widget.seance.presences
          .map((p) =>
              EtudiantPresence(etudiantId: p.etudiantId, present: p.present))
          .toList(),
    );
  }

  void _saveAttendance(AbsenceController absenceController) async {
    try {
      // Explicitly save the entire seance
      await absenceController.updateSeance(_seance);

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Présence enregistrée avec succès'),
        backgroundColor: Colors.green,
      ));

      setState(() {
        _hasChanges = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Erreur lors de l\'enregistrement : $e'),
        backgroundColor: Colors.red,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Présence - ${widget.groupe.nom}'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Date: ${_seance.date.toLocal().toString().split(' ')[0]}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Expanded(
              child: Consumer<AbsenceController>(
                builder: (context, absenceController, child) {
                  return ListView.builder(
                    itemCount: _seance.presences.length,
                    itemBuilder: (context, index) {
                      final presence = _seance.presences[index];
                      final etudiant = widget.groupe.etudiants
                          .firstWhere((e) => e.id == presence.etudiantId);

                      return ListTile(
                        title: Text(etudiant.nom),
                        trailing: Checkbox(
                          value: presence.present,
                          onChanged: (bool? value) {
                            if (value != null) {
                              // Update local state
                              setState(() {
                                presence.present = value;
                                _hasChanges = true;
                              });
                            }
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                onPressed: _hasChanges
                    ? () => _saveAttendance(context.read<AbsenceController>())
                    : null,
                child: Text('Enregistrer les présences'),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 50),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
