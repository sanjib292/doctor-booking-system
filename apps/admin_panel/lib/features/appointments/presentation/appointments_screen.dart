import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _baseUrl = String.fromEnvironment('API_BASE_URL',
    defaultValue: 'https://doctor-booking-system-production-2bf8.up.railway.app/api/v1');

final _dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(baseUrl: _baseUrl));
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (opts, handler) async {
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: 'access_token');
      if (token != null) opts.headers['Authorization'] = 'Bearer $token';
      handler.next(opts);
    },
  ));
  return dio;
});

final _appointmentsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final response = await ref
      .watch(_dioProvider)
      .get('/admin/appointments', queryParameters: {'limit': '50'});
  return List<Map<String, dynamic>>.from(response.data['data'] as List);
});

class AdminAppointmentsScreen extends ConsumerWidget {
  const AdminAppointmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appts = ref.watch(_appointmentsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Appointments',
                    style: theme.textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: () => ref.invalidate(_appointmentsProvider),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: appts.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (list) => Card(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Patient')),
                        DataColumn(label: Text('Doctor')),
                        DataColumn(label: Text('Date')),
                        DataColumn(label: Text('Time')),
                        DataColumn(label: Text('Status')),
                        DataColumn(label: Text('Actions')),
                      ],
                      rows: list.map((a) {
                        final patient =
                            a['patient'] as Map<String, dynamic>? ?? {};
                        final doctor =
                            a['doctor'] as Map<String, dynamic>? ?? {};
                        final status = a['status'] as String? ?? '';
                        final isCancellable = status == 'CONFIRMED' ||
                            status == 'PENDING';
                        return DataRow(cells: [
                          DataCell(Text(patient['name'] as String? ?? '—')),
                          DataCell(Text(doctor['name'] as String? ?? '—')),
                          DataCell(Text(a['date'] as String? ?? '—')),
                          DataCell(Text(a['startTime'] as String? ?? '—')),
                          DataCell(_StatusChip(status: status)),
                          DataCell(isCancellable
                              ? TextButton(
                                  onPressed: () =>
                                      _cancelAppointment(context, ref, a['id'] as String),
                                  child: const Text('Cancel',
                                      style: TextStyle(color: Colors.red)),
                                )
                              : const Text('—')),
                        ]);
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _cancelAppointment(
      BuildContext context, WidgetRef ref, String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel Appointment'),
        content: const Text('Are you sure you want to cancel this appointment?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child:
                  const Text('Yes', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ref
          .read(_dioProvider)
          .post('/appointments/$id/cancel',
              data: {'reason': 'Cancelled by admin'});
      ref.invalidate(_appointmentsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Appointment cancelled')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'CONFIRMED' => Colors.green,
      'PENDING' => Colors.orange,
      'CANCELLED' => Colors.red,
      'COMPLETED' => Colors.blue,
      'NO_SHOW' => Colors.grey,
      _ => Colors.purple,
    };
    return Chip(
      label: Text(status,
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      backgroundColor: color.withOpacity(0.1),
      side: BorderSide(color: color.withOpacity(0.3)),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }
}
