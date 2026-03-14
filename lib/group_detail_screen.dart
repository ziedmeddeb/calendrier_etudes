import 'package:calendrier_etude/student_history.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'controllers/groupe_controller.dart';
import 'models/groupe.dart';
import 'models/etudiant.dart';
import 'add_student_screen.dart';
import 'edit_student_screen.dart';
import 'edit_group_screen.dart';
import 'services/database_service.dart';

class GroupDetailScreen extends StatefulWidget {
  final Groupe groupe;
  GroupDetailScreen({required this.groupe});

  @override
  _GroupDetailScreenState createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  late Future<List<Etudiant>> _etudiantsFuture;

  @override
  void initState() {
    super.initState();
    _etudiantsFuture = _fetchEtudiants(widget.groupe.id);
  }

  Future<List<Etudiant>> _fetchEtudiants(String groupId) async {
    final etudiants = await DatabaseService().getEtudiants(groupId);
    for (var etudiant in etudiants) {
      final updatedEtudiant =
          await DatabaseService().getEtudiantById(etudiant.id);
      etudiant = updatedEtudiant!;
    }
    etudiants
        .sort((a, b) => a.nom.toLowerCase().compareTo(b.nom.toLowerCase()));
    return etudiants;
  }

  Future<void> _navigateToHistory(Etudiant etudiant) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StudentHistoryScreen(
          etudiant: etudiant,
          group: widget.groupe,
        ),
      ),
    );
    setState(() {
      _etudiantsFuture = _fetchEtudiants(widget.groupe.id);
    });
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

  Future<void> _confirmDeleteStudent(
      Etudiant etudiant, GroupeController groupeController) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirmation'),
          content: Text('Supprimer ${etudiant.nom} du groupe ?'),
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

    if (confirmed != true) return;

    // The controller method returns void, so don't await it.
    groupeController.supprimerEtudiantDuGroupe(
      widget.groupe.id,
      etudiant.id,
    );

    if (!mounted) return;

    setState(() {
      _etudiantsFuture = _fetchEtudiants(widget.groupe.id);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${etudiant.nom} supprime du groupe')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groupeController = Provider.of<GroupeController>(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(widget.groupe.nom),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Modifier le groupe',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditGroupScreen(groupe: widget.groupe),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildGroupInfoCard(context),
          Expanded(
            child: FutureBuilder<List<Etudiant>>(
              future: _etudiantsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text('Erreur: ${snapshot.error}'));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return _buildEmptyStudents();
                }
                final etudiants = snapshot.data!;
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: etudiants.length,
                  itemBuilder: (context, index) {
                    final etudiant = etudiants[index];
                    return _buildStudentCard(
                        context, etudiant, groupeController);
                  },
                );
              },
            ),
          ),
          _buildAddStudentButton(context),
        ],
      ),
    );
  }

  Widget _buildGroupInfoCard(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Row(
        children: [
          _infoTile(
              Icons.calendar_today_outlined, widget.groupe.jour, 'Jour'),
          const SizedBox(width: 12),
          _infoTile(
            Icons.access_time,
            '${widget.groupe.heureDebut.format(context)} - ${widget.groupe.heureFin.format(context)}',
            'Horaire',
          ),
          const SizedBox(width: 12),
          _infoTile(
            Icons.people_outline,
            '${widget.groupe.etudiants.length}',
            'Étudiants',
          ),
        ],
      ),
    );
  }

  Widget _infoTile(IconData icon, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 13, color: const Color(0xFF2563EB)),
                const SizedBox(width: 4),
                Text(label,
                    style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500)),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentCard(BuildContext context, Etudiant etudiant,
      GroupeController groupeController) {
    final unpaid = etudiant.unpaidSessions;
    final avatarColor = _avatarColor(etudiant.nom);
    final initials = etudiant.nom.isNotEmpty
        ? etudiant.nom
            .trim()
            .split(' ')
            .take(2)
            .map((w) => w[0].toUpperCase())
            .join()
        : '?';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: avatarColor.withOpacity(0.15),
              child: Text(
                initials,
                style: TextStyle(
                  color: avatarColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    etudiant.nom,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.school_outlined,
                          size: 12, color: Colors.grey.shade500),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          etudiant.lycee,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (unpaid > 0) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: unpaid >= 4
                            ? Colors.red.shade50
                            : Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$unpaid séance${unpaid > 1 ? "s" : ""} non payée${unpaid > 1 ? "s" : ""}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: unpaid >= 4
                              ? Colors.red.shade700
                              : Colors.amber.shade800,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _actionButton(Icons.history_outlined, Colors.blue,
                    () => _navigateToHistory(etudiant)),
                _actionButton(
                    Icons.swap_horiz_outlined, Colors.teal, () async {
                  await _showPermutationChoiceDialog(context, etudiant, groupeController);
                }),
                _actionButton(Icons.edit_outlined, Colors.grey.shade600,
                    () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EditStudentScreen(
                        groupeId: widget.groupe.id,
                        etudiant: etudiant,
                      ),
                    ),
                  );
                  setState(() {
                    _etudiantsFuture = _fetchEtudiants(widget.groupe.id);
                  });
                }),
                _actionButton(Icons.delete_outline, Colors.red.shade400,
                    () => _confirmDeleteStudent(etudiant, groupeController)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Step 1 : choix du type de permutation ───────────────────────────────
  Future<void> _showPermutationChoiceDialog(BuildContext context,
      Etudiant etudiant, GroupeController groupeController) async {
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
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'Choisissez le type de permutation',
                style:
                    TextStyle(fontSize: 13, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              // Option 1 – permuter avec un étudiant du groupe cible
              _choiceCard(
                icon: Icons.people_alt_outlined,
                color: Colors.indigo,
                title: 'Permuter avec un étudiant',
                subtitle:
                    'Échange de place avec un étudiant d\'un autre groupe',
                onTap: () => Navigator.pop(ctx, 'swap'),
              ),
              const SizedBox(height: 10),
              // Option 2 – déplacer directement
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
      await _showSwapWithStudentDialog(context, etudiant, groupeController);
    } else if (choice == 'move') {
      await _showMoveToGroupDialog(context, etudiant, groupeController);
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
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: color)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade600)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: color, size: 18),
          ],
        ),
      ),
    );
  }

  // ── Option 2 : déplacer directement vers un groupe ───────────────────────
  Future<void> _showMoveToGroupDialog(BuildContext context, Etudiant etudiant,
      GroupeController groupeController) async {
    final otherGroupes = groupeController.groupes
        .where((g) => g.id != widget.groupe.id)
        .toList();

    if (otherGroupes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Aucun autre groupe disponible.')));
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
                          widget.groupe.id,
                          selectedGroupe!.id,
                        );
                        setState(() {
                          _etudiantsFuture = _fetchEtudiants(widget.groupe.id);
                        });
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

  // ── Option 1 : permuter avec un étudiant d'un autre groupe ───────────────
  Future<void> _showSwapWithStudentDialog(BuildContext context,
      Etudiant etudiant, GroupeController groupeController) async {
    final otherGroupes = groupeController.groupes
        .where((g) => g.id != widget.groupe.id)
        .toList();

    if (otherGroupes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Aucun autre groupe disponible.')));
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
                  // Reminder of who we're swapping
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.person,
                            color: Colors.indigo, size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(etudiant.nom,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.indigo)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Center(
                      child: Icon(Icons.swap_vert,
                          color: Colors.grey, size: 20)),
                  const SizedBox(height: 4),
                  // Step 1 : choose group
                  const Text('Groupe :',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600)),
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
                  // Step 2 : choose student
                  if (selectedGroupe != null) ...[
                    const SizedBox(height: 12),
                    const Text('Étudiant à échanger :',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    if (targetStudents.isEmpty)
                      Text('Ce groupe n\'a aucun étudiant.',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade500))
                    else
                      // Use a fixed-height box + SingleChildScrollView to avoid
                      // the "intrinsic dimensions" crash with nested ListViews.
                      SizedBox(
                        height: targetStudents.length > 4
                            ? 220
                            : targetStudents.length * 56.0,
                        child: SingleChildScrollView(
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: const Color(0xFFE2E8F0)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: List.generate(
                                targetStudents.length,
                                (i) {
                                  final s = targetStudents[i];
                                  final isSelected =
                                      selectedTarget?.id == s.id;
                                  return Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (i > 0)
                                        const Divider(height: 1),
                                      ListTile(
                                        dense: true,
                                        selected: isSelected,
                                        selectedTileColor:
                                            Colors.indigo.shade50,
                                        leading: CircleAvatar(
                                          radius: 16,
                                          backgroundColor:
                                              Colors.indigo.withOpacity(0.12),
                                          child: Text(
                                            s.nom.isNotEmpty
                                                ? s.nom[0].toUpperCase()
                                                : '?',
                                            style: const TextStyle(
                                                color: Colors.indigo,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12),
                                          ),
                                        ),
                                        title: Text(s.nom,
                                            style: const TextStyle(
                                                fontSize: 13)),
                                        subtitle: Text(s.lycee,
                                            style: const TextStyle(
                                                fontSize: 11)),
                                        trailing: isSelected
                                            ? const Icon(Icons.check_circle,
                                                color: Colors.indigo,
                                                size: 18)
                                            : null,
                                        onTap: () => setD(
                                            () => selectedTarget = s),
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
                            widget.groupe.id,
                            selectedTarget!.id,
                            selectedGroupe!.id,
                          );
                          setState(() {
                            _etudiantsFuture =
                                _fetchEtudiants(widget.groupe.id);
                          });
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

  Widget _actionButton(IconData icon, Color color, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onPressed,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
      ),
    );
  }

  Widget _buildEmptyStudents() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_add_outlined,
                size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'Aucun étudiant',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              'Ajoutez des étudiants à ce groupe',
              style:
                  TextStyle(fontSize: 13, color: Colors.grey.shade400),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddStudentButton(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) =>
                      AddStudentScreen(groupeId: widget.groupe.id)),
            );
            setState(() {
              _etudiantsFuture = _fetchEtudiants(widget.groupe.id);
            });
          },
          icon: const Icon(Icons.person_add_outlined, size: 18),
          label: const Text('Ajouter un étudiant'),
        ),
      ),
    );
  }
}
