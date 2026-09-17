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
                              FilledButton.tonal(
                                onPressed: () => _showManageSheet(context, ref, doc),
                                style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                                child: const Text('Manage'),
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

  void _showManageSheet(BuildContext context, WidgetRef ref, Map<String, dynamic> doc) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _DoctorManageSheet(doc: doc, dioProvider: _dioProvider),
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

// ─────────────────────────────────────────────────────────────────────────────
// Doctor Manage Sheet — Availability / Clinics / Categories
// ─────────────────────────────────────────────────────────────────────────────

class _DoctorManageSheet extends ConsumerStatefulWidget {
  const _DoctorManageSheet({required this.doc, required this.dioProvider});
  final Map<String, dynamic> doc;
  final Provider<Dio> dioProvider;

  @override
  ConsumerState<_DoctorManageSheet> createState() => _DoctorManageSheetState();
}

class _DoctorManageSheetState extends ConsumerState<_DoctorManageSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  String get _doctorId => widget.doc['id'] as String;
  String get _doctorName => widget.doc['name'] as String? ?? '';

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, controller) => Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                Text('Dr. $_doctorName', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          TabBar(
            controller: _tabs,
            tabs: const [
              Tab(icon: Icon(Icons.schedule), text: 'Availability'),
              Tab(icon: Icon(Icons.local_hospital), text: 'Clinics'),
              Tab(icon: Icon(Icons.category), text: 'Categories'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _AvailabilityTab(doctorId: _doctorId, dioProvider: widget.dioProvider),
                _ClinicsTab(doctorId: _doctorId, dioProvider: widget.dioProvider),
                _CategoriesTab(doctorId: _doctorId, dioProvider: widget.dioProvider),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Availability Tab ──────────────────────────────────────────────────────────

class _AvailabilityTab extends ConsumerStatefulWidget {
  const _AvailabilityTab({required this.doctorId, required this.dioProvider});
  final String doctorId;
  final Provider<Dio> dioProvider;

  @override
  ConsumerState<_AvailabilityTab> createState() => _AvailabilityTabState();
}

class _AvailabilityTabState extends ConsumerState<_AvailabilityTab> {
  List<Map<String, dynamic>>? _availability;
  bool _loading = true;
  String? _error;

  static const _dayOrder = ['MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY', 'SUNDAY'];
  static const _dayLabels = {
    'MONDAY': 'Monday', 'TUESDAY': 'Tuesday', 'WEDNESDAY': 'Wednesday',
    'THURSDAY': 'Thursday', 'FRIDAY': 'Friday', 'SATURDAY': 'Saturday', 'SUNDAY': 'Sunday',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final resp = await ref.read(widget.dioProvider).get('/admin/doctors/${widget.doctorId}/availability');
      final list = List<Map<String, dynamic>>.from(resp.data['data'] as List);
      list.sort((a, b) => _dayOrder.indexOf(a['dayOfWeek'] as String).compareTo(_dayOrder.indexOf(b['dayOfWeek'] as String)));
      setState(() { _availability = list; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _deleteDay(String day) async {
    await ref.read(widget.dioProvider).delete('/admin/doctors/${widget.doctorId}/availability/$day');
    _load();
  }

  void _showAddDay() {
    showDialog(
      context: context,
      builder: (_) => _AddAvailabilityDialog(
        doctorId: widget.doctorId,
        dioProvider: widget.dioProvider,
        existingDays: _availability?.map((a) => a['dayOfWeek'] as String).toSet() ?? {},
        onSaved: _load,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text('Error: $_error'));
    final avail = _availability ?? [];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Text('Working Hours (${avail.length} days)', style: const TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              FilledButton.icon(
                onPressed: _showAddDay,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Day'),
                style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
              ),
            ],
          ),
        ),
        if (avail.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.schedule, size: 64, color: Colors.grey),
                  const SizedBox(height: 12),
                  const Text('No availability configured', style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 8),
                  FilledButton(onPressed: _showAddDay, child: const Text('Set Up Schedule')),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: avail.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final a = avail[i];
                final day = a['dayOfWeek'] as String;
                final isActive = a['isActive'] as bool? ?? true;
                return ListTile(
                  leading: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: isActive ? Colors.blue.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.calendar_today, size: 20, color: isActive ? Colors.blue : Colors.grey),
                  ),
                  title: Text(_dayLabels[day] ?? day, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('${a['startTime']} – ${a['endTime']}  ·  ${a['slotDurationMinutes']}min slots'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _deleteDay(day),
                    tooltip: 'Remove',
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _AddAvailabilityDialog extends ConsumerStatefulWidget {
  const _AddAvailabilityDialog({
    required this.doctorId, required this.dioProvider,
    required this.existingDays, required this.onSaved,
  });
  final String doctorId;
  final Provider<Dio> dioProvider;
  final Set<String> existingDays;
  final VoidCallback onSaved;

  @override
  ConsumerState<_AddAvailabilityDialog> createState() => _AddAvailabilityDialogState();
}

class _AddAvailabilityDialogState extends ConsumerState<_AddAvailabilityDialog> {
  static const _allDays = ['MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY', 'SUNDAY'];
  static const _dayLabels = {
    'MONDAY': 'Monday', 'TUESDAY': 'Tuesday', 'WEDNESDAY': 'Wednesday',
    'THURSDAY': 'Thursday', 'FRIDAY': 'Friday', 'SATURDAY': 'Saturday', 'SUNDAY': 'Sunday',
  };
  String? _day;
  String _startTime = '09:00';
  String _endTime = '17:00';
  int _slotMinutes = 30;
  bool _loading = false;
  String? _error;

  List<String> get _availableDays => _allDays.where((d) => !widget.existingDays.contains(d)).toList();

  Future<void> _save() async {
    if (_day == null) { setState(() => _error = 'Select a day'); return; }
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(widget.dioProvider).post('/admin/doctors/${widget.doctorId}/availability', data: {
        'dayOfWeek': _day,
        'startTime': _startTime,
        'endTime': _endTime,
        'slotDurationMinutes': _slotMinutes,
        'isActive': true,
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
    return AlertDialog(
      title: const Text('Add Working Hours'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
              const SizedBox(height: 8),
            ],
            DropdownButtonFormField<String>(
              value: _day,
              decoration: const InputDecoration(labelText: 'Day *', border: OutlineInputBorder()),
              items: _availableDays.map((d) => DropdownMenuItem(value: d, child: Text(_dayLabels[d] ?? d))).toList(),
              onChanged: (v) => setState(() => _day = v),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: _startTime,
                    decoration: const InputDecoration(labelText: 'Start Time', hintText: 'HH:MM', border: OutlineInputBorder()),
                    onChanged: (v) => _startTime = v.trim(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    initialValue: _endTime,
                    decoration: const InputDecoration(labelText: 'End Time', hintText: 'HH:MM', border: OutlineInputBorder()),
                    onChanged: (v) => _endTime = v.trim(),
                  ),
                ),
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
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _loading ? null : _save,
          child: _loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save'),
        ),
      ],
    );
  }
}

// ── Clinics Tab ───────────────────────────────────────────────────────────────

class _ClinicsTab extends ConsumerStatefulWidget {
  const _ClinicsTab({required this.doctorId, required this.dioProvider});
  final String doctorId;
  final Provider<Dio> dioProvider;

  @override
  ConsumerState<_ClinicsTab> createState() => _ClinicsTabState();
}

class _ClinicsTabState extends ConsumerState<_ClinicsTab> {
  List<Map<String, dynamic>>? _clinics;
  List<Map<String, dynamic>>? _allClinics;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final [clinicsResp, allResp] = await Future.wait([
        ref.read(widget.dioProvider).get('/admin/doctors/${widget.doctorId}/clinics'),
        ref.read(widget.dioProvider).get('/admin/clinics', queryParameters: {'limit': '100'}),
      ]);
      setState(() {
        _clinics = List<Map<String, dynamic>>.from(clinicsResp.data['data'] as List);
        _allClinics = List<Map<String, dynamic>>.from(allResp.data['data'] as List);
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _remove(String clinicId) async {
    await ref.read(widget.dioProvider).delete('/admin/doctors/${widget.doctorId}/clinics/$clinicId');
    _load();
  }

  void _showAssign() {
    final assignedIds = _clinics?.map((c) => c['clinicId'] as String? ?? '').toSet() ?? {};
    final available = _allClinics?.where((c) => !assignedIds.contains(c['id'])).toList() ?? [];
    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All clinics already assigned')));
      return;
    }
    showDialog(
      context: context,
      builder: (_) => _AssignClinicDialog(
        doctorId: widget.doctorId,
        dioProvider: widget.dioProvider,
        clinics: available,
        onSaved: _load,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final list = _clinics ?? [];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Text('Assigned Clinics (${list.length})', style: const TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              FilledButton.icon(
                onPressed: _showAssign,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Assign Clinic'),
                style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
              ),
            ],
          ),
        ),
        if (list.isEmpty)
          const Expanded(child: Center(child: Text('No clinics assigned', style: TextStyle(color: Colors.grey))))
        else
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final c = list[i];
                final isPrimary = c['isPrimary'] as bool? ?? false;
                return ListTile(
                  leading: const Icon(Icons.local_hospital, color: Colors.blue),
                  title: Row(
                    children: [
                      Text(c['clinicName'] as String? ?? ''),
                      if (isPrimary) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(4)),
                          child: const Text('Primary', style: TextStyle(fontSize: 10, color: Colors.blue)),
                        ),
                      ],
                    ],
                  ),
                  subtitle: Text('${c['city'] ?? ''} · Fee: ₹${c['consultationFee'] ?? 0}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.link_off, color: Colors.red),
                    onPressed: () => _remove(c['clinicId'] as String? ?? ''),
                    tooltip: 'Remove',
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _AssignClinicDialog extends ConsumerStatefulWidget {
  const _AssignClinicDialog({
    required this.doctorId, required this.dioProvider,
    required this.clinics, required this.onSaved,
  });
  final String doctorId;
  final Provider<Dio> dioProvider;
  final List<Map<String, dynamic>> clinics;
  final VoidCallback onSaved;

  @override
  ConsumerState<_AssignClinicDialog> createState() => _AssignClinicDialogState();
}

class _AssignClinicDialogState extends ConsumerState<_AssignClinicDialog> {
  String? _clinicId;
  final _feeCtrl = TextEditingController(text: '500');
  bool _isPrimary = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() { _feeCtrl.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (_clinicId == null) { setState(() => _error = 'Select a clinic'); return; }
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(widget.dioProvider).post('/admin/doctors/${widget.doctorId}/clinics', data: {
        'clinicId': _clinicId,
        'consultationFee': int.tryParse(_feeCtrl.text.trim()) ?? 0,
        'isPrimary': _isPrimary,
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
    return AlertDialog(
      title: const Text('Assign Clinic'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_error != null) ...[Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)), const SizedBox(height: 8)],
            DropdownButtonFormField<String>(
              value: _clinicId,
              decoration: const InputDecoration(labelText: 'Clinic *', border: OutlineInputBorder()),
              items: widget.clinics.map((c) => DropdownMenuItem(value: c['id'] as String, child: Text('${c['name']} (${c['city'] ?? ''})'))).toList(),
              onChanged: (v) => setState(() => _clinicId = v),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _feeCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Consultation Fee (₹)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              value: _isPrimary,
              onChanged: (v) => setState(() => _isPrimary = v ?? false),
              title: const Text('Set as primary clinic'),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _loading ? null : _save,
          child: _loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Assign'),
        ),
      ],
    );
  }
}

// ── Categories Tab ────────────────────────────────────────────────────────────

class _CategoriesTab extends ConsumerStatefulWidget {
  const _CategoriesTab({required this.doctorId, required this.dioProvider});
  final String doctorId;
  final Provider<Dio> dioProvider;

  @override
  ConsumerState<_CategoriesTab> createState() => _CategoriesTabState();
}

class _CategoriesTabState extends ConsumerState<_CategoriesTab> {
  List<Map<String, dynamic>>? _assigned;
  List<Map<String, dynamic>>? _allCats;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final [assignedResp, allResp] = await Future.wait([
        ref.read(widget.dioProvider).get('/admin/doctors/${widget.doctorId}/categories'),
        ref.read(widget.dioProvider).get('/admin/categories'),
      ]);
      setState(() {
        _assigned = List<Map<String, dynamic>>.from(assignedResp.data['data'] as List);
        _allCats = List<Map<String, dynamic>>.from(allResp.data['data'] as List);
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _remove(String categoryId) async {
    await ref.read(widget.dioProvider).delete('/admin/doctors/${widget.doctorId}/categories/$categoryId');
    _load();
  }

  void _showAssign() {
    final assignedIds = _assigned?.map((c) => c['categoryId'] as String? ?? '').toSet() ?? {};
    final available = _allCats?.where((c) => !assignedIds.contains(c['id'])).toList() ?? [];
    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All categories already assigned')));
      return;
    }
    showDialog(
      context: context,
      builder: (_) => _AssignCategoryDialog(
        doctorId: widget.doctorId,
        dioProvider: widget.dioProvider,
        categories: available,
        onSaved: _load,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final list = _assigned ?? [];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Text('Specializations (${list.length})', style: const TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              FilledButton.icon(
                onPressed: _showAssign,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Specialization'),
                style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
              ),
            ],
          ),
        ),
        if (list.isEmpty)
          const Expanded(child: Center(child: Text('No specializations assigned', style: TextStyle(color: Colors.grey))))
        else
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final c = list[i];
                final isPrimary = c['isPrimary'] as bool? ?? false;
                final color = c['color'] as String? ?? '#4CAF50';
                Color chipColor;
                try {
                  chipColor = Color(int.parse(color.replaceFirst('#', 'FF'), radix: 16));
                } catch (_) {
                  chipColor = Colors.green;
                }
                return ListTile(
                  leading: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(color: chipColor.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                    child: Icon(Icons.local_hospital, size: 18, color: chipColor),
                  ),
                  title: Row(
                    children: [
                      Text(c['categoryName'] as String? ?? ''),
                      if (isPrimary) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: chipColor.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                          child: Text('Primary', style: TextStyle(fontSize: 10, color: chipColor, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                    onPressed: () => _remove(c['categoryId'] as String? ?? ''),
                    tooltip: 'Remove',
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _AssignCategoryDialog extends ConsumerStatefulWidget {
  const _AssignCategoryDialog({
    required this.doctorId, required this.dioProvider,
    required this.categories, required this.onSaved,
  });
  final String doctorId;
  final Provider<Dio> dioProvider;
  final List<Map<String, dynamic>> categories;
  final VoidCallback onSaved;

  @override
  ConsumerState<_AssignCategoryDialog> createState() => _AssignCategoryDialogState();
}

class _AssignCategoryDialogState extends ConsumerState<_AssignCategoryDialog> {
  String? _categoryId;
  bool _isPrimary = false;
  bool _loading = false;
  String? _error;

  Future<void> _save() async {
    if (_categoryId == null) { setState(() => _error = 'Select a category'); return; }
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(widget.dioProvider).post('/admin/doctors/${widget.doctorId}/categories', data: {
        'categoryId': _categoryId,
        'isPrimary': _isPrimary,
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
    return AlertDialog(
      title: const Text('Add Specialization'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_error != null) ...[Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)), const SizedBox(height: 8)],
            DropdownButtonFormField<String>(
              value: _categoryId,
              decoration: const InputDecoration(labelText: 'Specialization *', border: OutlineInputBorder()),
              items: widget.categories.map((c) => DropdownMenuItem(value: c['id'] as String, child: Text(c['name'] as String))).toList(),
              onChanged: (v) => setState(() => _categoryId = v),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              value: _isPrimary,
              onChanged: (v) => setState(() => _isPrimary = v ?? false),
              title: const Text('Set as primary specialization'),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _loading ? null : _save,
          child: _loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Assign'),
        ),
      ],
    );
  }
}
