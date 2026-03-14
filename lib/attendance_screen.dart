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
      // DatabaseService().deleteAllSeances();
      // DatabaseService().resetEtudiantUnpaidSessions();
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

      // Check for custom session name
      final customName = await _databaseService.getCustomSessionName(
        widget.date,
        widget.groupe.id,
      );

      setState(() {
        _isLoading = false;
        _dataLoaded = true;

        // Set session name prioritizing custom session name if it exists
        if (customName != null) {
          _sessionName = customName;
        } else if (_seanceMap.isNotEmpty) {
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
          title: const Row(children: [
            Icon(Icons.person_add_outlined, size: 20, color: Color(0xFF2563EB)),
            SizedBox(width: 8),
            Text('Étudiant externe'),
          ]),
          content: Container(
            width: double.maxFinite,
            child: filteredStudents.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Aucun étudiant disponible'),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: filteredStudents.length,
                    itemBuilder: (context, index) {
                      final student = filteredStudents[index];
                      final initials = student.nom.isNotEmpty
                          ? student.nom
                              .trim()
                              .split(' ')
                              .take(2)
                              .map((w) => w[0].toUpperCase())
                              .join()
                          : '?';
                      return ListTile(
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundColor: const Color(0xFFEFF6FF),
                          child: Text(initials,
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF2563EB))),
                        ),
                        title: Text(student.nom),
                        subtitle: Text(student.lycee),
                        onTap: () => Navigator.of(context).pop(student),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              child: const Text('Annuler'),
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
          title: const Row(children: [
            Icon(Icons.label_outline, size: 20, color: Color(0xFF2563EB)),
            SizedBox(width: 8),
            Text('Nom de la séance'),
          ]),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Ex: Séance normale',
              prefixIcon: Icon(Icons.edit_outlined),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('Confirmer'),
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

      // Also update custom session name if it exists
      await _databaseService.updateCustomSessionName(
        widget.date,
        widget.groupe.id,
        newName,
      );
    }
  }

  Widget _buildContent() {
    if (!_dataLoaded) {
      return Center(child: Text('Aucune donnée disponible'));
    }

    final int presentCount = _seanceMap.values.where((s) => s.present).length;
    final int totalStudents =
        widget.groupe.etudiants.length + _externalStudents.length;

    return Column(
      children: [
        // Session header
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _sessionName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _infoBadge(
                    Icons.calendar_today_outlined,
                    '${widget.date.day}/${widget.date.month}/${widget.date.year}',
                    const Color(0xFF2563EB),
                  ),
                  const SizedBox(width: 8),
                  _infoBadge(
                    Icons.check_circle_outline,
                    '$presentCount / $totalStudents présents',
                    presentCount == totalStudents
                        ? const Color(0xFF10B981)
                        : const Color(0xFFF59E0B),
                  ),
                  const SizedBox(width: 8),
                  if (_externalStudents.isNotEmpty)
                    _infoBadge(
                      Icons.people_outline,
                      '${_externalStudents.length} externe${_externalStudents.length > 1 ? "s" : ""}',
                      const Color(0xFF8B5CF6),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.person_add_outlined, size: 16),
                  label: const Text('Ajouter étudiant externe'),
                  onPressed: _addExternalStudent,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2563EB),
                    side: const BorderSide(color: Color(0xFF2563EB)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              if (widget.groupe.etudiants.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Text(
                    'ÉTUDIANTS DU GROUPE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade500,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ...widget.groupe.etudiants
                  .sorted((a, b) => a.nom.compareTo(b.nom))
                  .map((etudiant) {
                final seance = _seanceMap[etudiant.id];
                final isPresent = seance?.present ?? false;
                return _buildStudentTile(
                  etudiant.nom,
                  isPresent,
                  () => _toggleAttendance(etudiant.id),
                );
              }),
              if (_externalStudents.isNotEmpty) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Text(
                    'ÉTUDIANTS EXTERNES',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.purple.shade400,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                ..._externalStudents.values
                    .toList()
                    .sorted((a, b) => a.nom.compareTo(b.nom))
                    .map((etudiant) {
                  final seance = _seanceMap[etudiant.id];
                  final isPresent = seance?.present ?? false;
                  return _buildStudentTile(
                    etudiant.nom,
                    isPresent,
                    () => _toggleAttendance(etudiant.id),
                    isExternal: true,
                    onRemove: () => _removeExternalStudent(etudiant.id),
                  );
                }),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _infoBadge(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentTile(
    String name,
    bool isPresent,
    VoidCallback onToggle, {
    bool isExternal = false,
    VoidCallback? onRemove,
  }) {
    final initials = name.isNotEmpty
        ? name.trim().split(' ').take(2).map((w) => w[0].toUpperCase()).join()
        : '?';
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      elevation: isPresent ? 1 : 0,
      color: isPresent ? const Color(0xFFF0FDF4) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isPresent
              ? const Color(0xFF10B981).withOpacity(0.4)
              : Colors.grey.shade200,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: isPresent
                  ? const Color(0xFF10B981).withOpacity(0.15)
                  : Colors.grey.shade100,
              child: Text(
                initials,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isPresent
                      ? const Color(0xFF10B981)
                      : Colors.grey.shade500,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isPresent
                          ? const Color(0xFF065F46)
                          : const Color(0xFF1E293B),
                    ),
                  ),
                  if (isExternal)
                    Text('Externe',
                        style: TextStyle(
                            fontSize: 11, color: Colors.purple.shade400)),
                ],
              ),
            ),
            if (onRemove != null)
              IconButton(
                icon: Icon(Icons.remove_circle_outline,
                    color: Colors.red.shade400, size: 18),
                onPressed: onRemove,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onToggle,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isPresent
                      ? const Color(0xFF10B981)
                      : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isPresent ? Icons.check : Icons.close,
                  color: isPresent ? Colors.white : Colors.grey.shade400,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleAttendance(String etudiantId) async {
    if (_isLoading) return;

    var seance = _seanceMap[etudiantId];
    if (seance == null) {
      // Create new seance (marked as present)
      setState(() {
        _seanceMap[etudiantId] = Seance(
          id: Uuid().v4(),
          date: widget.date,
          etudiantId: etudiantId,
          present: true,
          name: _sessionName,
        );
        _hasChanges = true;
      });
    } else {
      if (seance.present) {
        // If currently present, delete the seance
        try {
          setState(() {
            _isLoading = true;
          });

          await _databaseService.deleteSeance(etudiantId, widget.date);

          setState(() {
            _seanceMap.remove(etudiantId);
            _hasChanges = false; // No need to save since we've already deleted
            _isLoading = false;
          });

          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Présence supprimée')),
          );
        } catch (e) {
          print('Error toggling attendance: $e');
          setState(() {
            _isLoading = false;
          });

          // Show error message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur lors de la suppression de la présence'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        // If currently absent, mark as present
        setState(() {
          _seanceMap[etudiantId] = Seance(
            id: seance.id,
            date: seance.date,
            etudiantId: seance.etudiantId,
            present: true,
            name: _sessionName,
          );
          _hasChanges = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(widget.groupe.nom),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: _editSessionName,
            tooltip: 'Modifier le nom de la séance',
          ),
          if (_hasChanges && !_isLoading)
            TextButton.icon(
              icon: const Icon(Icons.save_outlined,
                  size: 18, color: Colors.white),
              label: const Text('Sauvegarder',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
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
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      'Chargement des présences...',
                      style: TextStyle(
                          color: Colors.grey.shade600, fontSize: 14),
                    ),
                  ],
                ),
              )
            : _buildContent(),
      ),
    );
  }
}
