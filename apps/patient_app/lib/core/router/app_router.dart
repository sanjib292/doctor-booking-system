import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/screens/phone_input_screen.dart';
import '../../features/auth/presentation/screens/otp_verification_screen.dart';
import '../../features/auth/presentation/screens/registration_screen.dart';
import '../../features/home/presentation/screens/main_navigation_screen.dart';
import '../../features/doctors/presentation/screens/doctor_search_screen.dart';
import '../../features/doctors/presentation/screens/doctor_profile_screen.dart';
import '../../features/appointments/presentation/screens/slot_selection_screen.dart';
import '../../features/appointments/presentation/screens/booking_confirmation_screen.dart';
import '../../features/appointments/presentation/screens/appointments_screen.dart';
import '../../features/appointments/presentation/screens/appointment_detail_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../storage/auth_storage.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authStorage = ref.watch(authStorageProvider);

  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: true,
    redirect: (context, state) async {
      final isLoggedIn = await authStorage.isLoggedIn();
      final isAuthRoute = state.matchedLocation.startsWith('/auth');

      if (!isLoggedIn && !isAuthRoute) return '/auth/phone';
      if (isLoggedIn && isAuthRoute) return '/home';
      return null;
    },
    routes: [
      // Auth flow
      GoRoute(
        path: '/auth/phone',
        name: 'phoneInput',
        builder: (_, __) => const PhoneInputScreen(),
      ),
      GoRoute(
        path: '/auth/otp',
        name: 'otpVerification',
        builder: (_, state) {
          final phone = state.extra as String;
          return OtpVerificationScreen(phone: phone);
        },
      ),
      GoRoute(
        path: '/auth/register',
        name: 'registration',
        builder: (_, state) {
          final data = state.extra as Map<String, dynamic>;
          return RegistrationScreen(
            phone: data['phone'] as String,
            token: data['token'] as String,
          );
        },
      ),

      // Main shell
      ShellRoute(
        builder: (context, state, child) => MainNavigationScreen(child: child),
        routes: [
          GoRoute(
            path: '/home',
            name: 'home',
            builder: (_, __) => const SizedBox.shrink(), // handled by MainNavigationScreen
          ),
          GoRoute(
            path: '/search',
            name: 'search',
            builder: (_, __) => const DoctorSearchScreen(),
          ),
          GoRoute(
            path: '/appointments',
            name: 'appointments',
            builder: (_, __) => const AppointmentsScreen(),
          ),
          GoRoute(
            path: '/profile',
            name: 'profile',
            builder: (_, __) => const ProfileScreen(),
          ),
        ],
      ),

      // Doctor profile (outside shell for full-screen)
      GoRoute(
        path: '/doctors/:id',
        name: 'doctorProfile',
        builder: (_, state) => DoctorProfileScreen(doctorId: state.pathParameters['id']!),
      ),

      // Booking flow
      GoRoute(
        path: '/doctors/:id/book',
        name: 'slotSelection',
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>;
          return SlotSelectionScreen(
            doctorId: state.pathParameters['id']!,
            clinicId: extra['clinicId'] as String,
            doctorName: extra['doctorName'] as String,
          );
        },
      ),
      GoRoute(
        path: '/booking/confirm',
        name: 'bookingConfirmation',
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>;
          return BookingConfirmationScreen(appointmentData: extra);
        },
      ),

      // Appointment detail
      GoRoute(
        path: '/appointments/:id',
        name: 'appointmentDetail',
        builder: (_, state) =>
            AppointmentDetailScreen(appointmentId: state.pathParameters['id']!),
      ),

      // Notifications
      GoRoute(
        path: '/notifications',
        name: 'notifications',
        builder: (_, __) => const NotificationsScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Page not found: ${state.uri}')),
    ),
  );
});
