import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import 'controllers/groupe_controller.dart';
import 'models/groupe.dart';
import 'attendance_screen.dart';

class CalendarScreen extends StatefulWidget {
  @override
  _CalendarScreenState createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  @override
  Widget build(BuildContext context) {
    final groupeController = Provider.of<GroupeController>(context);
    final groupes = groupeController.groupes;

    List<Appointment> _getDataSource() {
      List<Appointment> appointments = <Appointment>[];
      for (var groupe in groupes) {
        List<DateTime> occurrences = _getAllOccurrences(groupe.jour);
        for (var occurrence in occurrences) {
          appointments.add(Appointment(
            startTime: DateTime(
                occurrence.year,
                occurrence.month,
                occurrence.day,
                groupe.heureDebut.hour,
                groupe.heureDebut.minute),
            endTime: DateTime(occurrence.year, occurrence.month, occurrence.day,
                groupe.heureFin.hour, groupe.heureFin.minute),
            subject: groupe.nom,
            color: Colors.blue,
            notes: groupe.id,
          ));
        }
      }
      return appointments;
    }

    return Scaffold(
      body: SfCalendar(
        view: CalendarView.week,
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
          ),
        ),
        monthViewSettings: MonthViewSettings(
          appointmentDisplayMode: MonthAppointmentDisplayMode.appointment,
        ),
        headerDateFormat: 'MMMM yyyy',
        todayHighlightColor: Colors.blue,
        firstDayOfWeek: 1, // Lundi

        onTap: (CalendarTapDetails details) {
          if (details.appointments != null &&
              details.appointments!.isNotEmpty) {
            final appointment = details.appointments!.first as Appointment;
            final groupeId = appointment.notes;
            final groupe = groupes.firstWhere((g) => g.id == groupeId);
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => AttendanceScreen(groupe: groupe)),
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
}

class MeetingDataSource extends CalendarDataSource {
  MeetingDataSource(List<Appointment> source) {
    appointments = source;
  }
}
