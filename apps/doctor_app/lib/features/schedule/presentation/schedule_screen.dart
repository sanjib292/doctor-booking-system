import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

final _availabilityProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final response =
      await ref.watch(dioProvider).get('/doctors/me/availability');
  return List<Map<String, dynamic>>.from(response.data['data'] as List);
});

const _dayOrder = [
  'MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY', 'SUNDAY'
];
const _dayLabels = {
  'MONDAY': 'Monday',
  'TUESDAY': 'Tuesday',
  'WEDNESDAY': 'Wednesday',
  'THURSDAY': 'Thursday',
  'FRIDAY': 'Friday',
  'SATURDAY': 'Saturday',
  'SUNDAY': 'Sunday',
};

class ScheduleScreen extends ConsumerWidget {
  const ScheduleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(_availabilityProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Schedule'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(_availabilityProvider),
          ),
        ],
      ),
      body: asyncData.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text('Failed to load schedule\n$e', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.invalidate(_availabilityProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (list) {
          final sorted = [...list]..sort((a, b) =>
              _dayOrder.indexOf(a['dayOfWeek'] as String).compareTo(
                  _dayOrder.indexOf(b['dayOfWeek'] as String)));

          return _ScheduleBody(availability: sorted, onRefresh: () => ref.invalidate(_availabilityProvider));
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDaySheet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add Working Day'),
      ),
    );
  }

  void _showAddDaySheet(BuildContext context, WidgetRef ref) {
    // collect days already configured
    final existing = ref.read(_availabilityProvider).valueOrNull ?? [];
    final existingDays = existing.map((e) => e['dayOfWeek'] as String).toSet();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _AddDaySheet(
        existingDays: existingDays,
        onSaved: () => ref.invalidate(_availabilityProvider),
      ),
    );
  }
}

class _ScheduleBody extends ConsumerWidget {
  const _ScheduleBody({required this.availability, required this.onRefresh});
  final List<Map<String, dynamic>> availability;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (availability.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.schedule_outlined, size: 80,
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.4)),
              const SizedBox(height: 16),
              Text('No working hours set',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              const Text(
                'Tap "Add Working Day" below to configure\nyour weekly schedule.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: availability.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final a = availability[i];
        return _DayCard(data: a, onDeleted: onRefresh, onEdited: onRefresh);
      },
    );
  }
}

class _DayCard extends ConsumerStatefulWidget {
  const _DayCard({required this.data, required this.onDeleted, required this.onEdited});
  final Map<String, dynamic> data;
  final VoidCallback onDeleted;
  final VoidCallback onEdited;

  @override
  ConsumerState<_DayCard> createState() => _DayCardState();
}

class _DayCardState extends ConsumerState<_DayCard> {
  bool _deleting = false;

  Future<void> _delete() async {
    final day = widget.data['dayOfWeek'] as String;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Remove ${_dayLabels[day] ?? day}?'),
        content: const Text('This will remove working hours for this day.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _deleting = true);
    try {
      await ref.read(dioProvider).delete('/doctors/me/availability/$day');
      widget.onDeleted();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  void _edit() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _AddDaySheet(
        existingDays: const {},
        initialData: widget.data,
        onSaved: widget.onEdited,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final day = widget.data['dayOfWeek'] as String;
    final isActive = widget.data['isActive'] as bool? ?? true;
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: isActive
                    ? theme.colorScheme.primary.withOpacity(0.1)
                    : Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.calendar_today_outlined, size: 20,
                  color: isActive ? theme.colorScheme.primary : Colors.grey),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _dayLabels[day] ?? day,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${widget.data['startTime']} – ${widget.data['endTime']}  ·  ${widget.data['slotDurationMinutes']} min slots',
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                  ),
                ],
              ),
            ),
            if (!isActive)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('Inactive', style: TextStyle(fontSize: 11, color: Colors.orange)),
              ),
            IconButton(icon: const Icon(Icons.edit_outlined), onPressed: _edit, tooltip: 'Edit'),
            if (_deleting)
              const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
            else
              IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: _delete, tooltip: 'Remove'),
          ],
        ),
      ),
    );
  }
}

class _AddDaySheet extends ConsumerStatefulWidget {
  const _AddDaySheet({
    required this.existingDays,
    this.initialData,
    required this.onSaved,
  });
  final Set<String> existingDays;
  final Map<String, dynamic>? initialData;
  final VoidCallback onSaved;

  @override
  ConsumerState<_AddDaySheet> createState() => _AddDaySheetState();
}

class _AddDaySheetState extends ConsumerState<_AddDaySheet> {
  String? _day;
  late String _startTime;
  late String _endTime;
  late int _slotMinutes;
  bool _isActive = true;
  bool _loading = false;
  String? _error;

  bool get _isEditing => widget.initialData != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _day = widget.initialData!['dayOfWeek'] as String;
      _startTime = widget.initialData!['startTime'] as String? ?? '09:00';
      _endTime = widget.initialData!['endTime'] as String? ?? '17:00';
      _slotMinutes = (widget.initialData!['slotDurationMinutes'] as num?)?.toInt() ?? 30;
      _isActive = widget.initialData!['isActive'] as bool? ?? true;
    } else {
      _startTime = '09:00';
      _endTime = '17:00';
      _slotMinutes = 30;
    }
  }

  List<String> get _availableDays =>
      _dayOrder.where((d) => !widget.existingDays.contains(d)).toList();

  Future<void> _save() async {
    if (_day == null) {
      setState(() => _error = 'Please select a day');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(dioProvider).post('/doctors/me/availability', data: {
        'dayOfWeek': _day,
        'startTime': _startTime,
        'endTime': _endTime,
        'slotDurationMinutes': _slotMinutes,
        'isActive': _isActive,
      });
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _isEditing ? 'Edit Working Hours' : 'Add Working Day',
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 20),
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
            ),
            const SizedBox(height: 12),
          ],
          // Day selector
          if (_isEditing)
            InputDecorator(
              decoration: const InputDecoration(labelText: 'Day', border: OutlineInputBorder()),
              child: Text(_dayLabels[_day!] ?? _day!),
            )
          else
            DropdownButtonFormField<String>(
              value: _day,
              decoration: const InputDecoration(labelText: 'Day *', border: OutlineInputBorder()),
              items: _availableDays
                  .map((d) => DropdownMenuItem(value: d, child: Text(_dayLabels[d] ?? d)))
                  .toList(),
              onChanged: (v) => setState(() => _day = v),
            ),
          const SizedBox(height: 12),
          // Time row
          Row(
            children: [
              Expanded(child: _TimeField(
                label: 'Start Time',
                value: _startTime,
                onChanged: (v) => setState(() => _startTime = v),
              )),
              const SizedBox(width: 12),
              Expanded(child: _TimeField(
                label: 'End Time',
                value: _endTime,
                onChanged: (v) => setState(() => _endTime = v),
              )),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            value: _slotMinutes,
            decoration: const InputDecoration(labelText: 'Slot Duration', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 15, child: Text('15 minutes')),
              DropdownMenuItem(value: 20, child: Text('20 minutes')),
              DropdownMenuItem(value: 30, child: Text('30 minutes')),
              DropdownMenuItem(value: 45, child: Text('45 minutes')),
              DropdownMenuItem(value: 60, child: Text('60 minutes')),
            ],
            onChanged: (v) => setState(() => _slotMinutes = v ?? 30),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            value: _isActive,
            onChanged: (v) => setState(() => _isActive = v),
            title: const Text('Active'),
            subtitle: const Text('Uncheck to temporarily disable this day'),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _loading ? null : _save,
              child: _loading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(_isEditing ? 'Save Changes' : 'Add Day'),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeField extends StatelessWidget {
  const _TimeField({required this.label, required this.value, required this.onChanged});
  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () async {
        final parts = value.split(':');
        final initial = TimeOfDay(
          hour: int.tryParse(parts[0]) ?? 9,
          minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
        );
        final picked = await showTimePicker(context: context, initialTime: initial);
        if (picked != null) {
          onChanged('${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}');
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        child: Row(
          children: [
            const Icon(Icons.access_time, size: 16, color: Colors.grey),
            const SizedBox(width: 6),
            Text(value),
          ],
        ),
      ),
    );
  }
}
