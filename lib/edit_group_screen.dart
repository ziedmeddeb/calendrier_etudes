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
        if (isStartTime)
          _selectedStartTime = picked;
        else
          _selectedEndTime = picked;
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
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: const Text('Modifier Groupe')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionCard(
                children: [
                  _sectionTitle('Informations du groupe'),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _groupNameController,
                    decoration: const InputDecoration(
                      labelText: 'Nom du groupe',
                      prefixIcon: Icon(Icons.group_outlined),
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Veuillez entrer un nom de groupe';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedDay,
                    decoration: const InputDecoration(
                      labelText: 'Jour de la semaine',
                      prefixIcon: Icon(Icons.calendar_today_outlined),
                    ),
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
                    onChanged: (value) =>
                        setState(() => _selectedDay = value!),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _sectionCard(
                children: [
                  _sectionTitle('Horaire'),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _timePicker(
                          label: 'Heure de début',
                          time: _selectedStartTime,
                          onTap: () => _selectTime(context, true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _timePicker(
                          label: 'Heure de fin',
                          time: _selectedEndTime,
                          onTap: () => _selectTime(context, false),
                        ),
                      ),
                    ],
                  ),
                ],
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

  Widget _sectionCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Color(0xFF2563EB),
          letterSpacing: 0.3),
    );
  }

  Widget _timePicker(
      {required String label,
      required TimeOfDay time,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.access_time,
                    size: 16, color: Color(0xFF2563EB)),
                const SizedBox(width: 6),
                Text(time.format(context),
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
