import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'controllers/groupe_controller.dart';
import 'controllers/theme_controller.dart';

import 'calendar_screen.dart';
import 'group_management_screen.dart';
import 'data_screen.dart';
import 'dashboard_screen.dart';
import 'services/database_service.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'services/auth_service.dart';
import 'activation_screen.dart';
import 'locked_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await NotificationService().init();
  runApp(MyApp());
}

class AppTheme {
  // Sophisticated Indigo + Slate palette
  static const Color primaryColor = Color(0xFF4F46E5);       // Deep Indigo
  static const Color secondaryColor = Color(0xFF7C3AED);     // Purple
  static const Color accentColor = Color(0xFF10B981);        // Emerald
  static const Color errorColor = Color(0xFFEF4444);         // Red
  static const Color warningColor = Color(0xFFF59E0B);       // Amber
  static const Color surfaceColor = Color(0xFFF7F9FB);       // Cool off-white
  static const Color surfaceContainerColor = Color(0xFFF2F4F6); // Subtle separator
  static const Color textHighEmphasis = Color(0xFF1E293B);   // Deep slate
  static const Color textSecondary = Color(0xFF64748B);      // Softer slate
  static const Color cardColor = Colors.white;

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        primary: const Color(0xFF818CF8),   // Lighter indigo for dark mode
        secondary: const Color(0xFFA78BFA),
        tertiary: const Color(0xFF34D399),
        error: errorColor,
        surface: const Color(0xFF1E1E2E),
        brightness: Brightness.dark,
      ),
      textTheme: GoogleFonts.manropeTextTheme(ThemeData.dark().textTheme),
      scaffoldBackgroundColor: const Color(0xFF121220),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: const Color(0xFF1E1E2E),
        foregroundColor: Colors.white,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: GoogleFonts.manrope(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        iconTheme: const IconThemeData(color: Color(0xFF818CF8)),
        shape: const Border(
          bottom: BorderSide(color: Color(0xFF2A2A3E), width: 1),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shadowColor: Colors.black26,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF2A2A3E), width: 1),
        ),
        color: const Color(0xFF2A2A3E),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF818CF8),
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFF818CF8),
          textStyle: GoogleFonts.manrope(fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Color(0xFF818CF8),
        foregroundColor: Colors.white,
        elevation: 4,
        shape: CircleBorder(),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF2A2A3E),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF3A3A4E)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF3A3A4E)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF818CF8), width: 2),
        ),
        labelStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
        hintStyle: const TextStyle(color: Color(0xFF6B7280), fontSize: 14),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF2A2A3E),
        thickness: 1,
        space: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 8,
        backgroundColor: const Color(0xFF2A2A3E),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        selectedItemColor: const Color(0xFF818CF8),
        unselectedItemColor: const Color(0xFF6B7280),
        backgroundColor: const Color(0xFF1E1E2E),
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: GoogleFonts.manrope(fontWeight: FontWeight.w700, fontSize: 11),
        unselectedLabelStyle: GoogleFonts.manrope(fontSize: 11),
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        primary: primaryColor,
        secondary: secondaryColor,
        tertiary: accentColor,
        error: errorColor,
        surface: surfaceColor,
        brightness: Brightness.light,
      ),
      textTheme: GoogleFonts.manropeTextTheme(ThemeData.light().textTheme),
      scaffoldBackgroundColor: surfaceColor,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: Colors.white,
        foregroundColor: textHighEmphasis,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: GoogleFonts.manrope(
          color: textHighEmphasis,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        iconTheme: const IconThemeData(color: primaryColor),
        shape: const Border(
          bottom: BorderSide(color: surfaceContainerColor, width: 1),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: surfaceContainerColor, width: 1),
        ),
        color: cardColor,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          textStyle: GoogleFonts.manrope(fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: StadiumBorder(),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceContainerColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: surfaceContainerColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: surfaceContainerColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        labelStyle: const TextStyle(color: textSecondary, fontSize: 14),
        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      dividerTheme: const DividerThemeData(
        color: surfaceContainerColor,
        thickness: 1,
        space: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        backgroundColor: Colors.white,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        selectedItemColor: primaryColor,
        unselectedItemColor: textSecondary,
        backgroundColor: Colors.white,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: GoogleFonts.manrope(fontWeight: FontWeight.w700, fontSize: 11),
        unselectedLabelStyle: GoogleFonts.manrope(fontSize: 11),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => GroupeController(context)),
        ChangeNotifierProvider(create: (context) => ThemeController()),
      ],
      child: Consumer<ThemeController>(
        builder: (context, themeController, _) => MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Gestion Cours Particuliers',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeController.themeMode,
          localizationsDelegates: [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: [
            const Locale('fr'),
            const Locale('en'),
          ],
          locale: const Locale('fr'),
          home: const AppGate(),
        ),
      ),
    );
  }
}

enum _AppState { loading, notActivated, locked, ready }

class AppGate extends StatefulWidget {
  const AppGate({super.key});

  @override
  State<AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<AppGate> {
  _AppState _state = _AppState.loading;

  @override
  void initState() {
    super.initState();
    _checkState();
  }

  Future<void> _checkState() async {
    setState(() => _state = _AppState.loading);
    final activated = await AuthService.instance.isActivated();
    if (!mounted) return;
    if (!activated) {
      setState(() => _state = _AppState.notActivated);
      return;
    }
    final binding = await AuthService.instance.verifyBinding();
    if (!mounted) return;
    if (binding == null) {
      setState(() => _state = _AppState.ready);
    } else {
      setState(() => _state = _AppState.notActivated);
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (_state) {
      case _AppState.loading:
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      case _AppState.notActivated:
        return ActivationScreen(onActivated: _checkState);
      case _AppState.locked:
        return const LockedScreen();
      case _AppState.ready:
        return HomeScreen();
    }
  }
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  int _unpaidAlertCount = 0;

  static const int _unpaidThreshold = 4;

  static List<Widget> _widgetOptions = <Widget>[
    CalendarScreen(),
    GroupManagementScreen(),
    DashboardScreen(),
    DataScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _refreshUnpaidCount();
  }

  Future<void> _refreshUnpaidCount() async {
    final students = await DatabaseService()
        .getStudentsWithUnpaidAboveThreshold(_unpaidThreshold);
    if (mounted) {
      setState(() {
        _unpaidAlertCount = students.length;
      });
    }
  }

  void _onItemTapped(int index) {
    _refreshUnpaidCount();
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _widgetOptions.elementAt(_selectedIndex),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF1E1E2E)
              : Colors.white,
          border: Border(
            top: BorderSide(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF2A2A3E)
                  : const Color(0xFFF2F4F6),
              width: 1,
            ),
          ),
        ),
        child: BottomNavigationBar(
          items: <BottomNavigationBarItem>[
            const BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today_outlined),
              activeIcon: Icon(Icons.calendar_today),
              label: 'Calendrier',
            ),
            BottomNavigationBarItem(
              icon: Badge(
                isLabelVisible: _unpaidAlertCount > 0,
                label: Text('$_unpaidAlertCount',
                    style: const TextStyle(fontSize: 10)),
                backgroundColor: Colors.red,
                child: const Icon(Icons.group_outlined),
              ),
              activeIcon: Badge(
                isLabelVisible: _unpaidAlertCount > 0,
                label: Text('$_unpaidAlertCount',
                    style: const TextStyle(fontSize: 10)),
                backgroundColor: Colors.red,
                child: const Icon(Icons.group),
              ),
              label: 'Groupes',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings),
              label: 'Config',
            ),
          ],
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
        ),
      ),
    );
  }
}
