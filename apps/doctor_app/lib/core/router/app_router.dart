import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/appointments/presentation/appointments_screen.dart';
import '../../features/schedule/presentation/schedule_screen.dart';
import '../../features/profile/presentation/doctor_profile_screen.dart';

final _storageProvider = Provider<FlutterSecureStorage>(
  (_) => const FlutterSecureStorage(aOptions: AndroidOptions(encryptedSharedPreferences: true)),
);

final routerProvider = Provider<GoRouter>((ref) {
  final storage = ref.watch(_storageProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (_, state) async {
      final token = await storage.read(key: 'access_token');
      final isLogin = state.matchedLocation == '/login';
      if (token == null && !isLogin) return '/login';
      if (token != null && isLogin) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      ShellRoute(
        builder: (_, __, child) => _DoctorShell(child: child),
        routes: [
          GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen()),
          GoRoute(path: '/appointments', builder: (_, __) => const AppointmentsScreen()),
          GoRoute(path: '/schedule', builder: (_, __) => const ScheduleScreen()),
          GoRoute(path: '/profile', builder: (_, __) => const DoctorProfileScreen()),
        ],
      ),
    ],
  );
});

class _DoctorShell extends StatefulWidget {
  const _DoctorShell({required this.child});
  final Widget child;

  @override
  State<_DoctorShell> createState() => _DoctorShellState();
}

class _DoctorShellState extends State<_DoctorShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) {
          setState(() => _index = i);
          switch (i) {
            case 0: context.go('/dashboard');
            case 1: context.go('/appointments');
            case 2: context.go('/schedule');
            case 3: context.go('/profile');
          }
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.calendar_today_outlined), selectedIcon: Icon(Icons.calendar_today), label: 'Appointments'),
          NavigationDestination(icon: Icon(Icons.schedule_outlined), selectedIcon: Icon(Icons.schedule), label: 'Schedule'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
