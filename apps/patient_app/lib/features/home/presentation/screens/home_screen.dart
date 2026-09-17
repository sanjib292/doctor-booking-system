import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/doctor_card.dart';
import '../../../../core/widgets/skeleton_loader.dart';
import '../../../appointments/presentation/providers/appointments_provider.dart';
import '../../../doctors/presentation/providers/doctors_provider.dart';

IconData _categoryIcon(String name) {
  final n = name.toLowerCase();
  if (n.contains('cardio') || n.contains('heart')) return Icons.favorite_rounded;
  if (n.contains('neuro') || n.contains('brain')) return Icons.psychology_rounded;
  if (n.contains('ortho') || n.contains('bone') || n.contains('joint')) return Icons.accessibility_new_rounded;
  if (n.contains('derm') || n.contains('skin')) return Icons.face_retouching_natural_rounded;
  if (n.contains('pediatr') || n.contains('child')) return Icons.child_care_rounded;
  if (n.contains('gynec') || n.contains('obste') || n.contains('women')) return Icons.pregnant_woman_rounded;
  if (n.contains('ent') || n.contains('ear') || n.contains('nose')) return Icons.hearing_rounded;
  if (n.contains('eye') || n.contains('ophthal')) return Icons.visibility_rounded;
  if (n.contains('dental') || n.contains('tooth') || n.contains('teeth')) return Icons.clean_hands_rounded;
  if (n.contains('psych') || n.contains('mental')) return Icons.self_improvement_rounded;
  if (n.contains('onco') || n.contains('cancer')) return Icons.biotech_rounded;
  if (n.contains('gastro') || n.contains('digest') || n.contains('liver')) return Icons.sick_rounded;
  if (n.contains('urol') || n.contains('kidney')) return Icons.water_drop_rounded;
  if (n.contains('pulmo') || n.contains('lung') || n.contains('respir')) return Icons.air_rounded;
  if (n.contains('endocrin') || n.contains('diabet') || n.contains('thyroid')) return Icons.monitor_heart_rounded;
  if (n.contains('general') || n.contains('family') || n.contains('physician')) return Icons.local_hospital_rounded;
  return Icons.medical_services_rounded;
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nearbyDoctors = ref.watch(nearbyDoctorsProvider);
    final upcomingAppt = ref.watch(upcomingAppointmentProvider);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(nearbyDoctorsProvider);
            ref.invalidate(upcomingAppointmentProvider);
          },
          child: CustomScrollView(
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _greeting(),
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Find a Doctor',
                                  style: AppTextStyles.headlineMedium,
                                ),
                              ],
                            ),
                          ),
                          Semantics(
                            label: 'View doctors on map',
                            child: IconButton.filled(
                              onPressed: () => context.pushNamed('mapView'),
                              icon: const Icon(Icons.map_outlined),
                              style: IconButton.styleFrom(
                                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                                foregroundColor: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Semantics(
                            label: 'View notifications',
                            child: IconButton.filled(
                              onPressed: () => context.pushNamed('notifications'),
                              icon: const Icon(Icons.notifications_outlined),
                              style: IconButton.styleFrom(
                                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                                foregroundColor: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Search bar
                      GestureDetector(
                        onTap: () => context.goNamed('search'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.search_rounded,
                                color: theme.colorScheme.onSurfaceVariant,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Search doctors, specialties...',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const Spacer(),
                              Icon(
                                Icons.tune_rounded,
                                color: AppColors.primary,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),

              // Upcoming appointment card
              SliverToBoxAdapter(
                child: upcomingAppt.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (appt) {
                    if (appt == null) return const SizedBox.shrink();
                    final doctor = appt['doctor'] as Map? ?? {};
                    final date = (appt['date'] as String? ?? '').length >= 10
                        ? (appt['date'] as String).substring(0, 10)
                        : appt['date'] as String? ?? '';
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                      child: GestureDetector(
                        onTap: () => context.pushNamed(
                          'appointmentDetail',
                          pathParameters: {'id': appt['id'] as String},
                          extra: appt,
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.primary, AppColors.primaryLight],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Upcoming Appointment',
                                      style: AppTextStyles.labelSmall
                                          .copyWith(color: Colors.white70),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Dr. ${doctor['name'] ?? ''}',
                                      style: AppTextStyles.titleMedium
                                          .copyWith(color: Colors.white),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '$date  ·  ${appt['startTime'] ?? ''}',
                                      style: AppTextStyles.bodySmall
                                          .copyWith(color: Colors.white70),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios_rounded,
                                  color: Colors.white70, size: 16),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Categories
              SliverToBoxAdapter(child: _CategoriesSection()),

              // Banner
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: _PromoBanner(),
                ),
              ),

              // Nearby doctors
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Nearby Doctors', style: AppTextStyles.titleMedium),
                      TextButton(
                        onPressed: () => context.goNamed('search'),
                        child: const Text('See All'),
                      ),
                    ],
                  ),
                ),
              ),

              nearbyDoctors.when(
                loading: () => SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, __) => const DoctorCardSkeleton(),
                    childCount: 4,
                  ),
                ),
                error: (e, _) => SliverToBoxAdapter(
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                        const SizedBox(height: 8),
                        Text('Failed to load doctors', style: AppTextStyles.bodyMedium),
                        TextButton(
                          onPressed: () => ref.refresh(nearbyDoctorsProvider),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (doctors) => SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) {
                      final doc = doctors[i];
                      final clinic = doc['clinics'] != null && (doc['clinics'] as List).isNotEmpty
                          ? (doc['clinics'] as List).first as Map<String, dynamic>
                          : null;
                      return DoctorCard(
                        id: doc['id'] as String,
                        name: doc['name'] as String,
                        specialty: _getSpecialty(doc),
                        experience: doc['experienceYears'] as int? ?? 0,
                        rating: (doc['averageRating'] as num?)?.toDouble() ?? 0,
                        reviewCount: doc['totalReviews'] as int? ?? 0,
                        consultationFee: (clinic?['consultationFee'] as num?)?.toDouble() ?? 0,
                        clinicCity: (clinic?['clinic'] as Map?)?['city'] as String? ?? '',
                        avatarUrl: doc['avatarUrl'] as String?,
                        distance: doc['distance'] as double?,
                        onTap: () => context.pushNamed(
                          'doctorProfile',
                          pathParameters: {'id': doc['id'] as String},
                        ),
                      );
                    },
                    childCount: doctors.length,
                  ),
                ),
              ),

              const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
            ],
          ),
        ),
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _getSpecialty(Map<String, dynamic> doc) {
    final cats = doc['categories'] as List?;
    if (cats == null || cats.isEmpty) return 'General Physician';
    final primary = cats.firstWhere(
      (c) => c['isPrimary'] == true,
      orElse: () => cats.first,
    );
    return (primary['category'] as Map?)?['name'] as String? ?? 'Specialist';
  }
}

class _CategoriesSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);

    return SizedBox(
      height: 100,
      child: categories.when(
        loading: () => ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: 6,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (_, __) => const SkeletonBox(width: 72, height: 90, borderRadius: 12),
        ),
        error: (_, __) => const SizedBox.shrink(),
        data: (cats) => ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: cats.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (_, i) {
            final cat = cats[i];
            final color = Color(int.parse(
              (cat['color'] as String? ?? '#4CAF50').replaceFirst('#', 'FF'),
              radix: 16,
            ));
            final icon = _categoryIcon(cat['name'] as String? ?? '');
            return GestureDetector(
              onTap: () => context.goNamed('search'),
              child: Column(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(icon, color: color, size: 28),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: 68,
                    child: Text(
                      cat['name'] as String,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.labelSmall,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PromoBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Book Your First Appointment',
                    style: AppTextStyles.titleMedium.copyWith(color: Colors.white),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Find Doctors Near You',
                      style: AppTextStyles.labelSmall.copyWith(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const Icon(Icons.local_hospital_rounded, color: Colors.white70, size: 48),
          ],
        ),
      ),
    );
  }
}
