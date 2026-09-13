import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';

// ── Providers ──────────────────────────────────────────────────────────────

final _medicalHistoryProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final response = await ref.watch(dioProvider).get('/users/me/medical-history');
  return List<Map<String, dynamic>>.from(response.data['data'] as List);
});

// ── Screen ─────────────────────────────────────────────────────────────────

class MedicalHistoryScreen extends ConsumerWidget {
  const MedicalHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordsAsync = ref.watch(_medicalHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Medical History'),
        actions: [
          Semantics(
            label: 'Add new medical record',
            child: IconButton(
              icon: const Icon(Icons.add_rounded),
              onPressed: () => _showAddDialog(context, ref),
              tooltip: 'Add record',
            ),
          ),
        ],
      ),
      body: recordsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 8),
              Text('Failed to load records', style: AppTextStyles.bodyMedium),
              TextButton(
                onPressed: () => ref.invalidate(_medicalHistoryProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (records) {
          if (records.isEmpty) {
            return _EmptyState(
              onAdd: () => _showAddDialog(context, ref),
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(_medicalHistoryProvider.future),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: records.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _MedicalRecordCard(
                record: records[i],
                onDelete: () => _deleteRecord(context, ref, records[i]['id'] as String),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDialog(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Record'),
      ),
    );
  }

  Future<void> _showAddDialog(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _AddRecordSheet(
        onSaved: () => ref.invalidate(_medicalHistoryProvider),
      ),
    );
  }

  Future<void> _deleteRecord(
      BuildContext context, WidgetRef ref, String recordId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete record?'),
        content:
            const Text('This record will be permanently removed from your history.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref
          .read(dioProvider)
          .delete('/users/me/medical-history/$recordId');
      ref.invalidate(_medicalHistoryProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Record deleted')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete record')),
        );
      }
    }
  }
}

// ── Record Card ────────────────────────────────────────────────────────────

class _MedicalRecordCard extends StatelessWidget {
  const _MedicalRecordCard({required this.record, required this.onDelete});
  final Map<String, dynamic> record;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final type = record['type'] as String? ?? 'NOTE';
    final date = record['date'] != null
        ? DateFormat('d MMM yyyy').format(DateTime.parse(record['date'] as String))
        : null;

    return Semantics(
      label: '${record['title']}, type: $type${date != null ? ', date: $date' : ''}',
      child: Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: _typeColor(type).withOpacity(0.15),
            child: Icon(_typeIcon(type), color: _typeColor(type), size: 20),
          ),
          title: Text(record['title'] as String? ?? '',
              style: AppTextStyles.titleSmall),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _typeColor(type).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      type.toLowerCase().replaceAll('_', ' '),
                      style: AppTextStyles.labelSmall
                          .copyWith(color: _typeColor(type)),
                    ),
                  ),
                  if (date != null) ...[
                    const SizedBox(width: 8),
                    Text(date, style: AppTextStyles.bodySmall),
                  ],
                ],
              ),
              if (record['details'] != null) ...[
                const SizedBox(height: 4),
                Text(record['details'] as String,
                    style: AppTextStyles.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ],
            ],
          ),
          isThreeLine: true,
          trailing: Semantics(
            label: 'Delete ${record['title']}',
            child: IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              color: AppColors.error.withOpacity(0.7),
              onPressed: onDelete,
            ),
          ),
        ),
      ),
    );
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'CONDITION': return Icons.monitor_heart_outlined;
      case 'ALLERGY': return Icons.warning_amber_outlined;
      case 'MEDICATION': return Icons.medication_outlined;
      case 'SURGERY': return Icons.healing_outlined;
      case 'VACCINATION': return Icons.vaccines_outlined;
      default: return Icons.note_alt_outlined;
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'CONDITION': return Colors.orange;
      case 'ALLERGY': return Colors.red;
      case 'MEDICATION': return Colors.blue;
      case 'SURGERY': return Colors.purple;
      case 'VACCINATION': return Colors.green;
      default: return Colors.grey;
    }
  }
}

// ── Add Record Sheet ───────────────────────────────────────────────────────

class _AddRecordSheet extends ConsumerStatefulWidget {
  const _AddRecordSheet({required this.onSaved});
  final VoidCallback onSaved;

  @override
  ConsumerState<_AddRecordSheet> createState() => _AddRecordSheetState();
}

class _AddRecordSheetState extends ConsumerState<_AddRecordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _detailsController = TextEditingController();
  String _type = 'CONDITION';
  DateTime? _date;
  bool _loading = false;

  static const _types = [
    ('CONDITION', 'Condition'),
    ('ALLERGY', 'Allergy'),
    ('MEDICATION', 'Medication'),
    ('SURGERY', 'Surgery'),
    ('VACCINATION', 'Vaccination'),
    ('NOTE', 'Note'),
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _detailsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Add Medical Record', style: AppTextStyles.titleMedium),
            const SizedBox(height: 20),

            // Type selector
            Text('Type', style: AppTextStyles.labelMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _types.map((t) {
                final selected = _type == t.$1;
                return Semantics(
                  label: '${t.$2} type${selected ? ', selected' : ''}',
                  child: ChoiceChip(
                    label: Text(t.$2),
                    selected: selected,
                    onSelected: (_) => setState(() => _type = t.$1),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Title
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title *',
                hintText: 'e.g. Diabetes Type 2',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Title is required' : null,
            ),
            const SizedBox(height: 16),

            // Date
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Date (optional)',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today_outlined),
                ),
                child: Text(
                  _date != null
                      ? DateFormat('d MMM yyyy').format(_date!)
                      : 'Select date',
                  style: AppTextStyles.bodyMedium,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Details
            TextFormField(
              controller: _detailsController,
              decoration: const InputDecoration(
                labelText: 'Details (optional)',
                hintText: 'Notes, dosage, severity…',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),

            AppButton(
              label: _loading ? 'Saving…' : 'Save Record',
              onPressed: _loading ? null : _save,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? DateTime.now(),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref.read(dioProvider).post('/users/me/medical-history', data: {
        'type': _type,
        'title': _titleController.text.trim(),
        'details': _detailsController.text.trim().isEmpty
            ? null
            : _detailsController.text.trim(),
        'date': _date?.toIso8601String().split('T').first,
      });
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save record')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

// ── Empty state ────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.medical_information_outlined,
                size: 80, color: AppColors.primary.withOpacity(0.4)),
            const SizedBox(height: 16),
            Text('No Medical Records',
                style: AppTextStyles.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'Keep track of your conditions, allergies, medications and more.',
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            AppButton(label: 'Add First Record', onPressed: onAdd),
          ],
        ),
      ),
    );
  }
}
