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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeApp();
    });
  }

  Future<void> _initializeApp() async {
    final groupeController = context.read<GroupeController>();
    groupeController.addListener(_onGroupesChanged);

    try {
      setState(() {
        _isLoading = true;
      });

      // Run all initialization steps in sequence
      await DatabaseService().createHiddenSeancesTable();
      // await DatabaseService().addNameColumnToTables();
      // await DatabaseService().cleanupSeanceDates();
      await _loadAppointments();
    } catch (e) {
      print('Error during initialization: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    final groupeController = context.read<GroupeController>();
    groupeController.removeListener(_onGroupesChanged);
    super.dispose();
  }

  void _onGroupesChanged() {
    _loadAppointments();
  }

  Future<void> _initializeCalendar() async {
    await DatabaseService().addNameColumnToTables();
    await _loadAppointments();
  }

  Future<void> _loadAppointments() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final appointments = await _getDataSource();
      if (mounted) {
        setState(() {
          _appointments = appointments;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Future<void> _loadAppointments() async {
  //   final appointments = await _getDataSource();
  //   if (mounted) {
  //     setState(() {
  //       _appointments = appointments;
  //       _isLoading = false;
  //     });
  //   }
  // }

  Future<void> _deleteCustomSession(CustomSeance session) async {
    final DatabaseService databaseService = DatabaseService();
    await databaseService.deleteCustomSeance(session.id);
    await _loadAppointments(); // Refresh appointments
  }

  Future<void> _addCustomSession(BuildContext context) async {
    final groupeController = context.read<GroupeController>();

    // Get the date
    final DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(Duration(days: 365)),
      lastDate: DateTime.now().add(Duration(days: 365)),
    );

    if (selectedDate == null || !mounted) return;

    // Get the start time
    final TimeOfDay? startTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: 8, minute: 0),
    );

    if (startTime == null || !mounted) return;

    // Get the end time
    final TimeOfDay? endTime = await showTimePicker(
      context: context,
      initialTime:
          TimeOfDay(hour: startTime.hour + 1, minute: startTime.minute),
    );

    if (endTime == null || !mounted) return;

    // Add session name input
    final TextEditingController nameController =
        TextEditingController(text: "Séance");
    final String? sessionName = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(children: [
            Icon(Icons.label_outline, size: 20, color: Color(0xFF2563EB)),
            SizedBox(width: 8),
            Text('Nom de la séance'),
          ]),
          content: TextField(
            controller: nameController,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Ex: Séance de rattrapage',
              prefixIcon: Icon(Icons.edit_outlined),
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Annuler'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              child: const Text('Confirmer'),
              onPressed: () => Navigator.of(context).pop(nameController.text),
            ),
          ],
        );
      },
    );

    if (sessionName == null || !mounted) return;

    // Select groupe
    final Groupe? selectedGroupe = await showDialog<Groupe>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(children: [
            Icon(Icons.group_outlined, size: 20, color: Color(0xFF2563EB)),
            SizedBox(width: 8),
            Text('Sélectionner un groupe'),
          ]),
          content: Container(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: groupeController.groupes.length,
              itemBuilder: (context, index) {
                final groupe = groupeController.groupes[index];
                return ListTile(
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: const Color(0xFFEFF6FF),
                    child: Text(
                      groupe.nom[0].toUpperCase(),
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2563EB)),
                    ),
                  ),
                  title: Text(groupe.nom),
                  subtitle: Text(groupe.jour),
                  onTap: () => Navigator.of(context).pop(groupe),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Annuler'),
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

      await _saveCustomSession(
        selectedGroupe,
        startDateTime,
        endDateTime,
        sessionName,
      );
      await _loadAppointments();
    }
  }

  Future<void> _saveCustomSession(
    Groupe groupe,
    DateTime startDateTime,
    DateTime endDateTime,
    String sessionName,
  ) async {
    final DatabaseService databaseService = DatabaseService();
    final customSeance = CustomSeance(
      id: Uuid().v4(),
      groupeId: groupe.id,
      startTime: startDateTime,
      endTime: endDateTime,
      name: sessionName,
    );

    await databaseService.insertCustomSeance(customSeance);
  }

  Future<List<Appointment>> _getDataSource() async {
    final groupeController = context.read<GroupeController>();
    final groupes = groupeController.groupes;
    List<Appointment> appointments = <Appointment>[];
    final DatabaseService databaseService = DatabaseService();

    // First, fetch all seances for the time range we're interested in
    final now = DateTime.now();
    final startRange = now.subtract(Duration(days: 365));
    final endRange = now.add(Duration(days: 365));

    // Get all seances for this date range
    final allSeances =
        await databaseService.getAllSeancesInRange(startRange, endRange);

    // Group seances by their date hour for quick lookup
    final seancesByDateTime = <String, Map<String, dynamic>>{};
    for (var seance in allSeances) {
      final key =
          '${seance.date.year}-${seance.date.month}-${seance.date.day}-${seance.date.hour}';
      if (!seancesByDateTime.containsKey(key)) {
        seancesByDateTime[key] = {
          'name': seance.name,
          'etudiantIds': <String>{},
          'presenceCount': 0
        };
      }
      seancesByDateTime[key]!['etudiantIds'].add(seance.etudiantId);
      if (seance.present) {
        seancesByDateTime[key]!['presenceCount']++;
      }
    }

    // Get hidden séances
    final hiddenSeances = await databaseService.getHiddenSeances();
    final hiddenSeanceKeys = hiddenSeances.map((hs) {
      final date = DateTime.parse(hs['date'] as String);
      return '${date.year}-${date.month}-${date.day}-${date.hour}-${hs['groupe_id']}';
    }).toSet();

    // Get custom sessions first
    final customSessions = await databaseService.getCustomSeances();
    final customSessionKeys = <String, CustomSeance>{};
    for (var session in customSessions) {
      final key =
          '${session.startTime.year}-${session.startTime.month}-${session.startTime.day}-${session.startTime.hour}';
      customSessionKeys[key] = session;
    }

    // Regular weekly sessions
    for (var groupe in groupes) {
      List<DateTime> occurrences = _getAllOccurrences(groupe.jour);
      for (var occurrence in occurrences) {
        final startTime = DateTime(
          occurrence.year,
          occurrence.month,
          occurrence.day,
          groupe.heureDebut.hour,
          groupe.heureDebut.minute,
        );

        final endTime = DateTime(
          occurrence.year,
          occurrence.month,
          occurrence.day,
          groupe.heureFin.hour,
          groupe.heureFin.minute,
        );

        final key =
            '${startTime.year}-${startTime.month}-${startTime.day}-${startTime.hour}';
        // print('Custom sessions loaded:');
        // customSessionKeys.forEach((key, session) {
        //   print('Key: $key, Name: ${session.name}');
        // });
        // Check if this is a custom session time
        // Check if this is a custom session time
        final customSession = customSessionKeys[key];
        if (customSession != null && customSession.groupeId == groupe.id) {
          // This is a custom session
          // Debug custom session data
          print('Custom session found - Name: ${customSession.name}');

          appointments.add(Appointment(
            startTime: customSession.startTime,
            endTime: customSession.endTime,
            subject: '${groupe.nom} - ${customSession.name}',
            color: Colors.green,
            notes: groupe.id,
          ));
          continue; // Skip adding regular session
        }
        // Regular session handling
        if (!hiddenSeanceKeys.contains('$key-${groupe.id}')) {
          final seanceInfo = seancesByDateTime[key];
          appointments.add(Appointment(
            startTime: startTime,
            endTime: endTime,
            subject: seanceInfo != null
                ? '${groupe.nom} - ${seanceInfo['name']}'
                : groupe.nom,
            color: seanceInfo != null ? Colors.blue : Colors.red,
            notes: groupe.id,
          ));
        }
      }
    }

    // Add custom sessions that don't align with regular times
    for (var session in customSessions) {
      final groupe = groupes.cast<Groupe?>().firstWhere(
          (g) => g!.id == session.groupeId,
          orElse: () => null);
      if (groupe == null) continue;

      // Check if we've already added this session (in the regular sessions loop)
      bool alreadyAdded = false;
      for (var occurrence in _getAllOccurrences(groupe.jour)) {
        if (occurrence.year == session.startTime.year &&
            occurrence.month == session.startTime.month &&
            occurrence.day == session.startTime.day &&
            groupe.heureDebut.hour == session.startTime.hour) {
          alreadyAdded = true;
          break;
        }
      }

      if (!alreadyAdded) {
        appointments.add(Appointment(
          startTime: session.startTime,
          endTime: session.endTime,
          subject: '${groupe.nom} - ${session.name}',
          color: Colors.green,
          notes: groupe.id,
        ));
      }
    }

    return appointments;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendrier'),
        actions: [
          PopupMenuButton<CalendarView>(
            icon: const Icon(Icons.calendar_view_week_outlined),
            tooltip: 'Changer la vue',
            initialValue: _currentView,
            onSelected: (CalendarView newView) {
              setState(() {
                _currentView = newView;
                _calendarController.view = newView;
              });
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem(
                value: CalendarView.day,
                child: Row(children: [
                  Icon(Icons.calendar_view_day_outlined, size: 18),
                  SizedBox(width: 8),
                  Text('Vue journalière'),
                ]),
              ),
              const PopupMenuItem(
                value: CalendarView.week,
                child: Row(children: [
                  Icon(Icons.calendar_view_week_outlined, size: 18),
                  SizedBox(width: 8),
                  Text('Vue semaine'),
                ]),
              ),
              const PopupMenuItem(
                value: CalendarView.month,
                child: Row(children: [
                  Icon(Icons.calendar_month_outlined, size: 18),
                  SizedBox(width: 8),
                  Text('Vue mois'),
                ]),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addCustomSession(context),
        child: const Icon(Icons.add),
        tooltip: 'Ajouter une séance personnalisée',
      ),
      body: Consumer<GroupeController>(
        builder: (context, groupeController, child) {
          if (_isLoading) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    'Chargement du calendrier...',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  ),
                ],
              ),
            );
          }

          if (groupeController.groupes.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(Icons.event_note_outlined,
                          size: 40, color: Color(0xFF2563EB)),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Aucun groupe',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onSurface),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Créez d\'abord un groupe pour voir\nles séances dans le calendrier',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 14, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            );
          }

          final isDark = Theme.of(context).brightness == Brightness.dark;
          final calTextColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B);
          final calHeaderColor = isDark ? Colors.white : const Color(0xFF1E293B);
          final calBg = isDark ? const Color(0xFF1E1E2E) : Colors.white;
          final calCellBg = isDark ? const Color(0xFF121220) : Colors.white;

          return SfCalendar(
            controller: _calendarController,
            view: _currentView,
            dataSource: MeetingDataSource(_appointments),
            backgroundColor: calCellBg,
            cellBorderColor: isDark ? const Color(0xFF2A2A3E) : null,
            timeSlotViewSettings: TimeSlotViewSettings(
              startHour: 7,
              endHour: 23,
              timeFormat: 'HH:mm',
              timeTextStyle: TextStyle(
                fontSize: 11,
                color: calTextColor,
              ),
            ),
            viewHeaderStyle: ViewHeaderStyle(
              backgroundColor: calBg,
              dayTextStyle: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: calTextColor,
              ),
              dateTextStyle: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: calHeaderColor,
              ),
            ),
            monthViewSettings: const MonthViewSettings(
              appointmentDisplayMode: MonthAppointmentDisplayMode.appointment,
            ),
            headerStyle: CalendarHeaderStyle(
              backgroundColor: calBg,
              textStyle: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: calHeaderColor,
              ),
            ),
            headerDateFormat: 'MMMM yyyy',
            todayHighlightColor: const Color(0xFF2563EB),
            todayTextStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
            selectionDecoration: BoxDecoration(
              border: Border.all(color: const Color(0xFF2563EB), width: 2),
              borderRadius: BorderRadius.circular(4),
            ),
            firstDayOfWeek: 1,
            onTap: (CalendarTapDetails details) async {
              if (details.appointments != null &&
                  details.appointments!.isNotEmpty) {
                final appointment =
                    details.appointments!.first as Appointment;
                final groupe = groupeController.groupes
                    .firstWhere((g) => g.id == appointment.notes);

                final normalizedDate = DateTime(
                  appointment.startTime.year,
                  appointment.startTime.month,
                  appointment.startTime.day,
                  appointment.startTime.hour,
                );

                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AttendanceScreen(
                      groupe: groupe,
                      date: normalizedDate,
                    ),
                  ),
                );

                await _loadAppointments();
              }
            },
            onLongPress: (CalendarLongPressDetails details) async {
              if (details.appointments != null &&
                  details.appointments!.isNotEmpty) {
                final appointment =
                    details.appointments!.first as Appointment;

                await showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: Row(
                        children: [
                          Icon(Icons.more_horiz, color: Colors.grey.shade600),
                          const SizedBox(width: 8),
                          const Text('Options de la séance'),
                        ],
                      ),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (appointment.color == Colors.green)
                            ListTile(
                              leading: Icon(Icons.delete_outline,
                                  color: Colors.red.shade400),
                              title: const Text('Supprimer la séance'),
                              contentPadding: EdgeInsets.zero,
                              onTap: () async {
                                Navigator.of(context).pop('delete');
                              },
                            ),
                          if (appointment.color != Colors.green)
                            ListTile(
                              leading: Icon(Icons.visibility_off_outlined,
                                  color: Colors.orange.shade600),
                              title: const Text('Masquer cette séance'),
                              contentPadding: EdgeInsets.zero,
                              onTap: () async {
                                Navigator.of(context).pop('hide');
                              },
                            ),
                        ],
                      ),
                    );
                  },
                ).then((result) async {
                  if (result == 'delete') {
                    final shouldDelete = await showDialog<bool>(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: Row(children: [
                            Icon(Icons.warning_amber_rounded,
                                color: Colors.red.shade400, size: 22),
                            const SizedBox(width: 8),
                            const Text('Supprimer la séance'),
                          ]),
                          content: const Text(
                              'Êtes-vous sûr de vouloir supprimer cette séance personnalisée ?'),
                          actions: [
                            TextButton(
                              child: const Text('Annuler'),
                              onPressed: () =>
                                  Navigator.of(context).pop(false),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white),
                              child: const Text('Supprimer'),
                              onPressed: () =>
                                  Navigator.of(context).pop(true),
                            ),
                          ],
                        );
                      },
                    );

                    if (shouldDelete == true) {
                      final customSessions =
                          await DatabaseService().getCustomSeances();

                      final session = customSessions.firstWhere((s) =>
                          s.startTime == appointment.startTime &&
                          s.endTime == appointment.endTime);
                      await _deleteCustomSession(session);
                    }
                  } else if (result == 'hide') {
                    final groupe = groupeController.groupes
                        .firstWhere((g) => g.id == appointment.notes);
                    await DatabaseService()
                        .hideSeance(appointment.startTime, groupe.id);
                  }
                  await _loadAppointments();
                });
              }
            },
          );
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
