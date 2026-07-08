import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/doctors/presentation/doctors_screen.dart';
import '../../features/users/presentation/users_screen.dart';
import '../../features/clinics/presentation/clinics_screen.dart';
import '../../features/appointments/presentation/appointments_screen.dart';
import '../widgets/admin_shell.dart';

final routerProvider = Provider<GoRouter>((_) {
  return GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      ShellRoute(
        builder: (_, __, child) => AdminShell(child: child),
        routes: [
          GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen()),
          GoRoute(path: '/doctors', builder: (_, __) => const DoctorsScreen()),
          GoRoute(path: '/users', builder: (_, __) => const UsersScreen()),
          GoRoute(path: '/clinics', builder: (_, __) => const ClinicsScreen()),
          GoRoute(path: '/appointments', builder: (_, __) => const AdminAppointmentsScreen()),
        ],
      ),
    ],
  );
});
