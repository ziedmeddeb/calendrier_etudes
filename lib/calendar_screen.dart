import 'package:calendrier_etude/models/custom_seance.dart';
import 'package:calendrier_etude/models/etudiant_presence.dart';
import 'package:calendrier_etude/services/database_service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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

// Appointment color constants — used both when creating and when checking type
const Color _kSessionColor = Color(0xFF4F46E5);   // indigo — recorded session
const Color _kPendingColor = Color(0xFFF43F5E);   // rose  — no data yet
const Color _kCustomColor = Color(0xFF10B981);    // emerald — custom session

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
            Icon(Icons.label_outline, size: 20, color: Color(0xFF4F46E5)),
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
            Icon(Icons.group_outlined, size: 20, color: Color(0xFF4F46E5)),
            SizedBox(width: 8),
            Expanded(child: Text('Sélectionner un groupe')),
          ]),
          content: SizedBox(
            width: double.maxFinite,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
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
                            color: Color(0xFF4F46E5)),
                      ),
                    ),
                    title: Text(groupe.nom),
                    subtitle: Text(groupe.jour),
                    onTap: () => Navigator.of(context).pop(groupe),
                  );
                },
              ),
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
            color: _kCustomColor,
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
            color: seanceInfo != null ? _kSessionColor : _kPendingColor,
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
          color: _kCustomColor,
          notes: groupe.id,
        ));
      }
    }

    return appointments;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Calendrier',
          style: GoogleFonts.manrope(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            color: isDark ? Colors.white : const Color(0xFF1E293B),
          ),
        ),
        actions: [
          _ViewSwitcherButton(
            currentView: _currentView,
            isDark: isDark,
            onViewSelected: (newView) {
              setState(() {
                _currentView = newView;
                _calendarController.view = newView;
              });
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addCustomSession(context),
        icon: const Icon(Icons.add_rounded),
        label: Text(
          'Séance',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        backgroundColor: const Color(0xFF4F46E5),
        foregroundColor: Colors.white,
        elevation: 3,
      ),
      body: Consumer<GroupeController>(
        builder: (context, groupeController, child) {
          if (_isLoading) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(
                    color: Color(0xFF4F46E5),
                    strokeWidth: 2.5,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Chargement du calendrier…',
                    style: GoogleFonts.manrope(
                      color: const Color(0xFF64748B),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
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
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(Icons.event_note_outlined,
                          size: 38, color: Color(0xFF4F46E5)),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Aucun groupe',
                      style: GoogleFonts.manrope(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Créez d\'abord un groupe pour voir\nles séances dans le calendrier',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        color: const Color(0xFF64748B),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final calTextColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B);
          final calHeaderColor = isDark ? Colors.white : const Color(0xFF1E293B);
          final calBg = isDark ? const Color(0xFF1E1E2E) : Colors.white;
          final calCellBg = isDark ? const Color(0xFF121220) : const Color(0xFFF7F9FB);
          final calBorderColor = isDark ? const Color(0xFF2A2A3E) : const Color(0xFFF2F4F6);

          return SfCalendar(
            controller: _calendarController,
            view: _currentView,
            dataSource: MeetingDataSource(_appointments),
            backgroundColor: calCellBg,
            cellBorderColor: calBorderColor,
            timeSlotViewSettings: TimeSlotViewSettings(
              startHour: 7,
              endHour: 23,
              timeFormat: 'HH:mm',
              timeIntervalHeight: 52,
              timeTextStyle: GoogleFonts.manrope(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: calTextColor,
              ),
            ),
            viewHeaderStyle: ViewHeaderStyle(
              backgroundColor: calBg,
              dayTextStyle: GoogleFonts.manrope(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: calTextColor,
                letterSpacing: 0.8,
              ),
              dateTextStyle: GoogleFonts.manrope(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: calHeaderColor,
              ),
            ),
            monthViewSettings: const MonthViewSettings(
              appointmentDisplayMode: MonthAppointmentDisplayMode.appointment,
            ),
            headerStyle: CalendarHeaderStyle(
              backgroundColor: calBg,
              textStyle: GoogleFonts.manrope(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: calHeaderColor,
                letterSpacing: -0.2,
              ),
            ),
            headerDateFormat: 'MMMM yyyy',
            todayHighlightColor: const Color(0xFF4F46E5),
            todayTextStyle: GoogleFonts.manrope(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
            selectionDecoration: BoxDecoration(
              border: Border.all(color: const Color(0xFF4F46E5), width: 2),
              borderRadius: BorderRadius.circular(6),
            ),
            firstDayOfWeek: 1,
            onTap: (CalendarTapDetails details) async {
              if (details.appointments != null &&
                  details.appointments!.isNotEmpty) {
                final appointment = details.appointments!.first as Appointment;
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
                final appointment = details.appointments!.first as Appointment;
                final isCustom = appointment.color == _kCustomColor;

                await showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF2F4F6),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.tune_rounded,
                                size: 16, color: Color(0xFF64748B)),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Options de la séance',
                            style: GoogleFonts.manrope(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                        ],
                      ),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isCustom)
                            _OptionTile(
                              icon: Icons.delete_outline_rounded,
                              iconColor: const Color(0xFFF43F5E),
                              iconBg: const Color(0xFFFFF1F2),
                              label: 'Supprimer la séance',
                              onTap: () => Navigator.of(context).pop('delete'),
                            ),
                          if (!isCustom)
                            _OptionTile(
                              icon: Icons.visibility_off_outlined,
                              iconColor: const Color(0xFFF59E0B),
                              iconBg: const Color(0xFFFFFBEB),
                              label: 'Masquer cette séance',
                              onTap: () => Navigator.of(context).pop('hide'),
                            ),
                        ],
                      ),
                    );
                  },
                ).then((result) async {
                  if (!mounted) return;
                  if (result == 'delete') {
                    final shouldDelete = await showDialog<bool>(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: Row(children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF1F2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.warning_amber_rounded,
                                  size: 16, color: Color(0xFFF43F5E)),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Supprimer la séance',
                              style: GoogleFonts.manrope(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF1E293B),
                              ),
                            ),
                          ]),
                          content: Text(
                            'Êtes-vous sûr de vouloir supprimer cette séance personnalisée ?',
                            style: GoogleFonts.manrope(
                              fontSize: 14,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                          actions: [
                            TextButton(
                              child: const Text('Annuler'),
                              onPressed: () => Navigator.of(context).pop(false),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFF43F5E),
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Supprimer'),
                              onPressed: () => Navigator.of(context).pop(true),
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
                    if (!mounted) return;
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

}

class _ViewSwitcherButton extends StatelessWidget {
  const _ViewSwitcherButton({
    required this.currentView,
    required this.isDark,
    required this.onViewSelected,
  });

  final CalendarView currentView;
  final bool isDark;
  final ValueChanged<CalendarView> onViewSelected;

  @override
  Widget build(BuildContext context) {
    final views = [
      (CalendarView.day, Icons.calendar_view_day_outlined, 'Journalier'),
      (CalendarView.week, Icons.calendar_view_week_outlined, 'Semaine'),
      (CalendarView.month, Icons.calendar_month_outlined, 'Mois'),
    ];

    return PopupMenuButton<CalendarView>(
      tooltip: 'Changer la vue',
      initialValue: currentView,
      onSelected: onViewSelected,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: isDark ? const Color(0xFF2A2A3E) : Colors.white,
      offset: const Offset(0, 8),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2A2A3E) : const Color(0xFFF2F4F6),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.tune_rounded,
              size: 16,
              color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5),
            ),
            const SizedBox(width: 5),
            Text(
              _labelFor(currentView),
              style: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5),
              ),
            ),
          ],
        ),
      ),
      itemBuilder: (_) => views.map((v) {
        final (view, icon, label) = v;
        final isActive = currentView == view;
        return PopupMenuItem(
          value: view,
          child: Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: isActive
                    ? const Color(0xFF4F46E5)
                    : (isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B)),
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive
                      ? const Color(0xFF4F46E5)
                      : (isDark ? Colors.white : const Color(0xFF1E293B)),
                ),
              ),
              if (isActive) ...[
                const Spacer(),
                const Icon(Icons.check_rounded, size: 14, color: Color(0xFF4F46E5)),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }

  String _labelFor(CalendarView view) {
    switch (view) {
      case CalendarView.day:
        return 'Jour';
      case CalendarView.week:
        return 'Semaine';
      case CalendarView.month:
        return 'Mois';
      default:
        return 'Vue';
    }
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1E293B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MeetingDataSource extends CalendarDataSource {
  MeetingDataSource(List<Appointment> source) {
    appointments = source;
  }
}
