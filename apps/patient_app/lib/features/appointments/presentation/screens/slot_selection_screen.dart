import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../providers/appointments_provider.dart';

class SlotSelectionScreen extends ConsumerStatefulWidget {
  const SlotSelectionScreen({
    super.key,
    required this.doctorId,
    required this.clinicId,
    required this.doctorName,
  });

  final String doctorId;
  final String clinicId;
  final String doctorName;

  @override
  ConsumerState<SlotSelectionScreen> createState() => _SlotSelectionScreenState();
}

class _SlotSelectionScreenState extends ConsumerState<SlotSelectionScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  String? _selectedSlotId;
  String? _selectedSlotTime;
  Timer? _lockTimer;
  int _lockSecondsLeft = 0;
  bool _isBooking = false;

  @override
  void dispose() {
    _lockTimer?.cancel();
    if (_selectedSlotId != null) {
      ref.read(appointmentServiceProvider).releaseSlot(_selectedSlotId!);
    }
    super.dispose();
  }

  String get _dateString =>
      '${_selectedDay.year}-${_selectedDay.month.toString().padLeft(2,'0')}-${_selectedDay.day.toString().padLeft(2,'0')}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final slotsAsync = ref.watch(
      slotsProvider((doctorId: widget.doctorId, clinicId: widget.clinicId, date: _dateString)),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('Dr. ${widget.doctorName}'),
        leading: const BackButton(),
      ),
      body: Column(
        children: [
          // Calendar
          TableCalendar(
            firstDay: DateTime.now(),
            lastDay: DateTime.now().add(const Duration(days: 60)),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            calendarFormat: CalendarFormat.week,
            startingDayOfWeek: StartingDayOfWeek.monday,
            headerStyle: HeaderStyle(
              formatButtonVisible: false,
              titleTextStyle: AppTextStyles.titleSmall,
              leftChevronIcon: const Icon(Icons.chevron_left_rounded),
              rightChevronIcon: const Icon(Icons.chevron_right_rounded),
            ),
            calendarStyle: CalendarStyle(
              selectedDecoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                color: AppColors.primaryContainer,
                shape: BoxShape.circle,
              ),
              todayTextStyle: const TextStyle(color: AppColors.primary),
              weekendTextStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
            onDaySelected: (selected, focused) {
              setState(() {
                _selectedDay = selected;
                _focusedDay = focused;
                _selectedSlotId = null;
                _selectedSlotTime = null;
              });
              _lockTimer?.cancel();
            },
          ),

          const Divider(height: 1),

          // Slots
          Expanded(
            child: slotsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text('Failed to load slots: $e'),
              ),
              data: (slots) {
                final available = slots.where((s) => s['isAvailable'] == true).toList();
                if (slots.isEmpty) {
                  return _UnavailableState(message: 'Doctor not available on this day');
                }
                if (available.isEmpty) {
                  return _UnavailableState(message: 'All slots are booked for this day');
                }

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Row(
                        children: [
                          Text(
                            '${available.length} slots available',
                            style: AppTextStyles.titleSmall,
                          ),
                          if (_lockSecondsLeft > 0) ...[
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.warning.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.timer_outlined, size: 14, color: AppColors.warning),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Held for ${_lockSecondsLeft}s',
                                    style: AppTextStyles.labelSmall.copyWith(color: AppColors.warning),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Expanded(
                      child: GridView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 2.5,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: slots.length,
                        itemBuilder: (_, i) {
                          final slot = slots[i];
                          final isAvail = slot['isAvailable'] == true;
                          final slotId = slot['id'] as String;
                          final isSelected = _selectedSlotId == slotId;

                          return GestureDetector(
                            onTap: isAvail ? () => _selectSlot(slot) : null,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primary
                                    : isAvail
                                        ? theme.colorScheme.surfaceContainerHighest
                                        : theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected ? AppColors.primary : Colors.transparent,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  slot['startTime'] as String,
                                  style: AppTextStyles.labelMedium.copyWith(
                                    color: isSelected
                                        ? Colors.white
                                        : isAvail
                                            ? theme.colorScheme.onSurface
                                            : theme.colorScheme.onSurface.withOpacity(0.3),
                                    decoration: isAvail ? null : TextDecoration.lineThrough,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // Book button
          if (_selectedSlotId != null)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: AppButton(
                  label: 'Confirm Booking — $_selectedSlotTime',
                  onPressed: _confirmBooking,
                  isLoading: _isBooking,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _selectSlot(Map<String, dynamic> slot) async {
    // Release previous lock if any
    if (_selectedSlotId != null && _selectedSlotId != slot['id']) {
      await ref.read(appointmentServiceProvider).releaseSlot(_selectedSlotId!);
      _lockTimer?.cancel();
    }

    setState(() {
      _selectedSlotId = slot['id'] as String;
      _selectedSlotTime = slot['startTime'] as String;
    });

    // Lock the slot
    try {
      await ref.read(appointmentServiceProvider).lockSlot(_selectedSlotId!);
      _startLockCountdown();
    } catch (e) {
      setState(() { _selectedSlotId = null; _selectedSlotTime = null; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Slot no longer available'),
            backgroundColor: AppColors.error,
          ),
        );
        ref.refresh(slotsProvider((
          doctorId: widget.doctorId,
          clinicId: widget.clinicId,
          date: _dateString,
        )));
      }
    }
  }

  void _startLockCountdown() {
    _lockTimer?.cancel();
    setState(() => _lockSecondsLeft = 120);
    _lockTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_lockSecondsLeft <= 0) {
        t.cancel();
        setState(() { _selectedSlotId = null; _selectedSlotTime = null; _lockSecondsLeft = 0; });
        ref.refresh(slotsProvider((
          doctorId: widget.doctorId,
          clinicId: widget.clinicId,
          date: _dateString,
        )));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Slot hold expired. Please select again.')),
          );
        }
      } else {
        setState(() => _lockSecondsLeft--);
      }
    });
  }

  Future<void> _confirmBooking() async {
    if (_selectedSlotId == null) return;
    setState(() => _isBooking = true);

    try {
      final appointment = await ref.read(appointmentServiceProvider).bookAppointment(
        doctorId: widget.doctorId,
        clinicId: widget.clinicId,
        slotId: _selectedSlotId!,
      );

      _lockTimer?.cancel();

      if (mounted) {
        context.pushReplacementNamed('bookingConfirmation', extra: appointment);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isBooking = false);
    }
  }
}

class _UnavailableState extends StatelessWidget {
  const _UnavailableState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_busy_rounded,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.4),
          ),
          const SizedBox(height: 16),
          Text(message, style: AppTextStyles.bodyMedium),
        ],
      ),
    );
  }
}
