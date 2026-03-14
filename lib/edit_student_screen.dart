import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'controllers/groupe_controller.dart';
import 'models/etudiant.dart';

class EditStudentScreen extends StatefulWidget {
  final String groupeId;
  final Etudiant etudiant;
  EditStudentScreen({required this.groupeId, required this.etudiant});

  @override
  _EditStudentScreenState createState() => _EditStudentScreenState();
}

class _EditStudentScreenState extends State<EditStudentScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _studentNameController;
  late TextEditingController _studentLyceeController;
  late bool _isGratuit;

  @override
  void initState() {
    super.initState();
    _studentNameController = TextEditingController(text: widget.etudiant.nom);
    _studentLyceeController = TextEditingController(text: widget.etudiant.lycee);
    _isGratuit = widget.etudiant.isGratuit;
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      final updatedEtudiant = Etudiant(
        id: widget.etudiant.id,
        nom: _studentNameController.text,
        lycee: _studentLyceeController.text,
        unpaidSessions: widget.etudiant.unpaidSessions,
        isGratuit: _isGratuit,
      );
      Provider.of<GroupeController>(context, listen: false)
          .modifierEtudiantDuGroupe(widget.groupeId, updatedEtudiant);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: const Text('Modifier Étudiant')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Informations de l\'étudiant',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
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
                        if (value == null || value.isEmpty) return 'Veuillez entrer un nom';
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
                        if (value == null || value.isEmpty) return 'Veuillez entrer un lycée';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      value: _isGratuit,
                      onChanged: (value) {
                        setState(() {
                          _isGratuit = value ?? false;
                        });
                      },
                      title: const Text('Étudiant gratuit',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                      subtitle: const Text(
                          'Les séances ne seront pas comptées comme impayées',
                          style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      activeColor: const Color(0xFF2563EB),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _submitForm,
                  icon: const Icon(Icons.save_outlined, size: 18),
                  label: const Text('Enregistrer les modifications'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
