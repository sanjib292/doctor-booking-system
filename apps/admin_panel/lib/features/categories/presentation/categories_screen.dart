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

final _categoriesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final response = await ref.watch(_dioProvider).get('/admin/categories');
  return List<Map<String, dynamic>>.from(response.data['data'] as List);
});

const _colorOptions = [
  '#4CAF50', '#2196F3', '#F44336', '#FF9800', '#9C27B0',
  '#00BCD4', '#FF5722', '#607D8B', '#795548', '#E91E63',
];

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(_categoriesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Categories',
                    style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
                const Spacer(),
                FilledButton.icon(
                  onPressed: () => _showCreateDialog(context, ref),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Category'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Manage doctor specialization categories shown in the patient app.',
                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey)),
            const SizedBox(height: 24),
            Expanded(
              child: categories.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Error: $e'),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () => ref.invalidate(_categoriesProvider),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
                data: (list) => list.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.category_outlined, size: 64, color: Colors.grey),
                            const SizedBox(height: 16),
                            Text('No categories yet', style: theme.textTheme.titleMedium),
                            const SizedBox(height: 8),
                            FilledButton.icon(
                              onPressed: () => _showCreateDialog(context, ref),
                              icon: const Icon(Icons.add),
                              label: const Text('Create First Category'),
                            ),
                          ],
                        ),
                      )
                    : Card(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('Color')),
                              DataColumn(label: Text('Name')),
                              DataColumn(label: Text('Slug')),
                              DataColumn(label: Text('Active')),
                              DataColumn(label: Text('Order')),
                              DataColumn(label: Text('Actions')),
                            ],
                            rows: list.map((cat) {
                              final colorHex = cat['color'] as String? ?? '#4CAF50';
                              final isActive = cat['isActive'] as bool? ?? true;
                              Color color;
                              try {
                                color = Color(int.parse(colorHex.replaceFirst('#', 'FF'), radix: 16));
                              } catch (_) {
                                color = Colors.blue;
                              }
                              return DataRow(cells: [
                                DataCell(
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: color,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                                DataCell(Text(cat['name'] as String? ?? '')),
                                DataCell(Text(cat['slug'] as String? ?? '',
                                    style: const TextStyle(fontSize: 12, color: Colors.grey))),
                                DataCell(
                                  Switch(
                                    value: isActive,
                                    onChanged: (v) => _toggleActive(context, ref, cat['id'] as String, v),
                                  ),
                                ),
                                DataCell(Text('${cat['sortOrder'] ?? 0}')),
                                DataCell(Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, size: 18),
                                      onPressed: () => _showEditDialog(context, ref, cat),
                                      tooltip: 'Edit',
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                      onPressed: () => _confirmDelete(context, ref, cat),
                                      tooltip: 'Delete',
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

  Future<void> _toggleActive(BuildContext context, WidgetRef ref, String id, bool active) async {
    try {
      await ref.read(_dioProvider).patch('/admin/categories/$id', data: {'isActive': active});
      ref.invalidate(_categoriesProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, Map<String, dynamic> cat) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text('Delete "${cat['name']}"? This will hide it from the patient app.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(_dioProvider).delete('/admin/categories/${cat['id']}');
      ref.invalidate(_categoriesProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Category deleted')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => _CategoryFormDialog(
        title: 'Add Category',
        onSave: (name, color, order) async {
          await ref.read(_dioProvider).post('/admin/categories', data: {
            'name': name,
            'color': color,
          });
          ref.invalidate(_categoriesProvider);
        },
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, Map<String, dynamic> cat) {
    showDialog(
      context: context,
      builder: (_) => _CategoryFormDialog(
        title: 'Edit Category',
        initialName: cat['name'] as String? ?? '',
        initialColor: cat['color'] as String? ?? _colorOptions.first,
        initialOrder: cat['sortOrder'] as int? ?? 0,
        onSave: (name, color, order) async {
          await ref.read(_dioProvider).patch('/admin/categories/${cat['id']}', data: {
            'name': name,
            'color': color,
            'sortOrder': order,
          });
          ref.invalidate(_categoriesProvider);
        },
      ),
    );
  }
}

class _CategoryFormDialog extends StatefulWidget {
  const _CategoryFormDialog({
    required this.title,
    required this.onSave,
    this.initialName = '',
    this.initialColor,
    this.initialOrder = 0,
  });

  final String title;
  final Future<void> Function(String name, String color, int order) onSave;
  final String initialName;
  final String? initialColor;
  final int initialOrder;

  @override
  State<_CategoryFormDialog> createState() => _CategoryFormDialogState();
}

class _CategoryFormDialogState extends State<_CategoryFormDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _orderCtrl;
  late String _selectedColor;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialName);
    _orderCtrl = TextEditingController(text: '${widget.initialOrder}');
    _selectedColor = widget.initialColor ?? _colorOptions.first;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _orderCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Name is required');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final order = int.tryParse(_orderCtrl.text.trim()) ?? 0;
      await widget.onSave(_nameCtrl.text.trim(), _selectedColor, order);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = 'Failed to save: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 400,
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
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Category Name *', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _orderCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Sort Order',
                hintText: '0 = first',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Color', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _colorOptions.map((hex) {
                Color color;
                try {
                  color = Color(int.parse(hex.replaceFirst('#', 'FF'), radix: 16));
                } catch (_) {
                  color = Colors.blue;
                }
                final isSelected = _selectedColor == hex;
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = hex),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(8),
                      border: isSelected ? Border.all(color: Colors.black, width: 2) : null,
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 18)
                        : null,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Save'),
        ),
      ],
    );
  }
}
