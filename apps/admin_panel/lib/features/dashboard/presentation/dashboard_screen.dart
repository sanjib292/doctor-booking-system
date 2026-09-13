import 'package:dio/dio.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _baseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'https://doctor-booking-system-production-2bf8.up.railway.app/api/v1');

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

final _statsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final response = await ref.watch(_dioProvider).get('/admin/dashboard');
  return response.data['data'] as Map<String, dynamic>;
});

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(_statsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: statsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (stats) => SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Dashboard', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 24),

              // KPI Cards
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _KpiCard(title: 'Total Users', value: stats['totalUsers'].toString(), icon: Icons.people_outline, color: Colors.blue),
                  _KpiCard(title: 'Total Doctors', value: stats['totalDoctors'].toString(), icon: Icons.medical_services_outlined, color: Colors.green),
                  _KpiCard(title: 'Total Appointments', value: stats['totalAppointments'].toString(), icon: Icons.calendar_today_outlined, color: Colors.purple),
                  _KpiCard(title: 'Today\'s Appointments', value: stats['todayAppointments'].toString(), icon: Icons.today_outlined, color: Colors.orange),
                  _KpiCard(title: 'Active Clinics', value: stats['totalClinics'].toString(), icon: Icons.location_city_outlined, color: Colors.teal),
                  _KpiCard(title: 'Pending Verifications', value: stats['pendingVerifications'].toString(), icon: Icons.verified_outlined, color: Colors.red),
                ],
              ),

              const SizedBox(height: 32),

              // Appointments by status chart
              Text('Appointments by Status', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: SizedBox(
                    height: 260,
                    child: _AppointmentStatusChart(
                      data: (stats['appointmentsByStatus'] as List?) ?? [],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Recent appointments
              Text('Recent Appointments', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              Card(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Patient')),
                      DataColumn(label: Text('Doctor')),
                      DataColumn(label: Text('Status')),
                    ],
                    rows: ((stats['recentAppointments'] as List?) ?? []).map((a) {
                      final appt = a as Map;
                      return DataRow(cells: [
                        DataCell(Text((appt['patient'] as Map?)?['name'] as String? ?? '')),
                        DataCell(Text((appt['doctor'] as Map?)?['name'] as String? ?? '')),
                        DataCell(Text(appt['status'] as String? ?? '')),
                      ]);
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.title, required this.value, required this.icon, required this.color});
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 12),
              Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: color)),
              const SizedBox(height: 4),
              Text(title, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppointmentStatusChart extends StatelessWidget {
  const _AppointmentStatusChart({required this.data});
  final List data;

  static const _colors = [
    Colors.blue, Colors.green, Colors.orange, Colors.red, Colors.purple, Colors.teal, Colors.amber,
  ];

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const Center(child: Text('No data'));

    return PieChart(
      PieChartData(
        sections: List.generate(data.length, (i) {
          final item = data[i] as Map;
          final count = (item['_count'] as num?)?.toDouble() ?? 0;
          return PieChartSectionData(
            value: count,
            title: '${item['status']}\n${count.toInt()}',
            color: _colors[i % _colors.length],
            radius: 100,
            titleStyle: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600),
          );
        }),
        centerSpaceRadius: 40,
        sectionsSpace: 2,
      ),
    );
  }
}
