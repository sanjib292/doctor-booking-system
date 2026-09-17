import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

final _clinicsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final response = await ref
      .watch(_dioProvider)
      .get('/admin/clinics', queryParameters: {'limit': '100'});
  return List<Map<String, dynamic>>.from(response.data['data'] as List);
});

class ClinicsScreen extends ConsumerWidget {
  const ClinicsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clinicsAsync = ref.watch(_clinicsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Clinics',
                    style: theme.textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const Spacer(),
                FilledButton.icon(
                  onPressed: () => _showClinicDialog(context, ref),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Clinic'),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: () => ref.invalidate(_clinicsProvider),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: clinicsAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (list) => Card(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Name')),
                        DataColumn(label: Text('City')),
                        DataColumn(label: Text('Address')),
                        DataColumn(label: Text('Phone')),
                        DataColumn(label: Text('Actions')),
                      ],
                      rows: list.map((c) => DataRow(cells: [
                            DataCell(Text(c['name'] as String? ?? '—')),
                            DataCell(Text(c['city'] as String? ?? '—')),
                            DataCell(Text(c['addressLine1'] as String? ?? '—')),
                            DataCell(Text(c['phone'] as String? ?? '—')),
                            DataCell(Row(children: [
                              TextButton(
                                  onPressed: () =>
                                      _showClinicDialog(context, ref, clinic: c),
                                  child: const Text('Edit')),
                            ])),
                          ])).toList(),
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

  void _showClinicDialog(BuildContext context, WidgetRef ref,
      {Map<String, dynamic>? clinic}) {
    final isEdit = clinic != null;
    final nameCtrl =
        TextEditingController(text: clinic?['name'] as String? ?? '');
    final addressCtrl =
        TextEditingController(text: clinic?['addressLine1'] as String? ?? '');
    final cityCtrl =
        TextEditingController(text: clinic?['city'] as String? ?? '');
    final stateCtrl =
        TextEditingController(text: clinic?['state'] as String? ?? '');
    final phoneCtrl =
        TextEditingController(text: clinic?['phone'] as String? ?? '');
    final latCtrl = TextEditingController(
        text: clinic?['lat']?.toString() ?? '');
    final lngCtrl = TextEditingController(
        text: clinic?['lng']?.toString() ?? '');
    final formKey = GlobalKey<FormState>();
    bool loading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(isEdit ? 'Edit Clinic' : 'Add Clinic'),
          content: SizedBox(
            width: 480,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Name *'),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Required' : null,
                    ),
                    TextFormField(
                      controller: addressCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Address *'),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Required' : null,
                    ),
                    TextFormField(
                      controller: cityCtrl,
                      decoration: const InputDecoration(labelText: 'City *'),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Required' : null,
                    ),
                    TextFormField(
                      controller: stateCtrl,
                      decoration: const InputDecoration(labelText: 'State *'),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Required' : null,
                    ),
                    TextFormField(
                      controller: phoneCtrl,
                      decoration: const InputDecoration(labelText: 'Phone'),
                      keyboardType: TextInputType.phone,
                    ),
                    Row(children: [
                      Expanded(
                        child: TextFormField(
                          controller: latCtrl,
                          decoration: const InputDecoration(labelText: 'Lat *'),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[-0-9.]'))],
                          validator: (v) =>
                              v == null || v.isEmpty ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: lngCtrl,
                          decoration: const InputDecoration(labelText: 'Lng *'),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[-0-9.]'))],
                          validator: (v) =>
                              v == null || v.isEmpty ? 'Required' : null,
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: loading
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setState(() => loading = true);
                      try {
                        final body = {
                          'name': nameCtrl.text.trim(),
                          'addressLine1': addressCtrl.text.trim(),
                          'city': cityCtrl.text.trim(),
                          'state': stateCtrl.text.trim(),
                          'lat': double.parse(latCtrl.text.trim()),
                          'lng': double.parse(lngCtrl.text.trim()),
                          if (phoneCtrl.text.isNotEmpty)
                            'phone': phoneCtrl.text.trim(),
                        };
                        if (isEdit) {
                          await ref
                              .read(_dioProvider)
                              .patch('/admin/clinics/${clinic!['id']}',
                                  data: body);
                        } else {
                          await ref
                              .read(_dioProvider)
                              .post('/admin/clinics', data: body);
                        }
                        ref.invalidate(_clinicsProvider);
                        if (ctx.mounted) Navigator.pop(ctx);
                      } catch (e) {
                        setState(() => loading = false);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: Text('Error: $e')));
                        }
                      }
                    },
              child: Text(isEdit ? 'Save' : 'Create'),
            ),
          ],
        ),
      ),
    );
  }
}
