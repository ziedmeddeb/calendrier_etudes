import 'package:calendrier_etude/models/etudiant.dart';
import 'package:calendrier_etude/models/groupe.dart';
import 'package:calendrier_etude/models/seance.dart';
import 'package:calendrier_etude/services/database_service.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:collection/collection.dart';

class AttendanceScreen extends StatefulWidget {
  final DateTime date;
  final Groupe groupe;

  AttendanceScreen({
    required this.date,
    required this.groupe,
  });

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
  String _sessionName = 'Séance';

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

        // Set session name from first seance found, or keep default
        if (_seanceMap.isNotEmpty) {
          _sessionName = _seanceMap.values.first.name;
        }
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

      // Get all original seances for this date
      final originalSeances =
          await _databaseService.getSeancesByDate(widget.date);
      final Map<String, bool> originalAttendance = {
        for (var seance in originalSeances) seance.etudiantId: seance.present
      };

      for (var seance in _seanceMap.values) {
        await _databaseService.insertSeance(seance);

        // Only update unpaid sessions if this is a new attendance record or the status changed
        final originalPresent = originalAttendance[seance.etudiantId];
        if (originalPresent == null || originalPresent != seance.present) {
          Etudiant? etudiant =
              await _databaseService.getEtudiantById(seance.etudiantId);
          if (etudiant != null) {
            int unpaidSessions = etudiant.unpaidSessions;
            if (seance.present) {
              // Only increment if it's a new present record
              if (originalPresent == null || !originalPresent) {
                unpaidSessions += 1;
              }
            } else {
              // Only decrement if changing from present to absent
              if (originalPresent == true) {
                unpaidSessions -= 1;
              }
            }
            etudiant.unpaidSessions = unpaidSessions;

            // Get the student's original group ID
            String? originalGroupId = await _databaseService
                .findStudentOriginalGroup(seance.etudiantId);
            if (originalGroupId != null) {
              // Update the student while preserving their original group
              await _databaseService.updateEtudiantUnpaidSessions(
                  etudiant, originalGroupId);
            }
          }
        }
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

  void _removeExternalStudent(String studentId) async {
    await _databaseService.removeExternalStudent(studentId);
    setState(() {
      _externalStudents.remove(studentId);
      _seanceMap.remove(studentId);
      _hasChanges = true;
    });
  }

  Future<void> _editSessionName() async {
    final TextEditingController controller =
        TextEditingController(text: _sessionName);
    final String? newName = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Modifier le nom de la séance'),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: 'Entrez le nouveau nom',
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Annuler'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: Text('Confirmer'),
            ),
          ],
        );
      },
    );

    if (newName != null && newName.isNotEmpty && newName != _sessionName) {
      setState(() {
        _sessionName = newName;
        _hasChanges = true;

        // Update session name in all seances
        _seanceMap.forEach((etudiantId, seance) {
          _seanceMap[etudiantId] = Seance(
            id: seance.id,
            date: seance.date,
            etudiantId: seance.etudiantId,
            present: seance.present,
            name: newName,
          );
        });
      });
    }
  }

  Widget _buildContent() {
    if (!_dataLoaded) {
      return Center(child: Text('Aucune donnée disponible'));
    }

    final int totalStudents =
        widget.groupe.etudiants.length + _externalStudents.length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _sessionName,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Date: ${widget.date.day}/${widget.date.month}/${widget.date.year}',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  Text(
                    'Total étudiants: $totalStudents',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_externalStudents.isNotEmpty)
                    Text(
                      '(${widget.groupe.etudiants.length} réguliers, ${_externalStudents.length} externes)',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ElevatedButton.icon(
                    icon: Icon(Icons.person_add),
                    label: Text('Ajouter étudiant'),
                    onPressed: _addExternalStudent,
                  ),
                ],
              ),
            ],
          ),
        ),
        Divider(thickness: 1),
        Expanded(
          child: ListView(
            children: [
              ...widget.groupe.etudiants
                  .sorted(
                      (a, b) => a.nom.compareTo(b.nom)) // Sort regular students
                  .map((etudiant) {
                final seance = _seanceMap[etudiant.id];
                final isPresent = seance?.present ?? false;

                return ListTile(
                  title: Text('${etudiant.nom}'),
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
              ..._externalStudents.values
                  .toList() // Convert to list to enable sorting
                  .sorted((a, b) =>
                      a.nom.compareTo(b.nom)) // Sort external students
                  .map((etudiant) {
                final seance = _seanceMap[etudiant.id];
                final isPresent = seance?.present ?? false;

                return ListTile(
                  title: Text('${etudiant.nom}'),
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
      var seance = _seanceMap[etudiantId];
      if (seance == null) {
        seance = Seance(
          id: Uuid().v4(),
          date: widget.date,
          etudiantId: etudiantId,
          present: true,
          name: _sessionName,
        );
        _seanceMap[etudiantId] = seance;
      } else {
        seance.present = !seance.present;
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
          IconButton(
            icon: Icon(Icons.edit),
            onPressed: _editSessionName,
            tooltip: 'Modifier le nom de la séance',
          ),
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
