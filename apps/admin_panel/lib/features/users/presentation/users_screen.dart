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

final _usersProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final response = await ref
      .watch(_dioProvider)
      .get('/admin/users', queryParameters: {'limit': '100'});
  return List<Map<String, dynamic>>.from(response.data['data'] as List);
});

class UsersScreen extends ConsumerStatefulWidget {
  const UsersScreen({super.key});

  @override
  ConsumerState<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends ConsumerState<UsersScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(_usersProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Patients',
                    style: theme.textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const Spacer(),
                SizedBox(
                  width: 240,
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search by name, phone…',
                      prefixIcon: Icon(Icons.search_rounded),
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() => _search = v.toLowerCase()),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: () => ref.invalidate(_usersProvider),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: usersAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (list) {
                  final filtered = _search.isEmpty
                      ? list
                      : list.where((u) {
                          final name =
                              (u['name'] as String? ?? '').toLowerCase();
                          final phone =
                              (u['phone'] as String? ?? '').toLowerCase();
                          final email =
                              (u['email'] as String? ?? '').toLowerCase();
                          return name.contains(_search) ||
                              phone.contains(_search) ||
                              email.contains(_search);
                        }).toList();
                  return Card(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Name')),
                          DataColumn(label: Text('Phone')),
                          DataColumn(label: Text('Email')),
                          DataColumn(label: Text('Status')),
                          DataColumn(label: Text('Actions')),
                        ],
                        rows: filtered.map((u) {
                          final isBlocked = u['isBlocked'] as bool? ?? false;
                          return DataRow(cells: [
                            DataCell(Text(u['name'] as String? ?? '—')),
                            DataCell(Text(u['phone'] as String? ?? '—')),
                            DataCell(Text(u['email'] as String? ?? '—')),
                            DataCell(
                              Text(
                                isBlocked ? 'Blocked' : 'Active',
                                style: TextStyle(
                                  color: isBlocked ? Colors.red : Colors.green,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            DataCell(
                              TextButton(
                                onPressed: () => _toggleBlock(
                                    context, u['id'] as String, isBlocked),
                                child: Text(isBlocked ? 'Unblock' : 'Block',
                                    style: TextStyle(
                                        color: isBlocked
                                            ? Colors.green
                                            : Colors.red)),
                              ),
                            ),
                          ]);
                        }).toList(),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleBlock(
      BuildContext context, String userId, bool currentlyBlocked) async {
    try {
      await ref
          .read(_dioProvider)
          .patch('/admin/users/$userId/toggle-block');
      ref.invalidate(_usersProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(currentlyBlocked
                  ? 'User unblocked'
                  : 'User blocked')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}
