import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/doctors/presentation/doctors_screen.dart';
import '../../features/users/presentation/users_screen.dart';
import '../../features/clinics/presentation/clinics_screen.dart';
import '../../features/appointments/presentation/appointments_screen.dart';
import '../../features/categories/presentation/categories_screen.dart';
import '../widgets/admin_shell.dart';

final routerProvider = Provider<GoRouter>((_) {
  return GoRouter(
    initialLocation: '/login',
    redirect: (_, state) async {
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: 'access_token');
      final onLogin = state.matchedLocation == '/login';
      if (token == null && !onLogin) return '/login';
      if (token != null && onLogin) return '/dashboard';
      return null;
    },
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
          GoRoute(path: '/categories', builder: (_, __) => const CategoriesScreen()),
        ],
      ),
    ],
  );
});
