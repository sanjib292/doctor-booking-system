import 'package:dio/dio.dart';
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

final _doctorsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final response = await ref.watch(_dioProvider).get('/admin/doctors', queryParameters: {'limit': '50'});
  return List<Map<String, dynamic>>.from(response.data['data'] as List);
});

class DoctorsScreen extends ConsumerWidget {
  const DoctorsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doctors = ref.watch(_doctorsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Doctors', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
                const Spacer(),
                FilledButton.icon(
                  onPressed: () => _showCreateDoctorDialog(context, ref),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Doctor'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: doctors.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (list) => Card(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Name')),
                        DataColumn(label: Text('Email')),
                        DataColumn(label: Text('Status')),
                        DataColumn(label: Text('Rating')),
                        DataColumn(label: Text('Actions')),
                      ],
                      rows: list.map((doc) {
                        final status = doc['verificationStatus'] as String;
                        final isActive = doc['isActive'] as bool? ?? true;
                        return DataRow(cells: [
                          DataCell(Text(doc['name'] as String? ?? '')),
                          DataCell(Text(doc['email'] as String? ?? '')),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: status == 'VERIFIED' ? Colors.green.shade50 : Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(status, style: TextStyle(color: status == 'VERIFIED' ? Colors.green : Colors.orange, fontSize: 12)),
                            ),
                          ),
                          DataCell(Text('★ ${(doc['averageRating'] as num?)?.toStringAsFixed(1) ?? '0.0'}')),
                          DataCell(Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (status == 'PENDING')
                                TextButton(
                                  onPressed: () async {
                                    await ref.read(_dioProvider).patch('/admin/doctors/${doc['id']}/verify', data: {'status': 'VERIFIED'});
                                    ref.refresh(_doctorsProvider);
                                  },
                                  child: const Text('Verify'),
                                ),
                              TextButton(
                                onPressed: () async {
                                  await ref.read(_dioProvider).patch('/admin/doctors/${doc['id']}/toggle-active');
                                  ref.refresh(_doctorsProvider);
                                },
                                child: Text(isActive ? 'Deactivate' : 'Activate'),
                              ),
                            ],
                          )),
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

  void _showCreateDoctorDialog(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final passCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Doctor'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Full Name')),
              const SizedBox(height: 12),
              TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email')),
              const SizedBox(height: 12),
              TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone')),
              const SizedBox(height: 12),
              TextField(controller: passCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Temporary Password')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              await ref.read(_dioProvider).post('/admin/doctors', data: {
                'name': nameCtrl.text.trim(),
                'email': emailCtrl.text.trim(),
                'phone': phoneCtrl.text.trim(),
                'password': passCtrl.text,
              });
              ref.refresh(_doctorsProvider);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}
