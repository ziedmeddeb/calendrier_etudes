import 'package:calendrier_etude/models/custom_seance.dart';
import 'package:calendrier_etude/models/etudiant_presence.dart';
import 'package:calendrier_etude/services/database_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import 'package:uuid/uuid.dart';

import 'controllers/groupe_controller.dart';
import 'models/groupe.dart';
import 'models/seance.dart';
import 'attendance_screen.dart';

class CalendarScreen extends StatefulWidget {
  @override
  _CalendarScreenState createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  CalendarView _currentView = CalendarView.week;
  final CalendarController _calendarController = CalendarController();
  List<Appointment> _appointments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAppointments();
  }

  Future<void> _loadAppointments() async {
    final appointments = await _getDataSource();
    if (mounted) {
      setState(() {
        _appointments = appointments;
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteCustomSession(CustomSeance session) async {
    final DatabaseService databaseService = DatabaseService();
    await databaseService.deleteCustomSeance(session.id);
    await _loadAppointments(); // Refresh appointments
  }

  Future<void> _addCustomSession(BuildContext context) async {
    final groupeController = context.read<GroupeController>();
    final DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(Duration(days: 365)),
      lastDate: DateTime.now().add(Duration(days: 365)),
    );

    if (selectedDate == null || !mounted) return;

    final TimeOfDay? startTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: 8, minute: 0),
    );

    if (startTime == null || !mounted) return;

    final TimeOfDay? endTime = await showTimePicker(
      context: context,
      initialTime:
          TimeOfDay(hour: startTime.hour + 1, minute: startTime.minute),
    );

    if (endTime == null || !mounted) return;

    final Groupe? selectedGroupe = await showDialog<Groupe>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Sélectionner un groupe'),
          content: Container(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: groupeController.groupes.length,
              itemBuilder: (context, index) {
                final groupe = groupeController.groupes[index];
                return ListTile(
                  title: Text(groupe.nom),
                  onTap: () => Navigator.of(context).pop(groupe),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              child: Text('Annuler'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );

    if (selectedGroupe != null) {
      final DateTime startDateTime = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        startTime.hour,
        startTime.minute,
      );

      final DateTime endDateTime = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        endTime.hour,
        endTime.minute,
      );

      await _saveCustomSession(selectedGroupe, startDateTime, endDateTime);
      await _loadAppointments();
    }
  }

  Future<void> _saveCustomSession(
    Groupe groupe,
    DateTime startDateTime,
    DateTime endDateTime,
  ) async {
    final DatabaseService databaseService = DatabaseService();
    final customSeance = CustomSeance(
      id: Uuid().v4(),
      groupeId: groupe.id,
      startTime: startDateTime,
      endTime: endDateTime,
    );

    await databaseService.insertCustomSeance(customSeance);
  }

  Future<List<Appointment>> _getDataSource() async {
    final groupeController = context.read<GroupeController>();
    final groupes = groupeController.groupes;
    List<Appointment> appointments = <Appointment>[];
    final DatabaseService databaseService = DatabaseService();

    // Regular weekly sessions
    for (var groupe in groupes) {
      List<DateTime> occurrences = _getAllOccurrences(groupe.jour);
      for (var occurrence in occurrences) {
        String dayName = _getDayName(occurrence.weekday);
        appointments.add(Appointment(
          startTime: DateTime(
            occurrence.year,
            occurrence.month,
            occurrence.day,
            groupe.heureDebut.hour,
            groupe.heureDebut.minute,
          ),
          endTime: DateTime(
            occurrence.year,
            occurrence.month,
            occurrence.day,
            groupe.heureFin.hour,
            groupe.heureFin.minute,
          ),
          subject: '${groupe.nom} - $dayName',
          color: Colors.blue,
          notes: groupe.id,
        ));
      }
    }

    // Add custom sessions
    final customSessions = await databaseService.getCustomSeances();
    for (var session in customSessions) {
      final groupe = groupes.firstWhere((g) => g.id == session.groupeId);
      appointments.add(Appointment(
        startTime: session.startTime,
        endTime: session.endTime,
        subject: '${groupe.nom} (Personnalisé)',
        color: Colors.green,
        notes: groupe.id,
      ));
    }

    return appointments;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Calendrier'),
        actions: [
          // ... existing PopupMenuButton code ...
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addCustomSession(context),
        child: Icon(Icons.add),
        tooltip: 'Ajouter une séance personnalisée',
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SfCalendar(
              controller: _calendarController,
              view: _currentView,
              dataSource: MeetingDataSource(_appointments),
              timeSlotViewSettings: TimeSlotViewSettings(
                startHour: 7,
                endHour: 23,
                timeFormat: 'HH:mm',
              ),
              viewHeaderStyle: ViewHeaderStyle(
                dayTextStyle: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              monthViewSettings: MonthViewSettings(
                appointmentDisplayMode: MonthAppointmentDisplayMode.appointment,
              ),
              headerDateFormat: 'MMMM yyyy',
              todayHighlightColor: Colors.blue,
              firstDayOfWeek: 1,
              onTap: (CalendarTapDetails details) {
                if (details.appointments != null &&
                    details.appointments!.isNotEmpty) {
                  final appointment =
                      details.appointments!.first as Appointment;
                  final groupeId = appointment.notes;
                  final groupeController = context.read<GroupeController>();
                  final groupe = groupeController.groupes
                      .firstWhere((g) => g.id == groupeId);

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AttendanceScreen(
                        groupe: groupe,
                        date: details.date ?? DateTime.now(),
                      ),
                    ),
                  );
                }
              },
              onLongPress: (CalendarLongPressDetails details) async {
                if (details.appointments != null &&
                    details.appointments!.isNotEmpty) {
                  final appointment =
                      details.appointments!.first as Appointment;

                  // Check if the long-pressed appointment is a custom session
                  if (appointment.color == Colors.green) {
                    final shouldDelete = await showDialog<bool>(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: Text('Supprimer la séance personnalisée'),
                          content: Text(
                              'Êtes-vous sûr de vouloir supprimer cette séance personnalisée ?'),
                          actions: [
                            TextButton(
                              child: Text('Annuler'),
                              onPressed: () => Navigator.of(context).pop(false),
                            ),
                            TextButton(
                              child: Text('Supprimer'),
                              onPressed: () => Navigator.of(context).pop(true),
                            ),
                          ],
                        );
                      },
                    );

                    if (shouldDelete == true) {
                      // Retrieve the CustomSeance instance
                      final customSessions =
                          await DatabaseService().getCustomSeances();
                      final session = customSessions.firstWhere((s) =>
                          s.startTime == appointment.startTime &&
                          s.endTime == appointment.endTime);

                      await _deleteCustomSession(session); // Delete the session
                      await _loadAppointments(); // Reload appointments
                    }
                  }
                }
              },
            ),
    );
  }

  List<DateTime> _getAllOccurrences(String jour) {
    final now = DateTime.now();
    final startDate =
        now.subtract(Duration(days: 365)); // Start from 1 year ago

    final daysOfWeek = {
      'Lundi': DateTime.monday,
      'Mardi': DateTime.tuesday,
      'Mercredi': DateTime.wednesday,
      'Jeudi': DateTime.thursday,
      'Vendredi': DateTime.friday,
      'Samedi': DateTime.saturday,
      'Dimanche': DateTime.sunday,
    };

    int weekday = daysOfWeek[jour]!;
    List<DateTime> occurrences = [];
    DateTime occurrence = startDate;

    // Find first occurrence of the weekday
    while (occurrence.weekday != weekday) {
      occurrence = occurrence.add(Duration(days: 1));
    }

    // Add occurrences for past year and upcoming year
    final endDate = now.add(Duration(days: 365));
    while (occurrence.isBefore(endDate)) {
      occurrences.add(occurrence);
      occurrence = occurrence.add(Duration(days: 7));
    }

    return occurrences;
  }

  String _getDayName(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Lundi';
      case DateTime.tuesday:
        return 'Mardi';
      case DateTime.wednesday:
        return 'Mercredi';
      case DateTime.thursday:
        return 'Jeudi';
      case DateTime.friday:
        return 'Vendredi';
      case DateTime.saturday:
        return 'Samedi';
      case DateTime.sunday:
        return 'Dimanche';
      default:
        return '';
    }
  }
}

class MeetingDataSource extends CalendarDataSource {
  MeetingDataSource(List<Appointment> source) {
    appointments = source;
  }
}
