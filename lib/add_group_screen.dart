import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'controllers/groupe_controller.dart';
import 'models/groupe.dart';

class AddGroupScreen extends StatefulWidget {
  @override
  _AddGroupScreenState createState() => _AddGroupScreenState();
}

class _AddGroupScreenState extends State<AddGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _groupNameController = TextEditingController();
  String _selectedDay = 'Lundi';
  TimeOfDay _selectedStartTime = TimeOfDay(hour: 16, minute: 0);
  TimeOfDay _selectedEndTime = TimeOfDay(hour: 18, minute: 0);

  void _selectTime(BuildContext context, bool isStartTime) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStartTime ? _selectedStartTime : _selectedEndTime,
    );
    if (picked != null) {
      setState(() {
        if (isStartTime) {
          _selectedStartTime = picked;
        } else {
          _selectedEndTime = picked;
        }
      });
    }
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      final groupe = Groupe(
        id: DateTime.now().toString(),
        nom: _groupNameController.text,
        etudiants: [],
        jour: _selectedDay,
        heureDebut: _selectedStartTime,
        heureFin: _selectedEndTime,
      );
      Provider.of<GroupeController>(context, listen: false)
          .ajouterGroupe(groupe, context); // Passer le BuildContext ici
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Ajouter un Groupe')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _groupNameController,
                decoration: InputDecoration(labelText: 'Nom du Groupe'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez entrer un nom de groupe';
                  }
                  return null;
                },
              ),
              DropdownButtonFormField<String>(
                value: _selectedDay,
                decoration: InputDecoration(labelText: 'Jour de la Semaine'),
                items: [
                  'Lundi',
                  'Mardi',
                  'Mercredi',
                  'Jeudi',
                  'Vendredi',
                  'Samedi',
                  'Dimanche'
                ]
                    .map((day) => DropdownMenuItem(
                          value: day,
                          child: Text(day),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedDay = value!;
                  });
                },
              ),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Heure de Début',
                        hintText: _selectedStartTime.format(context),
                      ),
                      onTap: () => _selectTime(context, true),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Heure de Fin',
                        hintText: _selectedEndTime.format(context),
                      ),
                      onTap: () => _selectTime(context, false),
                    ),
                  ),
                ],
              ),
              ElevatedButton(
                onPressed: _submitForm,
                child: Text('Ajouter Groupe'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
