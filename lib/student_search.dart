import 'package:calendrier_etude/edit_student_screen.dart';
import 'package:calendrier_etude/student_history.dart';
import 'package:calendrier_etude/services/database_service.dart';
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

  // Filters
  String? _selectedLycee;
  String? _selectedJour;
  bool _onlyUnpaid = false;
  bool _onlyAnyUnpaid = false;
  bool _showFilters = false;
  List<String> _lycees = [];

  static const List<String> _jours = [
    'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'
  ];

  @override
  void initState() {
    super.initState();
    _loadLycees();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<GroupeController>(context, listen: false)
            .rechargerGroupes(context);
      }
    });
  }

  Future<void> _loadLycees() async {
    final lycees =
        await DatabaseService().getDistinctLycees();
    if (mounted) {
      setState(() => _lycees = lycees);
    }
  }

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
    return _buildBody(context);
  }

  Future<void> _confirmDeleteStudent(
      Etudiant etudiant, Groupe groupe, GroupeController groupeController) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirmation'),
          content: Text('Supprimer ${etudiant.nom} du groupe ${groupe.nom} ?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Supprimer'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    groupeController.supprimerEtudiantDuGroupe(groupe.id, etudiant.id);
    setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${etudiant.nom} supprimé du groupe')),
    );
  }

  Future<void> _showPermutationChoiceDialog(BuildContext context,
      Etudiant etudiant, Groupe groupe, GroupeController groupeController) async {
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.swap_horiz, color: Colors.teal, size: 36),
              const SizedBox(height: 12),
              Text(
                'Permuter ${etudiant.nom}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'Choisissez le type de permutation',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              _choiceCard(
                icon: Icons.people_alt_outlined,
                color: Colors.indigo,
                title: 'Permuter avec un étudiant',
                subtitle: 'Échange de place avec un étudiant d\'un autre groupe',
                onTap: () => Navigator.pop(ctx, 'swap'),
              ),
              const SizedBox(height: 10),
              _choiceCard(
                icon: Icons.arrow_forward_outlined,
                color: Colors.teal,
                title: 'Déplacer vers un groupe',
                subtitle: 'Transfère l\'étudiant sans échange',
                onTap: () => Navigator.pop(ctx, 'move'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annuler'),
              ),
            ],
          ),
        ),
      ),
    );

    if (choice == 'swap') {
      await _showSwapWithStudentDialog(context, etudiant, groupe, groupeController);
    } else if (choice == 'move') {
      await _showMoveToGroupDialog(context, etudiant, groupe, groupeController);
    }
  }

  Widget _choiceCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: color.withOpacity(0.15),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 13, color: color)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: color, size: 18),
          ],
        ),
      ),
    );
  }

  Future<void> _showMoveToGroupDialog(BuildContext context, Etudiant etudiant,
      Groupe currentGroupe, GroupeController groupeController) async {
    final otherGroupes = groupeController.groupes
        .where((g) => g.id != currentGroupe.id)
        .toList();

    if (otherGroupes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aucun autre groupe disponible.')));
      return;
    }

    Groupe? selectedGroupe;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text('Déplacer ${etudiant.nom}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Groupe de destination :'),
              const SizedBox(height: 12),
              DropdownButton<Groupe>(
                isExpanded: true,
                value: selectedGroupe,
                hint: const Text('Sélectionner un groupe'),
                items: otherGroupes
                    .map((g) => DropdownMenuItem(
                          value: g,
                          child: Text('${g.nom} (${g.jour})'),
                        ))
                    .toList(),
                onChanged: (g) => setD(() => selectedGroupe = g),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annuler')),
            ElevatedButton(
              onPressed: selectedGroupe == null
                  ? null
                  : () async {
                      Navigator.pop(ctx);
                      try {
                        await groupeController.transfererEtudiant(
                          etudiant.id,
                          currentGroupe.id,
                          selectedGroupe!.id,
                        );
                        setState(() {});
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(
                              '${etudiant.nom} déplacé vers ${selectedGroupe!.nom}'),
                          backgroundColor: Colors.teal,
                        ));
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('Erreur: $e'),
                            backgroundColor: Colors.red));
                      }
                    },
              child: const Text('Déplacer'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSwapWithStudentDialog(BuildContext context,
      Etudiant etudiant, Groupe currentGroupe, GroupeController groupeController) async {
    final otherGroupes = groupeController.groupes
        .where((g) => g.id != currentGroupe.id)
        .toList();

    if (otherGroupes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aucun autre groupe disponible.')));
      return;
    }

    Groupe? selectedGroupe;
    Etudiant? selectedTarget;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) {
          final targetStudents = selectedGroupe?.etudiants ?? [];
          return AlertDialog(
            title: const Text('Permuter avec un étudiant'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.person, color: Colors.indigo, size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(etudiant.nom,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, color: Colors.indigo)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Center(child: Icon(Icons.swap_vert, color: Colors.grey, size: 20)),
                  const SizedBox(height: 4),
                  const Text('Groupe :',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  DropdownButton<Groupe>(
                    isExpanded: true,
                    value: selectedGroupe,
                    hint: const Text('Sélectionner un groupe'),
                    items: otherGroupes
                        .map((g) => DropdownMenuItem(
                              value: g,
                              child: Text('${g.nom} (${g.jour})'),
                            ))
                        .toList(),
                    onChanged: (g) => setD(() {
                      selectedGroupe = g;
                      selectedTarget = null;
                    }),
                  ),
                  if (selectedGroupe != null) ...[
                    const SizedBox(height: 12),
                    const Text('Étudiant à échanger :',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    if (targetStudents.isEmpty)
                      Text('Ce groupe n\'a aucun étudiant.',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500))
                    else
                      SizedBox(
                        height: targetStudents.length > 4
                            ? 220
                            : targetStudents.length * 56.0,
                        child: SingleChildScrollView(
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: List.generate(
                                targetStudents.length,
                                (i) {
                                  final s = targetStudents[i];
                                  final isSelected = selectedTarget?.id == s.id;
                                  return Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (i > 0) const Divider(height: 1),
                                      ListTile(
                                        dense: true,
                                        selected: isSelected,
                                        selectedTileColor: Colors.indigo.shade50,
                                        leading: CircleAvatar(
                                          radius: 16,
                                          backgroundColor: Colors.indigo.withOpacity(0.12),
                                          child: Text(
                                            s.nom.isNotEmpty ? s.nom[0].toUpperCase() : '?',
                                            style: const TextStyle(
                                                color: Colors.indigo,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12),
                                          ),
                                        ),
                                        title: Text(s.nom, style: const TextStyle(fontSize: 13)),
                                        subtitle: Text(s.lycee, style: const TextStyle(fontSize: 11)),
                                        trailing: isSelected
                                            ? const Icon(Icons.check_circle,
                                                color: Colors.indigo, size: 18)
                                            : null,
                                        onTap: () => setD(() => selectedTarget = s),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Annuler')),
              ElevatedButton(
                onPressed: (selectedGroupe == null || selectedTarget == null)
                    ? null
                    : () async {
                        Navigator.pop(ctx);
                        try {
                          await groupeController.permuterEtudiants(
                            etudiant.id,
                            currentGroupe.id,
                            selectedTarget!.id,
                            selectedGroupe!.id,
                          );
                          setState(() {});
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  '${etudiant.nom} ↔ ${selectedTarget!.nom} permutés avec succès'),
                              backgroundColor: Colors.indigo,
                            ),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text('Erreur: $e'),
                              backgroundColor: Colors.red));
                        }
                      },
                child: const Text('Permuter'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterPanel() {
    final hasActiveFilters =
        _selectedLycee != null || _selectedJour != null || _onlyUnpaid || _onlyAnyUnpaid;
    return Container(
      color: Theme.of(context).cardTheme.color ?? Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Jour filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _jours.map((jour) {
                final selected = _selectedJour == jour;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(jour.substring(0, 3),
                        style: TextStyle(fontSize: 11,
                            color: selected ? Colors.white : null)),
                    selected: selected,
                    selectedColor: const Color(0xFF2563EB),
                    checkmarkColor: Colors.white,
                    visualDensity: VisualDensity.compact,
                    onSelected: (val) => setState(() =>
                        _selectedJour = val ? jour : null),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // Lycée dropdown
              if (_lycees.isNotEmpty)
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedLycee,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Lycée',
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                          value: null, child: Text('Tous')),
                      ..._lycees.map((l) =>
                          DropdownMenuItem(value: l, child: Text(l,
                              overflow: TextOverflow.ellipsis))),
                    ],
                    onChanged: (val) =>
                        setState(() => _selectedLycee = val),
                  ),
                ),
              const SizedBox(width: 12),
              // Unpaid ≥1 filter
              FilterChip(
                avatar: Icon(Icons.warning_amber,
                    size: 16,
                    color: _onlyAnyUnpaid ? Colors.white : Colors.amber.shade700),
                label: Text('Impayés ≥1',
                    style: TextStyle(fontSize: 11,
                        color: _onlyAnyUnpaid ? Colors.white : null)),
                selected: _onlyAnyUnpaid,
                selectedColor: Colors.amber.shade700,
                showCheckmark: false,
                onSelected: (val) =>
                    setState(() => _onlyAnyUnpaid = val),
              ),
              const SizedBox(width: 8),
              // Unpaid ≥4 filter
              FilterChip(
                avatar: Icon(Icons.warning_amber,
                    size: 16,
                    color: _onlyUnpaid ? Colors.white : Colors.red.shade400),
                label: Text('Impayés ≥4',
                    style: TextStyle(fontSize: 11,
                        color: _onlyUnpaid ? Colors.white : null)),
                selected: _onlyUnpaid,
                selectedColor: Colors.red.shade400,
                showCheckmark: false,
                onSelected: (val) =>
                    setState(() => _onlyUnpaid = val),
              ),
            ],
          ),
          if (hasActiveFilters)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: GestureDetector(
                onTap: () => setState(() {
                  _selectedLycee = null;
                  _selectedJour = null;
                  _onlyUnpaid = false;
                  _onlyAnyUnpaid = false;
                }),
                child: Text('✕ Réinitialiser les filtres',
                    style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final groupeController = Provider.of<GroupeController>(context);

    List<Etudiant> allStudents = [];
    Map<String, Groupe> studentGroupMap = {};
    for (Groupe groupe in groupeController.groupes) {
      for (var student in groupe.etudiants) {
        allStudents.add(student);
        studentGroupMap[student.id] = groupe;
      }
    }

    // Apply text search
    filteredStudents = searchQuery.isEmpty
        ? List.from(allStudents)
        : allStudents
            .where((student) =>
                student.nom.toLowerCase().contains(searchQuery.toLowerCase()))
            .toList();

    // Apply lycée filter
    if (_selectedLycee != null) {
      filteredStudents = filteredStudents
          .where((s) => s.lycee == _selectedLycee)
          .toList();
    }

    // Apply jour filter
    if (_selectedJour != null) {
      filteredStudents = filteredStudents.where((s) {
        final groupe = studentGroupMap[s.id];
        return groupe != null && groupe.jour == _selectedJour;
      }).toList();
    }

    // Apply unpaid filter (≥1)
    if (_onlyAnyUnpaid) {
      filteredStudents = filteredStudents
          .where((s) => s.unpaidSessions >= 1)
          .toList();
    }

    // Apply unpaid filter (≥4)
    if (_onlyUnpaid) {
      filteredStudents = filteredStudents
          .where((s) => s.unpaidSessions >= 4)
          .toList();
    }

    filteredStudents
        .sort((a, b) => a.nom.toLowerCase().compareTo(b.nom.toLowerCase()));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rechercher un étudiant'),
        actions: [
          IconButton(
            icon: Icon(_showFilters ? Icons.filter_list_off : Icons.filter_list),
            tooltip: 'Filtres',
            onPressed: () => setState(() => _showFilters = !_showFilters),
          ),
        ],
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
          if (_showFilters) _buildFilterPanel(),
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
                      return _buildStudentCard(context, student, groupe, groupeController);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentCard(
      BuildContext context, Etudiant student, Groupe groupe, GroupeController groupeController) {
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
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface,
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
                  ] else if (unpaid < 0) ...[
                    const SizedBox(height: 4),
                    _badge(
                      Icons.check_circle_outline,
                      '${unpaid.abs()} payée${unpaid.abs() > 1 ? "s" : ""} d\'avance',
                      Colors.green.shade700,
                      bgColor: Colors.green.shade50,
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
                _iconBtn(Icons.swap_horiz_outlined, Colors.teal, () async {
                  await _showPermutationChoiceDialog(
                      context, student, groupe, groupeController);
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
                _iconBtn(Icons.delete_outline, Colors.red.shade400, () {
                  _confirmDeleteStudent(student, groupe, groupeController);
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
