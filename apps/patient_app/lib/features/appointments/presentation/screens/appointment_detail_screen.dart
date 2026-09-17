import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../providers/appointments_provider.dart';

class AppointmentDetailScreen extends ConsumerStatefulWidget {
  const AppointmentDetailScreen({
    super.key,
    required this.appointmentId,
    this.appointmentData,
  });
  final String appointmentId;
  final Map<String, dynamic>? appointmentData;

  @override
  ConsumerState<AppointmentDetailScreen> createState() => _AppointmentDetailScreenState();
}

class _AppointmentDetailScreenState extends ConsumerState<AppointmentDetailScreen> {
  bool _cancelling = false;

  @override
  Widget build(BuildContext context) {
    if (widget.appointmentData != null) {
      return _buildScaffold(context, widget.appointmentData!);
    }

    final fetched = ref.watch(appointmentByIdProvider(widget.appointmentId));
    return fetched.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Appointment Details')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Appointment Details')),
        body: Center(child: Text('Failed to load appointment\n$e')),
      ),
      data: (appt) => _buildScaffold(context, appt),
    );
  }

  Widget _buildScaffold(BuildContext context, Map<String, dynamic> appt) {
    final theme = Theme.of(context);
    final status = appt['status'] as String? ?? '';
    final doctor = appt['doctor'] as Map? ?? {};
    final clinic = appt['clinic'] as Map? ?? {};
    final canCancel = ['PENDING', 'CONFIRMED'].contains(status);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Appointment Details'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status banner
            _StatusBanner(status: status),
            const SizedBox(height: 20),

            // Doctor card
            _SectionCard(
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Text(
                      (doctor['name'] as String? ?? 'D').substring(0, 1),
                      style: AppTextStyles.headlineSmall.copyWith(color: theme.colorScheme.primary),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Dr. ${doctor['name'] ?? ''}', style: AppTextStyles.titleMedium),
                        if (_doctorSpecialty(doctor).isNotEmpty)
                          Text(_doctorSpecialty(doctor), style: AppTextStyles.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Date & Time
            _SectionCard(
              child: Column(
                children: [
                  _DetailRow(
                    icon: Icons.calendar_today_outlined,
                    label: 'Date',
                    value: _formatDate(appt['date'] as String? ?? ''),
                  ),
                  const Divider(height: 20),
                  _DetailRow(
                    icon: Icons.access_time_rounded,
                    label: 'Time',
                    value: '${appt['startTime'] ?? ''} – ${appt['endTime'] ?? ''}',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Clinic
            if (clinic.isNotEmpty)
              _SectionCard(
                child: _DetailRow(
                  icon: Icons.location_on_outlined,
                  label: 'Clinic',
                  value: '${clinic['name'] ?? ''}\n${clinic['addressLine1'] ?? ''}, ${clinic['city'] ?? ''}',
                ),
              ),

            if ((appt['notes'] as String?)?.isNotEmpty == true) ...[
              const SizedBox(height: 12),
              _SectionCard(
                child: _DetailRow(
                  icon: Icons.notes_rounded,
                  label: 'Notes',
                  value: appt['notes'] as String,
                ),
              ),
            ],

            const SizedBox(height: 32),

            // Cancel button
            if (canCancel)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _cancelling ? null : _confirmCancel,
                  icon: _cancelling
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cancel_outlined, color: AppColors.error),
                  label: Text(
                    _cancelling ? 'Cancelling…' : 'Cancel Appointment',
                    style: const TextStyle(color: AppColors.error),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.error),
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String raw) {
    if (raw.isEmpty) return '';
    final date = raw.length >= 10 ? raw.substring(0, 10) : raw;
    try {
      final parts = date.split('-');
      if (parts.length != 3) return date;
      final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      final month = int.tryParse(parts[1]) ?? 0;
      return '${parts[2]} ${month > 0 && month <= 12 ? months[month - 1] : parts[1]} ${parts[0]}';
    } catch (_) { return date; }
  }

  String _doctorSpecialty(Map doctor) {
    final cats = doctor['categories'] as List?;
    if (cats != null && cats.isNotEmpty) {
      return ((cats.first as Map)['category'] as Map?)?['name'] as String? ?? '';
    }
    return doctor['specialization'] as String? ?? '';
  }

  Future<void> _confirmCancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Appointment'),
        content: const Text('Are you sure you want to cancel this appointment?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, Cancel', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _cancelling = true);
    try {
      await ref
          .read(appointmentServiceProvider)
          .cancelAppointment(widget.appointmentId, 'Cancelled by patient');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Appointment cancelled')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to cancel: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (color, label, icon) = switch (status) {
      'CONFIRMED' => (AppColors.success, 'Confirmed', Icons.check_circle_outline),
      'PENDING' => (AppColors.warning, 'Pending', Icons.schedule),
      'CHECKED_IN' => (AppColors.info, 'Checked In', Icons.login_rounded),
      'IN_CONSULTATION' => (AppColors.primary, 'In Consultation', Icons.medical_services_outlined),
      'COMPLETED' => (AppColors.success, 'Completed', Icons.task_alt_rounded),
      'CANCELLED' => (AppColors.error, 'Cancelled', Icons.cancel_outlined),
      'NO_SHOW' => (AppColors.error, 'No Show', Icons.person_off_outlined),
      _ => (AppColors.textSecondaryLight, status, Icons.info_outline),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Text(label, style: AppTextStyles.titleSmall.copyWith(color: color)),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: child,
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondaryLight)),
              const SizedBox(height: 2),
              Text(value, style: AppTextStyles.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}
