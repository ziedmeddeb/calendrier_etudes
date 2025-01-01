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

  @override
  void initState() {
    super.initState();
    _studentNameController = TextEditingController(text: widget.etudiant.nom);
    _studentLyceeController =
        TextEditingController(text: widget.etudiant.lycee);
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      final updatedEtudiant = Etudiant(
        id: widget.etudiant.id,
        nom: _studentNameController.text,
        lycee: _studentLyceeController.text,
        unpaidSessions: widget.etudiant.unpaidSessions,
      );
      Provider.of<GroupeController>(context, listen: false)
          .modifierEtudiantDuGroupe(widget.groupeId, updatedEtudiant);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Modifier Étudiant')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _studentNameController,
                decoration: InputDecoration(labelText: 'Nom de l\'Étudiant'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez entrer un nom';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _studentLyceeController,
                decoration: InputDecoration(labelText: 'Lycée de l\'Étudiant'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez entrer un lycée';
                  }
                  return null;
                },
              ),
              ElevatedButton(
                onPressed: _submitForm,
                child: Text('Modifier Étudiant'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
