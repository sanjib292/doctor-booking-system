import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

String _today() {
  final n = DateTime.now();
  return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
}

// Upcoming: future CONFIRMED appointments
final _upcomingProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/appointments/doctor/list', queryParameters: {
    'status': 'CONFIRMED',
    'limit': '50',
  });
  final all = List<Map<String, dynamic>>.from(response.data['data'] as List);
  final today = _today();
  return all.where((a) {
    final d = a['date'] as String? ?? '';
    final dateStr = d.length >= 10 ? d.substring(0, 10) : d;
    return dateStr.compareTo(today) >= 0;
  }).toList();
});

// Today: all appointments for today's date
final _todayProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/appointments/doctor/list', queryParameters: {
    'date': _today(),
    'limit': '50',
  });
  return List<Map<String, dynamic>>.from(response.data['data'] as List);
});

// History: past COMPLETED or CANCELLED
final _historyProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final dio = ref.watch(dioProvider);
  final [completedRes, cancelledRes] = await Future.wait([
    dio.get('/appointments/doctor/list',
        queryParameters: {'status': 'COMPLETED', 'limit': '50'}),
    dio.get('/appointments/doctor/list',
        queryParameters: {'status': 'CANCELLED', 'limit': '50'}),
  ]);
  final combined = [
    ...List<Map<String, dynamic>>.from(completedRes.data['data'] as List),
    ...List<Map<String, dynamic>>.from(cancelledRes.data['data'] as List),
  ];
  final today = _today();
  combined.sort((a, b) {
    final da = (a['date'] as String? ?? '').substring(0, 10);
    final db = (b['date'] as String? ?? '').substring(0, 10);
    return db.compareTo(da);
  });
  return combined.where((a) {
    final d = a['date'] as String? ?? '';
    final dateStr = d.length >= 10 ? d.substring(0, 10) : d;
    return dateStr.compareTo(today) <= 0;
  }).toList();
});

class AppointmentsScreen extends ConsumerWidget {
  const AppointmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Appointments'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Upcoming'),
              Tab(text: 'Today'),
              Tab(text: 'History'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _AppointmentList(provider: _upcomingProvider, emptyLabel: 'No upcoming appointments', ref: ref),
            _AppointmentList(provider: _todayProvider, emptyLabel: 'No appointments today', ref: ref, showUpdateStatus: true),
            _AppointmentList(provider: _historyProvider, emptyLabel: 'No appointment history', ref: ref),
          ],
        ),
      ),
    );
  }
}

class _AppointmentList extends ConsumerWidget {
  const _AppointmentList({
    required this.provider,
    required this.emptyLabel,
    required this.ref,
    this.showUpdateStatus = false,
  });

  final ProviderListenable<AsyncValue<List<Map<String, dynamic>>>> provider;
  final String emptyLabel;
  final WidgetRef ref;
  final bool showUpdateStatus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(provider);
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(_upcomingProvider);
        ref.invalidate(_todayProvider);
        ref.invalidate(_historyProvider);
      },
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text('$e', textAlign: TextAlign.center),
            ],
          ),
        ),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.event_available_outlined, size: 64, color: Colors.grey),
                  const SizedBox(height: 12),
                  Text(emptyLabel, style: const TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            itemBuilder: (_, i) => _AppointmentCard(
              appt: list[i],
              showUpdateStatus: showUpdateStatus,
              onStatusUpdated: () {
                ref.invalidate(_upcomingProvider);
                ref.invalidate(_todayProvider);
                ref.invalidate(_historyProvider);
              },
            ),
          );
        },
      ),
    );
  }
}

class _AppointmentCard extends ConsumerWidget {
  const _AppointmentCard({
    required this.appt,
    required this.showUpdateStatus,
    required this.onStatusUpdated,
  });

  final Map<String, dynamic> appt;
  final bool showUpdateStatus;
  final VoidCallback onStatusUpdated;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patient = appt['patient'] as Map? ?? {};
    final clinic = appt['clinic'] as Map? ?? {};
    final status = appt['status'] as String? ?? '';
    final date = (appt['date'] as String? ?? '').length >= 10
        ? (appt['date'] as String).substring(0, 10)
        : appt['date'] as String? ?? '';

    final statusColor = switch (status) {
      'CONFIRMED' => Colors.blue,
      'CHECKED_IN' => Colors.orange,
      'IN_CONSULTATION' => Colors.purple,
      'COMPLETED' => Colors.green,
      'CANCELLED' => Colors.red,
      'NO_SHOW' => Colors.grey,
      _ => Colors.grey,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  child: Text(
                    (patient['name'] as String? ?? 'P').substring(0, 1).toUpperCase(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patient['name'] as String? ?? '—',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                      if ((patient['phone'] as String?) != null)
                        Text(patient['phone'] as String,
                            style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    status.replaceAll('_', ' '),
                    style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(date, style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 12),
                const Icon(Icons.access_time_outlined, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  '${appt['startTime']} — ${appt['endTime']}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            if ((clinic['name'] as String?) != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(clinic['name'] as String, style: const TextStyle(fontSize: 12)),
                ],
              ),
            ],
            if (showUpdateStatus &&
                (status == 'CONFIRMED' ||
                    status == 'CHECKED_IN' ||
                    status == 'IN_CONSULTATION')) ...[
              const SizedBox(height: 10),
              _StatusActions(
                apptId: appt['id'] as String,
                currentStatus: status,
                onUpdated: onStatusUpdated,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusActions extends ConsumerStatefulWidget {
  const _StatusActions({
    required this.apptId,
    required this.currentStatus,
    required this.onUpdated,
  });

  final String apptId;
  final String currentStatus;
  final VoidCallback onUpdated;

  @override
  ConsumerState<_StatusActions> createState() => _StatusActionsState();
}

class _StatusActionsState extends ConsumerState<_StatusActions> {
  bool _loading = false;

  Future<void> _updateStatus(String newStatus) async {
    setState(() => _loading = true);
    try {
      final dio = ref.read(dioProvider);
      await dio.patch('/appointments/${widget.apptId}/status',
          data: {'status': newStatus});
      widget.onUpdated();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(strokeWidth: 2));

    return Wrap(
      spacing: 8,
      children: [
        if (widget.currentStatus == 'CONFIRMED')
          OutlinedButton.icon(
            onPressed: () => _updateStatus('CHECKED_IN'),
            icon: const Icon(Icons.login_rounded, size: 16),
            label: const Text('Check In'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.orange,
              side: const BorderSide(color: Colors.orange),
              visualDensity: VisualDensity.compact,
            ),
          ),
        if (widget.currentStatus == 'CHECKED_IN')
          OutlinedButton.icon(
            onPressed: () => _updateStatus('IN_CONSULTATION'),
            icon: const Icon(Icons.medical_services_outlined, size: 16),
            label: const Text('Start'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.purple,
              side: const BorderSide(color: Colors.purple),
              visualDensity: VisualDensity.compact,
            ),
          ),
        if (widget.currentStatus == 'IN_CONSULTATION')
          FilledButton.icon(
            onPressed: () => _updateStatus('COMPLETED'),
            icon: const Icon(Icons.done_rounded, size: 16),
            label: const Text('Complete'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.green,
              visualDensity: VisualDensity.compact,
            ),
          ),
        if (widget.currentStatus == 'CONFIRMED' ||
            widget.currentStatus == 'CHECKED_IN')
          OutlinedButton.icon(
            onPressed: () => _updateStatus('NO_SHOW'),
            icon: const Icon(Icons.person_off_outlined, size: 16),
            label: const Text('No Show'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.grey,
              side: const BorderSide(color: Colors.grey),
              visualDensity: VisualDensity.compact,
            ),
          ),
      ],
    );
  }
}
