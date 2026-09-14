import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../providers/doctors_provider.dart';

class DoctorProfileScreen extends ConsumerStatefulWidget {
  const DoctorProfileScreen({super.key, required this.doctorId});
  final String doctorId;

  @override
  ConsumerState<DoctorProfileScreen> createState() => _DoctorProfileScreenState();
}

class _DoctorProfileScreenState extends ConsumerState<DoctorProfileScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  int _galleryIndex = 0;

  @override
  Widget build(BuildContext context) {
    final doctorAsync = ref.watch(doctorDetailProvider(widget.doctorId));

    return Scaffold(
      body: doctorAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (doctor) => _buildContent(doctor),
      ),
    );
  }

  Widget _buildContent(Map<String, dynamic> doctor) {
    final theme = Theme.of(context);
    final clinics = (doctor['clinics'] as List?) ?? [];
    final primaryClinic = clinics.isNotEmpty ? clinics.first as Map : null;
    final fee = (primaryClinic?['consultationFee'] as num?)?.toDouble() ?? 0;
    final clinicInfo = primaryClinic?['clinic'] as Map?;
    final clinicImages = (clinicInfo?['images'] as List?)?.cast<String>() ?? [];

    return CustomScrollView(
      slivers: [
        // ── Hero header ──────────────────────────────────────────────
        SliverAppBar(
          expandedHeight: 280,
          pinned: true,
          leading: Semantics(
            label: 'Go back',
            child: IconButton.filled(
              onPressed: () => context.pop(),
              icon: const Icon(Icons.arrow_back_rounded),
              style: IconButton.styleFrom(
                backgroundColor: Colors.black38,
                foregroundColor: Colors.white,
              ),
            ),
          ),
          actions: [
            Semantics(
              label: doctor['isFavorite'] == true ? 'Remove from favorites' : 'Add to favorites',
              child: IconButton.filled(
                onPressed: () => ref.read(doctorsProviderFamily.notifier).toggleFavorite(widget.doctorId),
                icon: Icon(
                  doctor['isFavorite'] == true ? Icons.favorite : Icons.favorite_outline,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black38,
                  foregroundColor: doctor['isFavorite'] == true ? AppColors.error : Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(
              fit: StackFit.expand,
              children: [
                doctor['avatarUrl'] != null
                    ? CachedNetworkImage(
                        imageUrl: doctor['avatarUrl'] as String,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => _doctorInitialAvatar(doctor),
                      )
                    : _doctorInitialAvatar(doctor),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black54],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dr. ${doctor['name']}',
                        style: AppTextStyles.headlineSmall.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      Semantics(
                        label: 'Rating: ${(doctor['averageRating'] as num?)?.toStringAsFixed(1) ?? '0'} out of 5',
                        child: RatingBarIndicator(
                          rating: (doctor['averageRating'] as num?)?.toDouble() ?? 0,
                          itemBuilder: (_, __) =>
                              const Icon(Icons.star_rounded, color: AppColors.warning),
                          itemCount: 5,
                          itemSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Stats row ──────────────────────────────────────
                Row(
                  children: [
                    _StatBox(
                      value: '${doctor['experienceYears']}yr',
                      label: 'Experience',
                      semanticLabel: '${doctor['experienceYears']} years experience',
                    ),
                    const SizedBox(width: 12),
                    _StatBox(
                      value: '${doctor['totalReviews']}',
                      label: 'Reviews',
                      semanticLabel: '${doctor['totalReviews']} patient reviews',
                    ),
                    const SizedBox(width: 12),
                    _StatBox(
                      value: '₹${fee.toStringAsFixed(0)}',
                      label: 'Fee',
                      semanticLabel: 'Consultation fee ₹${fee.toStringAsFixed(0)}',
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // ── About ───────────────────────────────────────────
                if (doctor['about'] != null) ...[
                  Text('About', style: AppTextStyles.titleSmall),
                  const SizedBox(height: 8),
                  Text(doctor['about'] as String, style: AppTextStyles.bodyMedium),
                  const SizedBox(height: 20),
                ],

                // ── Qualifications ─────────────────────────────────
                if ((doctor['qualifications'] as List?)?.isNotEmpty == true) ...[
                  Text('Qualifications', style: AppTextStyles.titleSmall),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: (doctor['qualifications'] as List)
                        .map((q) => Chip(label: Text(q as String)))
                        .toList(),
                  ),
                  const SizedBox(height: 20),
                ],

                // ── Languages ──────────────────────────────────────
                if ((doctor['languages'] as List?)?.isNotEmpty == true) ...[
                  Text('Languages', style: AppTextStyles.titleSmall),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: (doctor['languages'] as List)
                        .map((l) => Chip(
                              avatar: const Icon(Icons.language, size: 16),
                              label: Text(l as String),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 20),
                ],

                // ── Clinic image gallery (Phase 2) ─────────────────
                if (clinicImages.isNotEmpty) ...[
                  Text('Clinic Gallery', style: AppTextStyles.titleSmall),
                  const SizedBox(height: 12),
                  _ClinicImageGallery(
                    images: clinicImages,
                    currentIndex: _galleryIndex,
                    onPageChanged: (i) => setState(() => _galleryIndex = i),
                  ),
                  const SizedBox(height: 20),
                ],

                // ── Clinic card ────────────────────────────────────
                if (clinicInfo != null) ...[
                  Text('Clinic', style: AppTextStyles.titleSmall),
                  const SizedBox(height: 8),
                  _ClinicCard(
                    clinicInfo: clinicInfo,
                    onDirections: () => _openMaps(clinicInfo),
                  ),
                  const SizedBox(height: 24),
                ],

                // ── Availability calendar (Phase 2) ─────────────────
                Text('Available Dates', style: AppTextStyles.titleSmall),
                const SizedBox(height: 12),
                _AvailabilityCalendar(
                  doctorId: widget.doctorId,
                  focusedDay: _focusedDay,
                  selectedDay: _selectedDay,
                  onDaySelected: (selected, focused) {
                    setState(() {
                      _selectedDay = selected;
                      _focusedDay = focused;
                    });
                  },
                  onMonthChanged: (focused) =>
                      setState(() => _focusedDay = focused),
                  onBook: () {
                    final clinicId = clinicInfo?['id'] as String? ?? '';
                    final doctorName = doctor['name'] as String? ?? '';
                    context.pushNamed(
                      'slotSelection',
                      pathParameters: {'id': widget.doctorId},
                      extra: {
                        'clinicId': clinicId,
                        'doctorName': doctorName,
                      },
                    );
                  },
                ),

                const SizedBox(height: 28),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _doctorInitialAvatar(Map<String, dynamic> doctor) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          (doctor['name'] as String).substring(0, 1).toUpperCase(),
          style: const TextStyle(
              fontSize: 80, color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  void _openMaps(Map clinicInfo) async {
    final lat = clinicInfo['lat'];
    final lng = clinicInfo['lng'];
    if (lat == null || lng == null) return;
    final uri =
        Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    if (await canLaunchUrl(uri)) launchUrl(uri);
  }
}

// ─── Clinic Image Gallery ────────────────────────────────────────────────────

class _ClinicImageGallery extends StatelessWidget {
  const _ClinicImageGallery({
    required this.images,
    required this.currentIndex,
    required this.onPageChanged,
  });
  final List<String> images;
  final int currentIndex;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 180,
          child: PageView.builder(
            onPageChanged: onPageChanged,
            itemCount: images.length,
            itemBuilder: (_, i) => Semantics(
              label: 'Clinic photo ${i + 1} of ${images.length}',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CachedNetworkImage(
                  imageUrl: images[i],
                  fit: BoxFit.cover,
                  width: double.infinity,
                  errorWidget: (_, __, ___) => Container(
                    color: AppColors.primaryContainer,
                    child: const Icon(Icons.image_not_supported, size: 48),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (images.length > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              images.length,
              (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == currentIndex ? 16 : 6,
                height: 6,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  color: i == currentIndex
                      ? AppColors.primary
                      : AppColors.primary.withOpacity(0.3),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ─── Clinic Card ─────────────────────────────────────────────────────────────

class _ClinicCard extends StatelessWidget {
  const _ClinicCard({required this.clinicInfo, required this.onDirections});
  final Map clinicInfo;
  final VoidCallback onDirections;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_on_rounded, color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(clinicInfo['name'] as String, style: AppTextStyles.titleSmall),
                Text(clinicInfo['addressLine1'] as String? ?? '',
                    style: AppTextStyles.bodySmall),
                Text(clinicInfo['city'] as String? ?? '',
                    style: AppTextStyles.bodySmall),
              ],
            ),
          ),
          Semantics(
            label: 'Get directions to ${clinicInfo['name']}',
            child: IconButton(
              onPressed: onDirections,
              icon: const Icon(Icons.directions_rounded, color: AppColors.primary),
              tooltip: 'Directions',
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Availability Calendar (Phase 2) ─────────────────────────────────────────

class _AvailabilityCalendar extends ConsumerWidget {
  const _AvailabilityCalendar({
    required this.doctorId,
    required this.focusedDay,
    required this.selectedDay,
    required this.onDaySelected,
    required this.onMonthChanged,
    this.onBook,
  });

  final String doctorId;
  final DateTime focusedDay;
  final DateTime? selectedDay;
  final void Function(DateTime, DateTime) onDaySelected;
  final ValueChanged<DateTime> onMonthChanged;
  final VoidCallback? onBook;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final availAsync = ref.watch(doctorAvailabilityProvider(doctorId));
    final today = DateTime.now();

    return availAsync.when(
      loading: () => const SizedBox(
        height: 320,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (availableDays) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Column(
            children: [
              TableCalendar(
                firstDay: today,
                lastDay: today.add(const Duration(days: 60)),
                focusedDay: focusedDay,
                selectedDayPredicate: (d) =>
                    selectedDay != null && isSameDay(d, selectedDay!),
                enabledDayPredicate: (d) {
                  if (d.isBefore(today.subtract(const Duration(days: 1)))) {
                    return false;
                  }
                  final weekday = _weekdayName(d.weekday);
                  return availableDays.contains(weekday);
                },
                onDaySelected: onDaySelected,
                onPageChanged: onMonthChanged,
                calendarStyle: CalendarStyle(
                  todayDecoration: BoxDecoration(
                    color: AppColors.primaryLight.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  selectedDecoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  disabledTextStyle: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                  ),
                  weekendTextStyle: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                headerStyle: const HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                ),
              ),
              if (selectedDay != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Consumer(
                    builder: (ctx, ref2, _) {
                      return AppButton(
                        label:
                            'Book on ${DateFormat('EEE, d MMM').format(selectedDay!)}',
                        onPressed: onBook,
                      );
                    },
                  ),
                ),
              // Legend
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _LegendDot(color: AppColors.primary, label: 'Selected'),
                    const SizedBox(width: 16),
                    _LegendDot(
                        color: AppColors.primaryLight.withOpacity(0.5),
                        label: 'Today'),
                    const SizedBox(width: 16),
                    _LegendDot(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.2),
                        label: 'Unavailable'),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _weekdayName(int wd) {
    const days = [
      'MONDAY',
      'TUESDAY',
      'WEDNESDAY',
      'THURSDAY',
      'FRIDAY',
      'SATURDAY',
      'SUNDAY'
    ];
    return days[wd - 1];
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: AppTextStyles.labelSmall),
      ],
    );
  }
}

// ─── Stat box ────────────────────────────────────────────────────────────────

class _StatBox extends StatelessWidget {
  const _StatBox(
      {required this.value, required this.label, required this.semanticLabel});
  final String value;
  final String label;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        label: semanticLabel,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Text(value,
                  style: AppTextStyles.titleMedium
                      .copyWith(color: AppColors.primary)),
              const SizedBox(height: 2),
              Text(label,
                  style: AppTextStyles.labelSmall
                      .copyWith(color: AppColors.primaryDark)),
            ],
          ),
        ),
      ),
    );
  }
}
