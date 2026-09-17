import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _baseUrl = String.fromEnvironment('API_BASE_URL',
    defaultValue: 'https://doctor-booking-system-production-2bf8.up.railway.app/api/v1');

const _storage = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
);

final _dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(baseUrl: _baseUrl));
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (opts, handler) async {
      final token = await _storage.read(key: 'access_token');
      if (token != null) opts.headers['Authorization'] = 'Bearer $token';
      handler.next(opts);
    },
  ));
  return dio;
});

final _scheduleProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final response =
      await ref.watch(_dioProvider).get('/doctors/me/profile');
  return Map<String, dynamic>.from(response.data['data'] as Map);
});

const _days = ['MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY', 'SUNDAY'];
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
    final scheduleAsync = ref.watch(_scheduleProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Schedule'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(_scheduleProvider),
          ),
        ],
      ),
      body: scheduleAsync.when(
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
                onPressed: () => ref.invalidate(_scheduleProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (doc) {
          final availabilities = (doc['availabilities'] as List? ?? []);
          final vacations = (doc['vacations'] as List? ?? []);
          final blockedDates = (doc['blockedDates'] as List? ?? []);

          // Group by day
          final Map<String, List<Map<String, dynamic>>> byDay = {};
          for (final a in availabilities) {
            final day = a['dayOfWeek'] as String? ?? '';
            byDay.putIfAbsent(day, () => []).add(a as Map<String, dynamic>);
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Working Hours',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                if (availabilities.isEmpty)
                  const _EmptySection(
                      message: 'No working hours configured.\nContact admin to set up your schedule.')
                else
                  Card(
                    child: Column(
                      children: _days.map((day) {
                        final slots = byDay[day] ?? [];
                        return _DayRow(day: day, slots: slots);
                      }).toList(),
                    ),
                  ),
                const SizedBox(height: 24),
                Text('Upcoming Vacations',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                if (vacations.isEmpty)
                  const _EmptySection(message: 'No upcoming vacations')
                else
                  Card(
                    child: Column(
                      children: vacations
                          .cast<Map<String, dynamic>>()
                          .map((v) => ListTile(
                                leading: const Icon(Icons.beach_access_outlined),
                                title: Text(_formatDateRange(
                                    v['startDate'] as String? ?? '',
                                    v['endDate'] as String? ?? '')),
                                subtitle: (v['reason'] as String?) != null
                                    ? Text(v['reason'] as String)
                                    : null,
                              ))
                          .toList(),
                    ),
                  ),
                const SizedBox(height: 24),
                Text('Blocked Dates',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                if (blockedDates.isEmpty)
                  const _EmptySection(message: 'No blocked dates')
                else
                  Card(
                    child: Column(
                      children: blockedDates
                          .cast<Map<String, dynamic>>()
                          .map((b) => ListTile(
                                leading: const Icon(Icons.block_outlined),
                                title: Text(_fmtDate(b['date'] as String? ?? '')),
                                subtitle: (b['reason'] as String?) != null
                                    ? Text(b['reason'] as String)
                                    : null,
                              ))
                          .toList(),
                    ),
                  ),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  String _fmtDate(String iso) =>
      iso.length >= 10 ? iso.substring(0, 10) : iso;

  String _formatDateRange(String start, String end) =>
      '${_fmtDate(start)} → ${_fmtDate(end)}';
}

class _DayRow extends StatelessWidget {
  const _DayRow({required this.day, required this.slots});
  final String day;
  final List<Map<String, dynamic>> slots;

  @override
  Widget build(BuildContext context) {
    final active = slots.any((s) => s['isActive'] == true);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              _dayLabels[day] ?? day,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: active ? null : Colors.grey,
              ),
            ),
          ),
          if (!active || slots.isEmpty)
            const Text('Off', style: TextStyle(color: Colors.grey))
          else
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: slots
                    .where((s) => s['isActive'] == true)
                    .map((s) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${s['startTime']} – ${s['endTime']}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptySection extends StatelessWidget {
  const _EmptySection({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey),
          ),
        ),
      ),
    );
  }
}
