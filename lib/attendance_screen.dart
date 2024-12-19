import 'package:calendrier_etude/models/etudiant.dart';
import 'package:calendrier_etude/models/groupe.dart';
import 'package:calendrier_etude/models/seance.dart';
import 'package:calendrier_etude/services/database_service.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

class AttendanceScreen extends StatefulWidget {
  final DateTime date;
  final Groupe groupe;

  AttendanceScreen({required this.date, required this.groupe});

  @override
  _AttendanceScreenState createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final Map<String, Seance> _seanceMap = {};
  final Map<String, Etudiant> _externalStudents = {};
  bool _isLoading = true;
  bool _hasChanges = false;
  bool _dataLoaded = false;
  final DatabaseService _databaseService = DatabaseService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSeances();
    });
  }

  Future<void> _loadSeances() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _dataLoaded = false;
    });

    try {
      await Future.wait([
        _fetchData(),
        Future.delayed(Duration(milliseconds: 800)),
      ]);

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _dataLoaded = true;
      });
    } catch (e) {
      print('Error loading seances: $e');
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _dataLoaded = false;
      });
    }
  }

  Future<void> _fetchData() async {
    final fetchedSeances = await _databaseService.getSeancesByDate(widget.date);

    if (!mounted) return;

    _seanceMap.clear();
    _externalStudents.clear();

    for (var seance in fetchedSeances) {
      _seanceMap[seance.etudiantId] = seance;

      // If this seance belongs to a student not in the group, fetch their info
      if (!widget.groupe.etudiants.any((e) => e.id == seance.etudiantId)) {
        final externalStudent =
            await _databaseService.getEtudiantById(seance.etudiantId);
        if (externalStudent != null) {
          _externalStudents[seance.etudiantId] = externalStudent;
        }
      }
    }
  }

  Future<void> _saveChanges() async {
    try {
      setState(() {
        _isLoading = true;
      });

      for (var seance in _seanceMap.values) {
        await _databaseService.insertSeance(seance);
      }

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _hasChanges = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Présence sauvegardée')),
      );
    } catch (e) {
      print('Error saving seances: $e');
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la sauvegarde')),
      );
    }
  }

  Future<void> _addExternalStudent() async {
    final List<Etudiant>? availableStudents =
        await _databaseService.getAllEtudiants();

    if (availableStudents == null || !mounted) return;

    // Filter out students already in the group or already added as external
    final filteredStudents = availableStudents
        .where((student) =>
            !widget.groupe.etudiants.any((e) => e.id == student.id) &&
            !_externalStudents.containsKey(student.id))
        .toList();

    final Etudiant? selectedStudent = await showDialog<Etudiant>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Ajouter un étudiant externe'),
          content: Container(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: filteredStudents.length,
              itemBuilder: (context, index) {
                final student = filteredStudents[index];
                return ListTile(
                  title: Text(student.nom),
                  subtitle: Text('Lycée: ${student.lycee}'),
                  onTap: () => Navigator.of(context).pop(student),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              child: Text('Annuler'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );

    if (selectedStudent != null) {
      setState(() {
        _externalStudents[selectedStudent.id] = selectedStudent;
        _seanceMap[selectedStudent.id] = Seance(
          id: Uuid().v4(),
          date: widget.date,
          etudiantId: selectedStudent.id,
          present: true, // Set as present by default since they're being added
        );
        _hasChanges = true;
      });
    }
  }

  void _removeExternalStudent(String studentId) {
    setState(() {
      _externalStudents.remove(studentId);
      _seanceMap.remove(studentId);
      _hasChanges = true;
    });
  }

  Widget _buildContent() {
    if (!_dataLoaded) {
      return Center(child: Text('Aucune donnée disponible'));
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Date: ${widget.date.day}/${widget.date.month}/${widget.date.year}',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                icon: Icon(Icons.person_add),
                label: Text('Ajouter étudiant'),
                onPressed: _addExternalStudent,
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            children: [
              // Regular group students
              ...widget.groupe.etudiants.map((etudiant) {
                final seance = _seanceMap[etudiant.id];
                final isPresent = seance?.present ?? false;

                return ListTile(
                  title: Text('Étudiant: ${etudiant.nom}'),
                  trailing: IconButton(
                    icon: Icon(
                      isPresent
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                    ),
                    onPressed: () => _toggleAttendance(etudiant.id),
                  ),
                );
              }),

              // Divider if there are external students
              if (_externalStudents.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Column(
                    children: [
                      Divider(thickness: 2),
                      Text(
                        'Étudiants externes',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ),

              // External students
              ..._externalStudents.values.map((etudiant) {
                final seance = _seanceMap[etudiant.id];
                final isPresent = seance?.present ?? false;

                return ListTile(
                  title: Text('Étudiant: ${etudiant.nom}'),
                  subtitle: Text('(Externe)'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          isPresent
                              ? Icons.check_box
                              : Icons.check_box_outline_blank,
                        ),
                        onPressed: () => _toggleAttendance(etudiant.id),
                      ),
                      IconButton(
                        icon: Icon(Icons.remove_circle_outline,
                            color: Colors.red),
                        onPressed: () => _removeExternalStudent(etudiant.id),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  void _toggleAttendance(String etudiantId) {
    if (_isLoading) return;

    setState(() {
      final seance = _seanceMap[etudiantId];
      if (seance != null) {
        seance.present = !seance.present;
        _hasChanges = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Présence - ${widget.groupe.nom}'),
        actions: [
          if (_hasChanges && !_isLoading)
            IconButton(
              icon: Icon(Icons.save),
              onPressed: _saveChanges,
            ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Chargement des présences...'),
                  ],
                ),
              )
            : _buildContent(),
      ),
    );
  }
}
