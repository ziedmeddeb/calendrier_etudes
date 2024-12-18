import 'package:calendrier_etude/models/etudiant_presence.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';

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

  @override
  Widget build(BuildContext context) {
    // Use context.watch to safely access providers
    final groupeController = context.watch<GroupeController>();

    final groupes = groupeController.groupes;

    List<Appointment> _getDataSource() {
      List<Appointment> appointments = <Appointment>[];
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
                groupe.heureDebut.minute),
            endTime: DateTime(occurrence.year, occurrence.month, occurrence.day,
                groupe.heureFin.hour, groupe.heureFin.minute),
            subject: '${groupe.nom} - $dayName',
            color: Colors.blue,
            notes: groupe.id,
          ));
        }
      }
      return appointments;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Calendrier'),
        actions: [
          PopupMenuButton<CalendarView>(
            icon: Icon(Icons.view_column),
            onSelected: (CalendarView view) {
              setState(() {
                _currentView = view;
                _calendarController.view = view;
              });
            },
            itemBuilder: (BuildContext context) =>
                <PopupMenuEntry<CalendarView>>[
              PopupMenuItem<CalendarView>(
                value: CalendarView.week,
                child: Text('Vue Semaine'),
              ),
              PopupMenuItem<CalendarView>(
                value: CalendarView.month,
                child: Text('Vue Mois'),
              ),
              PopupMenuItem<CalendarView>(
                value: CalendarView.day,
                child: Text('Vue Jour'),
              ),
            ],
          ),
        ],
      ),
      body: SfCalendar(
        controller: _calendarController,
        view: _currentView,
        dataSource: MeetingDataSource(_getDataSource()),
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
            final appointment = details.appointments!.first as Appointment;
            final groupeId = appointment.notes;
            final groupe = groupes.firstWhere((g) => g.id == groupeId);

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AttendanceScreen(
                    groupe: groupe, date: details.date ?? DateTime.now()),
              ),
            );
          }
        },
      ),
    );
  }

  List<DateTime> _getAllOccurrences(String jour) {
    final now = DateTime.now();
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
    DateTime occurrence = now;

    // Adjust to the first occurrence of the specified day
    while (occurrence.weekday != weekday) {
      occurrence = occurrence.add(Duration(days: 1));
    }

    for (int i = 0; i < 52; i++) {
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
