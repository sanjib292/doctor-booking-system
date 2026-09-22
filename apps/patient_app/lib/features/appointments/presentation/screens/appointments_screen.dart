import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/skeleton_loader.dart';
import '../providers/appointments_provider.dart';

class AppointmentsScreen extends ConsumerStatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  ConsumerState<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends ConsumerState<AppointmentsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const _tabs = [
    ('Upcoming', 'CONFIRMED,PENDING,CHECKED_IN,IN_CONSULTATION'),
    ('Completed', 'COMPLETED'),
    ('Cancelled', 'CANCELLED,NO_SHOW'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Appointments'),
        bottom: TabBar(
          controller: _tabController,
          tabs: _tabs.map((t) => Tab(text: t.$1)).toList(),
          labelStyle: AppTextStyles.labelMedium.copyWith(fontWeight: FontWeight.w600),
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _tabs.map((t) => _AppointmentList(status: t.$2)).toList(),
      ),
    );
  }
}

class _AppointmentList extends ConsumerWidget {
  const _AppointmentList({required this.status});
  final String status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appointments = ref.watch(patientAppointmentsProvider(status));

    return RefreshIndicator(
      onRefresh: () => ref.refresh(patientAppointmentsProvider(status).future),
      child: appointments.when(
        loading: () => ListView.builder(
          itemCount: 4,
          itemBuilder: (_, __) => const Padding(
            padding: EdgeInsets.all(16),
            child: DoctorCardSkeleton(),
          ),
        ),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) => list.isEmpty
            ? _EmptyAppointments(status: status)
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                itemBuilder: (_, i) => _AppointmentCard(
                  appointment: list[i],
                  onTap: () => context.pushNamed(
                    'appointmentDetail',
                    pathParameters: {'id': list[i]['id'] as String},
                    extra: list[i],
                  ),
                ),
              ),
      ),
    );
  }
}

String _countdownText(Map<String, dynamic> appointment) {
  final status = appointment['status'] as String;
  if (!['CONFIRMED', 'PENDING'].contains(status)) return '';
  try {
    final dateStr = (appointment['date'] as String? ?? '').substring(0, 10);
    final timeStr = appointment['startTime'] as String? ?? '00:00';
    final parts = timeStr.split(':');
    final apptDt = DateTime.parse('${dateStr}T${parts[0].padLeft(2, '0')}:${parts.length > 1 ? parts[1].padLeft(2, '0') : '00'}:00');
    final diff = apptDt.difference(DateTime.now());
    if (diff.isNegative) return '';
    final d = diff.inDays;
    final h = diff.inHours % 24;
    final m = diff.inMinutes % 60;
    if (d > 0) return 'in ${d}d ${h}h ${m}m';
    if (h > 0) return 'in ${h}h ${m}m';
    if (m > 0) return 'in ${m}m';
    return 'Starting soon';
  } catch (_) {
    return '';
  }
}

class _AppointmentCard extends StatefulWidget {
  const _AppointmentCard({required this.appointment, required this.onTap});
  final Map<String, dynamic> appointment;
  final VoidCallback onTap;

  @override
  State<_AppointmentCard> createState() => _AppointmentCardState();
}

class _AppointmentCardState extends State<_AppointmentCard> {
  Timer? _timer;
  String _countdown = '';

  @override
  void initState() {
    super.initState();
    _countdown = _countdownText(widget.appointment);
    if (_countdown.isNotEmpty) {
      _timer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (mounted) setState(() => _countdown = _countdownText(widget.appointment));
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appointment = widget.appointment;
    final theme = Theme.of(context);
    final status = appointment['status'] as String;
    final doctor = appointment['doctor'] as Map?;
    final clinic = appointment['clinic'] as Map?;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primaryContainer,
                  child: Text(
                    (doctor?['name'] as String? ?? 'D').substring(0, 1),
                    style: AppTextStyles.titleSmall.copyWith(color: AppColors.primary),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Dr. ${doctor?['name'] ?? ''}', style: AppTextStyles.titleSmall),
                      Text(clinic?['name'] as String? ?? '', style: AppTextStyles.bodySmall),
                    ],
                  ),
                ),
                _StatusBadge(status: status),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${appointment['date'] as String? ?? ''} at ${appointment['startTime'] as String? ?? ''}',
                    style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w500),
                  ),
                ),
                if (_countdown.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.timer_outlined, size: 12, color: AppColors.primary),
                        const SizedBox(width: 3),
                        Text(_countdown, style: AppTextStyles.labelSmall.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                const Icon(Icons.chevron_right_rounded, size: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      'CONFIRMED' => (AppColors.success, 'Confirmed'),
      'PENDING' => (AppColors.warning, 'Pending'),
      'CHECKED_IN' => (AppColors.info, 'Checked In'),
      'IN_CONSULTATION' => (AppColors.primary, 'In Progress'),
      'COMPLETED' => (AppColors.success, 'Completed'),
      'CANCELLED' => (AppColors.error, 'Cancelled'),
      'NO_SHOW' => (AppColors.error, 'No Show'),
      _ => (AppColors.textSecondaryLight, status),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _EmptyAppointments extends StatelessWidget {
  const _EmptyAppointments({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.calendar_month_outlined,
            size: 80,
            color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text('No appointments here', style: AppTextStyles.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Book your first appointment today',
            style: AppTextStyles.bodyMedium.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
