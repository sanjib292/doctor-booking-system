import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/doctor_card.dart';
import '../../../../core/widgets/skeleton_loader.dart';
import '../providers/doctors_provider.dart';

class DoctorSearchScreen extends ConsumerStatefulWidget {
  const DoctorSearchScreen({
    super.key,
    this.initialCategoryId,
    this.initialCategoryName,
  });

  final String? initialCategoryId;
  final String? initialCategoryName;

  @override
  ConsumerState<DoctorSearchScreen> createState() => _DoctorSearchScreenState();
}

class _DoctorSearchScreenState extends ConsumerState<DoctorSearchScreen> {
  final _searchController = TextEditingController();
  String? _selectedSort = 'rating';
  String? _activeCategoryId;
  String? _activeCategoryName;

  @override
  void initState() {
    super.initState();
    if (widget.initialCategoryId != null) {
      _activeCategoryId = widget.initialCategoryId;
      _activeCategoryName = widget.initialCategoryName;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(doctorSearchFiltersProvider.notifier).state =
            DoctorSearchFilters(categoryId: widget.initialCategoryId);
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final doctors = ref.watch(searchedDoctorsProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Search header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      autofocus: false,
                      decoration: InputDecoration(
                        hintText: 'Search doctors, specialties...',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded),
                                onPressed: () {
                                  _searchController.clear();
                                  _updateSearch('');
                                },
                              )
                            : null,
                      ),
                      onChanged: _updateSearch,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.outlined(
                    onPressed: _showFilterSheet,
                    icon: const Icon(Icons.tune_rounded),
                    style: IconButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Active category filter chip
            if (_activeCategoryId != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Row(
                  children: [
                    FilterChip(
                      label: Text(_activeCategoryName ?? 'Category'),
                      selected: true,
                      onSelected: (_) {
                        setState(() { _activeCategoryId = null; _activeCategoryName = null; });
                        ref.read(doctorSearchFiltersProvider.notifier).state =
                            ref.read(doctorSearchFiltersProvider).copyWith(categoryId: null);
                      },
                      deleteIcon: const Icon(Icons.close, size: 14),
                      onDeleted: () {
                        setState(() { _activeCategoryId = null; _activeCategoryName = null; });
                        ref.read(doctorSearchFiltersProvider.notifier).state =
                            ref.read(doctorSearchFiltersProvider).copyWith(categoryId: null);
                      },
                    ),
                  ],
                ),
              ),

            // Sort chips
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _SortChip(label: 'Rating', value: 'rating', selected: _selectedSort == 'rating', onTap: _updateSort),
                  _SortChip(label: 'Distance', value: 'distance', selected: _selectedSort == 'distance', onTap: _updateSort),
                  _SortChip(label: 'Experience', value: 'experience', selected: _selectedSort == 'experience', onTap: _updateSort),
                  _SortChip(label: 'Fee ↑', value: 'fee_asc', selected: _selectedSort == 'fee_asc', onTap: _updateSort),
                  _SortChip(label: 'Fee ↓', value: 'fee_desc', selected: _selectedSort == 'fee_desc', onTap: _updateSort),
                ],
              ),
            ),

            const SizedBox(height: 4),

            // Results
            Expanded(
              child: doctors.when(
                loading: () => ListView.builder(
                  itemCount: 6,
                  itemBuilder: (_, __) => const DoctorCardSkeleton(),
                ),
                error: (e, _) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: AppColors.error),
                      const SizedBox(height: 16),
                      Text('Something went wrong', style: AppTextStyles.titleMedium),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => ref.refresh(searchedDoctorsProvider),
                        child: const Text('Try Again'),
                      ),
                    ],
                  ),
                ),
                data: (docs) => docs.isEmpty
                    ? _EmptyState()
                    : ListView.builder(
                        itemCount: docs.length,
                        itemBuilder: (_, i) {
                          final doc = docs[i];
                          final clinic = (doc['clinics'] as List?)?.firstOrNull as Map?;
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
                            distance: (doc['distance'] as num?)?.toDouble(),
                            onTap: () => context.pushNamed(
                              'doctorProfile',
                              pathParameters: {'id': doc['id'] as String},
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _updateSearch(String value) {
    ref.read(doctorSearchFiltersProvider.notifier).state =
        ref.read(doctorSearchFiltersProvider).copyWithSearch(value);
  }

  void _updateSort(String value) {
    setState(() => _selectedSort = value);
    ref.read(doctorSearchFiltersProvider.notifier).state =
        ref.read(doctorSearchFiltersProvider).copyWithSort(value);
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _FilterSheet(),
    );
  }

  String _getSpecialty(Map<String, dynamic> doc) {
    final cats = doc['categories'] as List?;
    if (cats == null || cats.isEmpty) return 'General Physician';
    final primary = cats.firstWhere((c) => c['isPrimary'] == true, orElse: () => cats.first);
    return (primary['category'] as Map?)?['name'] as String? ?? 'Specialist';
  }
}

extension on DoctorSearchFilters {
  DoctorSearchFilters copyWithSearch(String? search) => DoctorSearchFilters(
    search: search,
    categoryId: categoryId,
    minRating: minRating,
    maxFee: maxFee,
    minFee: minFee,
    gender: gender,
    city: city,
    sortBy: sortBy,
  );

  DoctorSearchFilters copyWithSort(String sort) => DoctorSearchFilters(
    search: search,
    categoryId: categoryId,
    minRating: minRating,
    maxFee: maxFee,
    minFee: minFee,
    gender: gender,
    city: city,
    sortBy: sort,
  );
}

class _SortChip extends StatelessWidget {
  const _SortChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String value;
  final bool selected;
  final void Function(String) onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(value),
        selectedColor: AppColors.primaryContainer,
        labelStyle: AppTextStyles.labelMedium.copyWith(
          color: selected ? AppColors.primary : null,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 80,
            color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.4),
          ),
          const SizedBox(height: 16),
          Text('No doctors found', style: AppTextStyles.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your search or filters',
            style: AppTextStyles.bodyMedium.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterSheet extends ConsumerStatefulWidget {
  const _FilterSheet();

  @override
  ConsumerState<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<_FilterSheet> {
  String? _gender;
  double _minRating = 0;
  RangeValues _feeRange = const RangeValues(0, 5000);
  final _cityController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Filters', style: AppTextStyles.titleLarge),
              TextButton(
                onPressed: () => setState(() {
                  _gender = null; _minRating = 0;
                  _feeRange = const RangeValues(0, 5000);
                  _cityController.clear();
                }),
                child: const Text('Reset'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Rating', style: AppTextStyles.labelMedium),
          Slider(
            value: _minRating,
            min: 0, max: 5, divisions: 10,
            label: _minRating == 0 ? 'Any' : '${_minRating.toStringAsFixed(1)}+',
            onChanged: (v) => setState(() => _minRating = v),
          ),
          const SizedBox(height: 16),
          Text('Fee Range (₹)', style: AppTextStyles.labelMedium),
          RangeSlider(
            values: _feeRange,
            min: 0, max: 5000, divisions: 50,
            labels: RangeLabels('₹${_feeRange.start.toInt()}', '₹${_feeRange.end.toInt()}'),
            onChanged: (v) => setState(() => _feeRange = v),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              ref.read(doctorSearchFiltersProvider.notifier).state = DoctorSearchFilters(
                minRating: _minRating > 0 ? _minRating : null,
                minFee: _feeRange.start > 0 ? _feeRange.start : null,
                maxFee: _feeRange.end < 5000 ? _feeRange.end : null,
                gender: _gender,
                city: _cityController.text.trim().isNotEmpty ? _cityController.text.trim() : null,
              );
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 52)),
            child: const Text('Apply Filters'),
          ),
        ],
      ),
    );
  }
}
