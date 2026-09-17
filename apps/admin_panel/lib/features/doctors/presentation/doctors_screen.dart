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
                        DataColumn(label: Text('Specialization')),
                        DataColumn(label: Text('Exp')),
                        DataColumn(label: Text('Status')),
                        DataColumn(label: Text('Rating')),
                        DataColumn(label: Text('Actions')),
                      ],
                      rows: list.map((doc) {
                        final status = doc['verificationStatus'] as String;
                        final isActive = doc['isActive'] as bool? ?? true;
                        final specialty = _specialty(doc);
                        final expYears = doc['experienceYears'] as int? ?? 0;
                        return DataRow(cells: [
                          DataCell(Text(doc['name'] as String? ?? '')),
                          DataCell(Text(doc['email'] as String? ?? '')),
                          DataCell(Text(specialty.isEmpty ? '—' : specialty)),
                          DataCell(Text(expYears > 0 ? '${expYears}yr' : '—')),
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
                                    ref.invalidate(_doctorsProvider);
                                  },
                                  child: const Text('Verify'),
                                ),
                              TextButton(
                                onPressed: () async {
                                  await ref.read(_dioProvider).patch('/admin/doctors/${doc['id']}/toggle-active');
                                  ref.invalidate(_doctorsProvider);
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

  String _specialty(Map<String, dynamic> doc) {
    final cats = doc['categories'] as List?;
    if (cats == null || cats.isEmpty) return '';
    return ((cats.first as Map)['category'] as Map?)?['name'] as String? ?? '';
  }

  void _showCreateDoctorDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => _CreateDoctorDialog(
        onCreated: () => ref.invalidate(_doctorsProvider),
        dioProvider: _dioProvider,
      ),
    );
  }
}

class _CreateDoctorDialog extends ConsumerStatefulWidget {
  const _CreateDoctorDialog({required this.onCreated, required this.dioProvider});
  final VoidCallback onCreated;
  final Provider<Dio> dioProvider;

  @override
  ConsumerState<_CreateDoctorDialog> createState() => _CreateDoctorDialogState();
}

class _CreateDoctorDialogState extends ConsumerState<_CreateDoctorDialog> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _qualCtrl = TextEditingController();
  final _expCtrl = TextEditingController();
  String? _gender;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose(); _emailCtrl.dispose(); _phoneCtrl.dispose();
    _passCtrl.dispose(); _qualCtrl.dispose(); _expCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty || _emailCtrl.text.trim().isEmpty ||
        _passCtrl.text.isEmpty) {
      setState(() => _error = 'Name, email, and password are required');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final quals = _qualCtrl.text.trim().isEmpty
          ? <String>[]
          : _qualCtrl.text.split(',').map((q) => q.trim()).where((q) => q.isNotEmpty).toList();
      final expYears = int.tryParse(_expCtrl.text.trim()) ?? 0;
      await ref.read(widget.dioProvider).post('/admin/doctors', data: {
        'name': _nameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'password': _passCtrl.text,
        if (quals.isNotEmpty) 'qualifications': quals,
        if (expYears > 0) 'experienceYears': expYears,
        if (_gender != null) 'gender': _gender,
      });
      widget.onCreated();
      if (mounted) Navigator.pop(context);
    } on DioException catch (e) {
      setState(() => _error = (e.response?.data?['error']?['message'] as String?) ?? 'Failed to create doctor');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Doctor'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_error != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                  child: Text(_error!, style: TextStyle(color: Colors.red.shade700, fontSize: 13)),
                ),
                const SizedBox(height: 12),
              ],
              const Text('Basic Info', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 8),
              TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Full Name *', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: _emailCtrl, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email *', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: _phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone (with country code)', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: _passCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Temporary Password *', border: OutlineInputBorder())),
              const SizedBox(height: 16),
              const Text('Professional Details', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 8),
              TextField(
                controller: _qualCtrl,
                decoration: const InputDecoration(
                  labelText: 'Qualifications (comma-separated)',
                  hintText: 'MBBS, MD, MS',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _expCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Experience (years)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _gender,
                decoration: const InputDecoration(labelText: 'Gender', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'MALE', child: Text('Male')),
                  DropdownMenuItem(value: 'FEMALE', child: Text('Female')),
                  DropdownMenuItem(value: 'OTHER', child: Text('Other')),
                ],
                onChanged: (v) => setState(() => _gender = v),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Create'),
        ),
      ],
    );
  }
}
