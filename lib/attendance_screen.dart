import 'package:calendrier_etude/models/etudiant.dart';
import 'package:calendrier_etude/models/groupe.dart';
import 'package:calendrier_etude/models/seance.dart';
import 'package:calendrier_etude/services/database_service.dart';
import 'package:flutter/material.dart';

class AttendanceScreen extends StatefulWidget {
  final DateTime date;
  final Groupe groupe;

  AttendanceScreen({required this.date, required this.groupe});

  @override
  _AttendanceScreenState createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  late Future<List<Seance>> _seancesFuture;
  bool _hasChanges = false;
  DatabaseService _databaseService = DatabaseService();

  @override
  void initState() {
    super.initState();
    _seancesFuture = _loadSeances();
  }

  Future<List<Seance>> _loadSeances() async {
    print('🔍 DEBUG: Loading seances for date: ${widget.date}');
    print('🔍 DEBUG: Group: ${widget.groupe.nom}');
    print(
        '🔍 DEBUG: Total students in group: ${widget.groupe.etudiants.length}');

    // Fetch seances
    List<Seance> seances = await _databaseService.getSeancesByDate(widget.date);

    // Debug print existing seances
    print('🔍 DEBUG: Existing seances found: ${seances.length}');
    for (var seance in seances) {
      print(
          '🔍 DEBUG: Seance - StudentID: ${seance.etudiantId}, Present: ${seance.present}');
    }

    // If no seances exist, create default entries
    if (seances.isEmpty) {
      seances = widget.groupe.etudiants
          .map((etudiant) => Seance(
                id: UniqueKey().toString(),
                date: widget.date,
                etudiantId: etudiant.id,
                present: false,
              ))
          .toList();

      print(
          '🔍 DEBUG: No seances found. Creating default entries: ${seances.length}');

      // Save default seances
      for (var seance in seances) {
        await _databaseService.insertSeance(seance);
        print(
            '🔍 DEBUG: Inserted default seance for student: ${seance.etudiantId}');
      }
    }

    print('🔍 DEBUG: Final seances count: ${seances.length}');
    return seances;
  }

  void _toggleAttendance(Etudiant etudiant, List<Seance> seances) {
    setState(() {
      final index = seances.indexWhere((s) => s.etudiantId == etudiant.id);
      if (index != -1) {
        seances[index].present = !seances[index].present;
        print(
            '🔍 DEBUG: Toggled attendance for ${etudiant.nom}: ${seances[index].present}');
      } else {
        final newSeance = Seance(
          id: UniqueKey().toString(),
          date: widget.date,
          etudiantId: etudiant.id,
          present: true,
        );
        seances.add(newSeance);
        print(
            '🔍 DEBUG: Added new seance for ${etudiant.nom}: ${newSeance.present}');
      }
      _hasChanges = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Présence - ${widget.groupe.nom}'),
        actions: [
          if (_hasChanges)
            IconButton(
              icon: Icon(Icons.save),
              onPressed: () async {
                final seances = await _seancesFuture;
                _saveChanges(seances);
              },
            ),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<List<Seance>>(
          future: _seancesFuture,
          builder: (context, snapshot) {
            print('🔍 DEBUG: Connection State: ${snapshot.connectionState}');

            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Chargement des présences...'),
                  ],
                ),
              );
            } else if (snapshot.hasError) {
              print('🔍 DEBUG: Error: ${snapshot.error}');
              return Center(child: Text('Error: ${snapshot.error}'));
            } else if (snapshot.hasData) {
              final seances = snapshot.data!;
              print(
                  '🔍 DEBUG: Snapshot data received. Seances count: ${seances.length}');

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'Date: ${widget.date.day}/${widget.date.month}/${widget.date.year}',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: widget.groupe.etudiants.length,
                      itemBuilder: (context, index) {
                        final etudiant = widget.groupe.etudiants[index];
                        final seance = seances.firstWhere(
                          (s) => s.etudiantId == etudiant.id,
                          orElse: () => Seance(
                            id: UniqueKey().toString(),
                            date: widget.date,
                            etudiantId: etudiant.id,
                            present: false,
                          ),
                        );
                        return ListTile(
                          title: Text('Étudiant: ${etudiant.nom}'),
                          trailing: IconButton(
                            icon: Icon(
                              seance.present
                                  ? Icons.check_box
                                  : Icons.check_box_outline_blank,
                              color: seance.present ? Colors.green : Colors.red,
                            ),
                            onPressed: () =>
                                _toggleAttendance(etudiant, seances),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            } else {
              return Center(child: CircularProgressIndicator());
            }
          },
        ),
      ),
    );
  }

  Future<void> _saveChanges(List<Seance> seances) async {
    for (var seance in seances) {
      await _databaseService.insertSeance(seance);
      print(
          '🔍 DEBUG: Saved seance for ${seance.etudiantId}: ${seance.present}');
    }
    setState(() {
      _hasChanges = false;
    });
  }
}
