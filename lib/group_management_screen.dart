import 'package:calendrier_etude/add_group_screen.dart';
import 'package:calendrier_etude/student_list_pdf.dart';
import 'package:calendrier_etude/student_search.dart';
import 'package:calendrier_etude/services/database_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'controllers/groupe_controller.dart';
import 'models/groupe.dart';
import 'group_detail_screen.dart';

class GroupManagementScreen extends StatefulWidget {
  @override
  _GroupManagementScreenState createState() => _GroupManagementScreenState();
}

class _GroupManagementScreenState extends State<GroupManagementScreen> {
  static const int _unpaidThreshold = 4;
  List<Map<String, dynamic>> _unpaidStudents = [];

  static const Map<String, Color> _dayColors = {
    'Lundi': Color(0xFF3B82F6),
    'Mardi': Color(0xFF8B5CF6),
    'Mercredi': Color(0xFF10B981),
    'Jeudi': Color(0xFFF59E0B),
    'Vendredi': Color(0xFFEF4444),
    'Samedi': Color(0xFFEC4899),
    'Dimanche': Color(0xFF6366F1),
  };

  @override
  void initState() {
    super.initState();
    _loadUnpaidStudents();
  }

  Future<void> _loadUnpaidStudents() async {
    final students = await DatabaseService()
        .getStudentsWithUnpaidAboveThreshold(_unpaidThreshold);
    if (mounted) {
      setState(() {
        _unpaidStudents = students;
      });
    }
  }

  Color _getDayColor(String jour) =>
      _dayColors[jour] ?? const Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    final groupeController = Provider.of<GroupeController>(context);
    final groupes = groupeController.groupes;

    return Scaffold(
      appBar: AppBar(
        leading: _unpaidStudents.isNotEmpty
            ? IconButton(
          icon: Badge(
            label: Text('${_unpaidStudents.length}',
                style: const TextStyle(fontSize: 9)),
            backgroundColor: Colors.red,
            child: const Icon(Icons.warning_amber_rounded),
          ),
          tooltip: 'Étudiants avec impayés',
          onPressed: () => _showUnpaidDialog(context),
        )
            : null,
        title: const Text('Mes Groupes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Rechercher un étudiant',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => StudentSearchScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.calendar_view_day),
            tooltip: 'Voir étudiants par jour',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => StudentsByDayScreen()),
              );
            },
          ),
        ],
      ),
      body: groupes.isEmpty
          ? _buildEmptyState(context)
          : Column(
              children: [
                _buildHeader(groupes),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: groupes.length,
                    itemBuilder: (context, index) {
                      return _buildGroupCard(
                          context, groupes[index], groupeController);
                    },
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AddGroupScreen()),
          );
        },
        tooltip: 'Créer un groupe',
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showUnpaidDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red.shade600, size: 22),
            const SizedBox(width: 8),
            Text(
              '${_unpaidStudents.length} étudiant${_unpaidStudents.length > 1 ? 's' : ''} en alerte',
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _unpaidStudents.length,
            itemBuilder: (context, index) {
              final s = _unpaidStudents[index];
              final count = s['unpaidSessions'] as int;
              return ListTile(
                dense: true,
                leading: CircleAvatar(
                  backgroundColor: Colors.red.shade400,
                  radius: 14,
                  child: Text(
                    '$count',
                    style: const TextStyle(
                        fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text('${s['nom']}', style: const TextStyle(fontSize: 14)),
                subtitle: s['groupeNom'] != null
                    ? Text('${s['groupeNom']}', style: const TextStyle(fontSize: 11))
                    : null,
                trailing: Text(
                  '$count impayées',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.red.shade600,
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(List<Groupe> groupes) {
    final totalStudents =
        groupes.fold<int>(0, (sum, g) => sum + g.etudiants.length);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Row(
        children: [
          _buildStatChip(Icons.group, '${groupes.length}', 'groupes'),
          const SizedBox(width: 12),
          _buildStatChip(Icons.person, '$totalStudents', 'étudiants'),
        ],
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF2563EB)),
          const SizedBox(width: 6),
          Text(
            '$value $label',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2563EB),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupCard(BuildContext context, Groupe groupe,
      GroupeController groupeController) {
    final dayColor = _getDayColor(groupe.jour);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => GroupDetailScreen(groupe: groupe)),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: dayColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.group_work, color: dayColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      groupe.nom,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: dayColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            groupe.jour,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: dayColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.access_time,
                            size: 12, color: Colors.grey.shade500),
                        const SizedBox(width: 3),
                        Text(
                          '${groupe.heureDebut.format(context)} - ${groupe.heureFin.format(context)}',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.people_outline,
                            size: 13, color: Colors.grey.shade500),
                        const SizedBox(width: 3),
                        Text(
                          '${groupe.etudiants.length} étudiant${groupe.etudiants.length != 1 ? "s" : ""}',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline,
                    color: Colors.red.shade400, size: 20),
                onPressed: () {
                  _showDeleteConfirmationDialog(
                      context, groupeController, groupe.id);
                },
              ),
              Icon(Icons.chevron_right,
                  color: Colors.grey.shade400, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.group_add,
                  size: 40, color: Color(0xFF2563EB)),
            ),
            const SizedBox(height: 20),
            Text(
              'Aucun groupe',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Créez votre premier groupe en appuyant\nsur le bouton ci-dessous',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmationDialog(BuildContext context,
      GroupeController groupeController, String groupeId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: Colors.red.shade400, size: 22),
              const SizedBox(width: 8),
              const Text('Supprimer le groupe'),
            ],
          ),
          content: const Text(
              'Êtes-vous sûr de vouloir supprimer ce groupe ?\nCette action est irréversible.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Annuler'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red, foregroundColor: Colors.white),
              child: const Text('Supprimer'),
              onPressed: () {
                groupeController.supprimerGroupe(groupeId);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}


