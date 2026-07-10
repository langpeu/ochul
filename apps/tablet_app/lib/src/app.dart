import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/app_config.dart';
import 'features/admin/admin_dashboard.dart';
import 'features/attendance/student_attendance_screen.dart';
import 'features/auth/auth_service.dart';
import 'features/auth/login_screen.dart';
import 'features/teacher/teacher_dashboard.dart';

class OchulApp extends StatelessWidget {
  const OchulApp({super.key, required this.config});

  final AppConfig config;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ochul',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF006D77),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F8FA),
        cardTheme: const CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
            side: BorderSide(color: Color(0xFFE3E7EB)),
          ),
        ),
      ),
      home: AppShell(config: config),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.config});

  final AppConfig config;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  var _selectedIndex = 0;
  var _isSignedIn = false;
  late final AuthService? _authService;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _authService = widget.config.isSupabaseConfigured
        ? AuthService(config: widget.config)
        : null;
    _isSignedIn = _authService?.currentSession != null;
    _authSubscription = _authService?.onAuthStateChange.listen((state) {
      if (!mounted) {
        return;
      }
      setState(() => _isSignedIn = state.session != null);
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isSignedIn) {
      return LoginScreen(
        config: widget.config,
        authService: _authService,
        onDesignModeSignedIn: () => setState(() => _isSignedIn = true),
      );
    }

    final destinations = <_Destination>[
      _Destination(
        label: '출석',
        icon: Icons.fact_check_outlined,
        selectedIcon: Icons.fact_check,
        child: StudentAttendanceScreen(config: widget.config),
      ),
      _Destination(
        label: '선생님',
        icon: Icons.dashboard_outlined,
        selectedIcon: Icons.dashboard,
        child: TeacherDashboard(config: widget.config),
      ),
      _Destination(
        label: '관리자',
        icon: Icons.admin_panel_settings_outlined,
        selectedIcon: Icons.admin_panel_settings,
        child: const AdminDashboard(),
      ),
    ];

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              setState(() => _selectedIndex = index);
            },
            labelType: NavigationRailLabelType.all,
            destinations: [
              for (final destination in destinations)
                NavigationRailDestination(
                  icon: Icon(destination.icon),
                  selectedIcon: Icon(destination.selectedIcon),
                  label: Text(destination.label),
                ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: destinations[_selectedIndex].child),
        ],
      ),
    );
  }
}

class _Destination {
  const _Destination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.child,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget child;
}
