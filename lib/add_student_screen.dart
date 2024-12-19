import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'controllers/groupe_controller.dart';
import 'models/etudiant.dart';

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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Ajouter Étudiant')),
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
                child: Text('Ajouter Étudiant'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
