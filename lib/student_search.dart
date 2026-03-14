import 'package:calendrier_etude/edit_student_screen.dart';
import 'package:calendrier_etude/student_history.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'controllers/groupe_controller.dart';
import 'models/etudiant.dart';
import 'models/groupe.dart';

class StudentSearchScreen extends StatefulWidget {
  @override
  _StudentSearchScreenState createState() => _StudentSearchScreenState();
}

class _StudentSearchScreenState extends State<StudentSearchScreen> {
  String searchQuery = '';
  List<Etudiant> filteredStudents = [];
  final TextEditingController _searchController = TextEditingController();

  Color _avatarColor(String name) {
    final colors = [
      const Color(0xFF3B82F6),
      const Color(0xFF8B5CF6),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFFEF4444),
      const Color(0xFFEC4899),
      const Color(0xFF6366F1),
    ];
    return colors[name.codeUnitAt(0) % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final groupeController = Provider.of<GroupeController>(context);

    List<Etudiant> allStudents = [];
    for (Groupe groupe in groupeController.groupes) {
      allStudents.addAll(groupe.etudiants);
    }

    filteredStudents = searchQuery.isEmpty
        ? allStudents
        : allStudents
            .where((student) =>
                student.nom.toLowerCase().contains(searchQuery.toLowerCase()))
            .toList();
    filteredStudents
        .sort((a, b) => a.nom.toLowerCase().compareTo(b.nom.toLowerCase()));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Rechercher un étudiant'),
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Nom de l\'étudiant...',
                prefixIcon: const Icon(Icons.search, color: Color(0xFF2563EB)),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => searchQuery = '');
                        },
                      )
                    : null,
              ),
              onChanged: (value) => setState(() => searchQuery = value),
            ),
          ),
          if (filteredStudents.isNotEmpty)
            Container(
              color: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text(
                    '${filteredStudents.length} étudiant${filteredStudents.length > 1 ? "s" : ""} trouvé${filteredStudents.length > 1 ? "s" : ""}',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          const Divider(height: 1),
          Expanded(
            child: filteredStudents.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off,
                            size: 56, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text(
                          searchQuery.isEmpty
                              ? 'Commencez à taper pour chercher'
                              : 'Aucun résultat',
                          style: TextStyle(
                              fontSize: 15, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: filteredStudents.length,
                    itemBuilder: (context, index) {
                      final student = filteredStudents[index];
                      final groupe = groupeController.groupes.firstWhere(
                        (g) => g.etudiants.contains(student),
                        orElse: () =>
                            throw Exception('Student not found in any group'),
                      );
                      return _buildStudentCard(context, student, groupe);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentCard(
      BuildContext context, Etudiant student, Groupe groupe) {
    final color = _avatarColor(student.nom);
    final initials = student.nom.isNotEmpty
        ? student.nom
            .trim()
            .split(' ')
            .take(2)
            .map((w) => w[0].toUpperCase())
            .join()
        : '?';
    final unpaid = student.unpaidSessions;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: color.withValues(alpha: 0.15),
              child: Text(
                initials,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 14),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    student.nom,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _badge(Icons.group_outlined, groupe.nom,
                          const Color(0xFF2563EB)),
                      _badge(Icons.calendar_today_outlined, groupe.jour,
                          const Color(0xFF8B5CF6)),
                      _badge(Icons.school_outlined, student.lycee,
                          Colors.grey.shade600,
                          bgColor: Colors.grey.shade100),
                    ],
                  ),
                  if (unpaid > 0) ...[
                    const SizedBox(height: 4),
                    _badge(
                      Icons.warning_amber_outlined,
                      '$unpaid non payée${unpaid > 1 ? "s" : ""}',
                      unpaid >= 4
                          ? Colors.red.shade700
                          : Colors.amber.shade800,
                      bgColor: unpaid >= 4
                          ? Colors.red.shade50
                          : Colors.amber.shade50,
                    ),
                  ],
                ],
              ),
            ),
            Column(
              children: [
                _iconBtn(Icons.history_outlined, Colors.blue, () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => StudentHistoryScreen(
                        etudiant: student,
                        group: groupe,
                      ),
                    ),
                  );
                }),
                _iconBtn(Icons.edit_outlined, Colors.grey.shade600, () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EditStudentScreen(
                        groupeId: groupe.id,
                        etudiant: student,
                      ),
                    ),
                  );
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(IconData icon, String text, Color color,
      {Color? bgColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor ?? color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(
            text,
            style:
                TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _iconBtn(IconData icon, Color color, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }
}
