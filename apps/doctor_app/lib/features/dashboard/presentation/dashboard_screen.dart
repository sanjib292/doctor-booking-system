import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';

const _baseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'https://doctor-booking-system-production-2bf8.up.railway.app/api/v1');

final _dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(baseUrl: _baseUrl));
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (opts, handler) async {
      const storage = FlutterSecureStorage(
        aOptions: AndroidOptions(encryptedSharedPreferences: true),
      );
      final token = await storage.read(key: 'access_token');
      if (token != null) opts.headers['Authorization'] = 'Bearer $token';
      handler.next(opts);
    },
  ));
  return dio;
});

final _todayApptsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final now = DateTime.now();
  final date = '${now.year}-${now.month.toString().padLeft(2,'0')}-${now.day.toString().padLeft(2,'0')}';
  final response = await ref.watch(_dioProvider).get(
    '/appointments/doctor/list',
    queryParameters: {'date': date, 'limit': '50'},
  );
  return List<Map<String, dynamic>>.from(response.data['data'] as List);
});

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appts = ref.watch(_todayApptsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(_todayApptsProvider.future),
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              title: const Text("Today's Schedule"),
              floating: true,
              actions: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined),
                  onPressed: () {},
                ),
              ],
            ),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverToBoxAdapter(
                child: appts.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error: $e')),
                  data: (list) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Stats
                      Row(
                        children: [
                          _StatCard(
                            value: list.length.toString(),
                            label: 'Total Today',
                            icon: Icons.calendar_today_rounded,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          _StatCard(
                            value: list.where((a) => a['status'] == 'CONFIRMED').length.toString(),
                            label: 'Confirmed',
                            icon: Icons.check_circle_outline_rounded,
                            color: Colors.green,
                          ),
                          const SizedBox(width: 12),
                          _StatCard(
                            value: list.where((a) => a['status'] == 'COMPLETED').length.toString(),
                            label: 'Done',
                            icon: Icons.done_all_rounded,
                            color: Colors.teal,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text("Today's Appointments", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      if (list.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 48),
                            child: Column(
                              children: [
                                Icon(Icons.event_available_outlined, size: 64, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3)),
                                const SizedBox(height: 16),
                                const Text('No appointments today'),
                              ],
                            ),
                          ),
                        )
                      else
                        ...list.map((a) => _AppointmentTile(appointment: a)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.value, required this.label, required this.icon, required this.color});
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: color)),
            Text(label, style: TextStyle(fontSize: 11, color: color.withOpacity(0.8))),
          ],
        ),
      ),
    );
  }
}

class _AppointmentTile extends StatelessWidget {
  const _AppointmentTile({required this.appointment});
  final Map<String, dynamic> appointment;

  @override
  Widget build(BuildContext context) {
    final patient = appointment['patient'] as Map?;
    final status = appointment['status'] as String;

    final statusColor = switch (status) {
      'CONFIRMED' => Colors.blue,
      'CHECKED_IN' => Colors.orange,
      'IN_CONSULTATION' => Colors.purple,
      'COMPLETED' => Colors.green,
      'CANCELLED' => Colors.red,
      _ => Colors.grey,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: Text((patient?['name'] as String? ?? 'P').substring(0, 1)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(patient?['name'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                Text('${appointment['startTime']} — ${appointment['endTime']}', style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              status.replaceAll('_', ' '),
              style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
