import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';

class BookingConfirmationScreen extends StatelessWidget {
  const BookingConfirmationScreen({super.key, required this.appointmentData});

  final Map<String, dynamic> appointmentData;

  @override
  Widget build(BuildContext context) {
    final doctor = appointmentData['doctor'] as Map?;
    final clinic = appointmentData['clinic'] as Map?;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),

              // Success animation
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  size: 80,
                  color: AppColors.success,
                ),
              ),

              const SizedBox(height: 24),

              Text(
                'Appointment Confirmed!',
                style: AppTextStyles.headlineSmall,
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 8),

              Text(
                'Your appointment has been booked successfully',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 32),

              // Appointment details card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _DetailRow(
                      icon: Icons.person_outline_rounded,
                      label: 'Doctor',
                      value: 'Dr. ${doctor?['name'] ?? ''}',
                    ),
                    const SizedBox(height: 12),
                    _DetailRow(
                      icon: Icons.location_on_outlined,
                      label: 'Clinic',
                      value: clinic?['name'] as String? ?? '',
                    ),
                    const SizedBox(height: 12),
                    _DetailRow(
                      icon: Icons.calendar_today_outlined,
                      label: 'Date',
                      value: appointmentData['date'] as String? ?? '',
                    ),
                    const SizedBox(height: 12),
                    _DetailRow(
                      icon: Icons.access_time_rounded,
                      label: 'Time',
                      value: '${appointmentData['startTime']} - ${appointmentData['endTime']}',
                    ),
                    const SizedBox(height: 12),
                    _DetailRow(
                      icon: Icons.confirmation_number_outlined,
                      label: 'Booking ID',
                      value: (appointmentData['id'] as String?)?.substring(0, 8).toUpperCase() ?? '',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Time disclaimer
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded, size: 18, color: Colors.amber.shade800),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Your slot time is approximate and may vary slightly depending on earlier consultations. Please arrive 5–10 minutes early.',
                        style: TextStyle(fontSize: 12, color: Colors.amber.shade900, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              AppButton(
                label: 'View My Appointments',
                onPressed: () => context.goNamed('appointments'),
              ),
              const SizedBox(height: 12),
              AppButton(
                label: 'Back to Home',
                variant: ButtonVariant.outlined,
                onPressed: () => context.goNamed('home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: AppTextStyles.labelSmall.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            Text(value, style: AppTextStyles.titleSmall),
          ],
        ),
      ],
    );
  }
}
