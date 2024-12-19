import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'controllers/groupe_controller.dart';
import 'models/groupe.dart';

class EditGroupScreen extends StatefulWidget {
  final Groupe groupe;

  EditGroupScreen({required this.groupe});

  @override
  _EditGroupScreenState createState() => _EditGroupScreenState();
}

class _EditGroupScreenState extends State<EditGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _groupNameController;
  late String _selectedDay;
  late TimeOfDay _selectedStartTime;
  late TimeOfDay _selectedEndTime;

  @override
  void initState() {
    super.initState();
    _groupNameController = TextEditingController(text: widget.groupe.nom);
    _selectedDay = widget.groupe.jour;
    _selectedStartTime = widget.groupe.heureDebut;
    _selectedEndTime = widget.groupe.heureFin;
  }

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
      final updatedGroupe = Groupe(
        id: widget.groupe.id,
        nom: _groupNameController.text,
        etudiants: widget.groupe.etudiants,
        jour: _selectedDay,
        heureDebut: _selectedStartTime,
        heureFin: _selectedEndTime,
      );
      Provider.of<GroupeController>(context, listen: false)
          .modifierGroupe(updatedGroupe, context);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Modifier Groupe')),
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
                child: Text('Modifier Groupe'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
