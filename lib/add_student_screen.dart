import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'controllers/groupe_controller.dart';
import 'models/etudiant.dart';
import 'services/database_service.dart';

class AddStudentScreen extends StatefulWidget {
  final String groupeId;
  AddStudentScreen({required this.groupeId});

  @override
  _AddStudentScreenState createState() => _AddStudentScreenState();
}

class _AddStudentScreenState extends State<AddStudentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _studentNameController = TextEditingController();
  final _studentLyceeController = TextEditingController();
  final _searchController = TextEditingController();

  List<Etudiant> _allStudents = [];
  List<Etudiant> _filteredStudents = [];
  bool _loadingStudents = false;
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();
    _loadAllStudents();
  }

  Future<void> _loadAllStudents() async {
    setState(() => _loadingStudents = true);
    final students = await DatabaseService().getAllEtudiants();
    setState(() {
      _allStudents = students;
      _loadingStudents = false;
    });
  }

  void _onSearchChanged(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filteredStudents = [];
        _showSuggestions = false;
      } else {
        _filteredStudents = _allStudents
            .where((e) => e.nom.toLowerCase().contains(q))
            .toList()
          ..sort((a, b) => a.nom.toLowerCase().compareTo(b.nom.toLowerCase()));
        _showSuggestions = _filteredStudents.isNotEmpty;
      }
    });
  }

  void _selectExistingStudent(Etudiant etudiant) {
    setState(() {
      _studentNameController.text = etudiant.nom;
      _studentLyceeController.text = etudiant.lycee;
      _searchController.clear();
      _showSuggestions = false;
      _filteredStudents = [];
    });
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      final etudiant = Etudiant(
        id: Uuid().v4(),
        nom: _studentNameController.text,
        lycee: _studentLyceeController.text,
      );
      Provider.of<GroupeController>(context, listen: false)
          .ajouterEtudiantAuGroupe(widget.groupeId, etudiant);
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _studentNameController.dispose();
    _studentLyceeController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: const Text('Ajouter un Étudiant')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Recherche d'étudiant existant ──
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2)),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Rechercher un étudiant existant',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2563EB)),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Tapez un nom pour retrouver un étudiant déjà enregistré.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        labelText: 'Rechercher par nom',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  _onSearchChanged('');
                                },
                              )
                            : null,
                      ),
                      onChanged: _onSearchChanged,
                    ),
                    if (_loadingStudents)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    if (_showSuggestions) ...[
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        constraints: const BoxConstraints(maxHeight: 220),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: _filteredStudents.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final s = _filteredStudents[index];
                            return ListTile(
                              dense: true,
                              leading: CircleAvatar(
                                radius: 18,
                                backgroundColor:
                                    const Color(0xFF3B82F6).withOpacity(0.1),
                                child: Text(
                                  s.nom.isNotEmpty
                                      ? s.nom[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                      color: Color(0xFF3B82F6),
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              title: Text(s.nom,
                                  style: const TextStyle(fontSize: 13)),
                              subtitle: Text(s.lycee,
                                  style: const TextStyle(fontSize: 11)),
                              onTap: () => _selectExistingStudent(s),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Formulaire nouveau / pré-rempli ──
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2)),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Informations de l\'étudiant',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2563EB)),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _studentNameController,
                      decoration: const InputDecoration(
                        labelText: 'Nom complet',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      textCapitalization: TextCapitalization.words,
                      validator: (value) {
                        if (value == null || value.isEmpty)
                          return 'Veuillez entrer un nom';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _studentLyceeController,
                      decoration: const InputDecoration(
                        labelText: 'Lycée / Établissement',
                        prefixIcon: Icon(Icons.school_outlined),
                      ),
                      textCapitalization: TextCapitalization.words,
                      validator: (value) {
                        if (value == null || value.isEmpty)
                          return 'Veuillez entrer un lycée';
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _submitForm,
                  icon: const Icon(Icons.person_add_outlined, size: 18),
                  label: const Text('Ajouter l\'étudiant'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
