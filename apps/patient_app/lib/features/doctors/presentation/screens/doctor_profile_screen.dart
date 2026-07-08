import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/skeleton_loader.dart';
import '../providers/doctors_provider.dart';

class DoctorProfileScreen extends ConsumerWidget {
  const DoctorProfileScreen({super.key, required this.doctorId});
  final String doctorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doctorAsync = ref.watch(doctorDetailProvider(doctorId));

    return Scaffold(
      body: doctorAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (doctor) => _DoctorProfileView(doctor: doctor),
      ),
    );
  }
}

class _DoctorProfileView extends StatelessWidget {
  const _DoctorProfileView({required this.doctor});
  final Map<String, dynamic> doctor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final clinics = (doctor['clinics'] as List?) ?? [];
    final primaryClinic = clinics.isNotEmpty ? clinics.first as Map : null;
    final fee = (primaryClinic?['consultationFee'] as num?)?.toDouble() ?? 0;
    final clinicInfo = primaryClinic?['clinic'] as Map?;

    return CustomScrollView(
      slivers: [
        // Hero header
        SliverAppBar(
          expandedHeight: 280,
          pinned: true,
          leading: IconButton.filled(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back_rounded),
            style: IconButton.styleFrom(
              backgroundColor: Colors.black38,
              foregroundColor: Colors.white,
            ),
          ),
          actions: [
            IconButton.filled(
              onPressed: () {},
              icon: Icon(
                doctor['isFavorite'] == true ? Icons.favorite : Icons.favorite_outline,
              ),
              style: IconButton.styleFrom(
                backgroundColor: Colors.black38,
                foregroundColor: doctor['isFavorite'] == true ? AppColors.error : Colors.white,
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
                      )
                    : Container(
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
                            style: const TextStyle(fontSize: 80, color: Colors.white, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                // Gradient overlay
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black54],
                    ),
                  ),
                ),
                // Name overlay
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
                      RatingBarIndicator(
                        rating: (doctor['averageRating'] as num?)?.toDouble() ?? 0,
                        itemBuilder: (_, __) => const Icon(Icons.star_rounded, color: AppColors.warning),
                        itemCount: 5,
                        itemSize: 16,
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
                // Stats row
                Row(
                  children: [
                    _StatBox(value: '${doctor['experienceYears']}yr', label: 'Experience'),
                    const SizedBox(width: 12),
                    _StatBox(value: '${doctor['totalReviews']}', label: 'Reviews'),
                    const SizedBox(width: 12),
                    _StatBox(value: '₹${fee.toStringAsFixed(0)}', label: 'Fee'),
                  ],
                ),

                const SizedBox(height: 24),

                // About
                if (doctor['about'] != null) ...[
                  Text('About', style: AppTextStyles.titleSmall),
                  const SizedBox(height: 8),
                  Text(doctor['about'] as String, style: AppTextStyles.bodyMedium),
                  const SizedBox(height: 20),
                ],

                // Qualifications
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

                // Clinic
                if (clinicInfo != null) ...[
                  Text('Clinic', style: AppTextStyles.titleSmall),
                  const SizedBox(height: 8),
                  Container(
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
                              Text(clinicInfo['addressLine1'] as String? ?? '', style: AppTextStyles.bodySmall),
                              Text(clinicInfo['city'] as String? ?? '', style: AppTextStyles.bodySmall),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () {},
                          icon: const Icon(Icons.directions_rounded, color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(value, style: AppTextStyles.titleMedium.copyWith(color: AppColors.primary)),
            const SizedBox(height: 2),
            Text(label, style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryDark)),
          ],
        ),
      ),
    );
  }
}
