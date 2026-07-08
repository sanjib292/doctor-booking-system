import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/doctor_card.dart';
import '../../../../core/widgets/skeleton_loader.dart';
import '../../../doctors/presentation/providers/doctors_provider.dart';

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

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.refresh(nearbyDoctorsProvider.future),
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
                                  'Good morning 👋',
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
                          IconButton.filled(
                            onPressed: () => context.pushNamed('notifications'),
                            icon: const Icon(Icons.notifications_outlined),
                            style: IconButton.styleFrom(
                              backgroundColor: theme.colorScheme.surfaceContainerHighest,
                              foregroundColor: theme.colorScheme.onSurface,
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
                    child: Icon(Icons.medical_services_outlined, color: color, size: 28),
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
      height: 120,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Book Your First\nAppointment',
                  style: AppTextStyles.titleMedium.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 8),
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
          const Icon(Icons.local_hospital_rounded, color: Colors.white, size: 60),
        ],
      ),
    );
  }
}
