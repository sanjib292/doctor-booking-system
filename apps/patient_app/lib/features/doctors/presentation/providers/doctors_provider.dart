import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../core/network/api_client.dart';

final locationProvider = FutureProvider<Position?>((ref) async {
  try {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      final requested = await Geolocator.requestPermission();
      if (requested == LocationPermission.denied ||
          requested == LocationPermission.deniedForever) {
        return null;
      }
    }
    if (permission == LocationPermission.deniedForever) return null;

    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 10),
    );
  } catch (_) {
    return null;
  }
});

final categoriesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/doctors/categories');
  return List<Map<String, dynamic>>.from(response.data['data'] as List);
});

final nearbyDoctorsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final dio = ref.watch(dioProvider);
  final location = await ref.watch(locationProvider.future);

  final params = <String, dynamic>{
    'limit': '20',
    'page': '1',
    'sortBy': 'rating',
  };

  if (location != null) {
    params['lat'] = location.latitude.toString();
    params['lng'] = location.longitude.toString();
    params['radiusKm'] = '10';
    params['sortBy'] = 'distance';
  }

  final response = await dio.get('/doctors', queryParameters: params);
  return List<Map<String, dynamic>>.from(response.data['data'] as List);
});

final doctorSearchFiltersProvider = StateProvider<DoctorSearchFilters>(
  (_) => const DoctorSearchFilters(),
);

class DoctorSearchFilters {
  const DoctorSearchFilters({
    this.search,
    this.categoryId,
    this.minRating,
    this.maxFee,
    this.minFee,
    this.gender,
    this.city,
    this.sortBy = 'rating',
    this.page = 1,
  });

  final String? search;
  final String? categoryId;
  final double? minRating;
  final double? maxFee;
  final double? minFee;
  final String? gender;
  final String? city;
  final String sortBy;
  final int page;

  Map<String, dynamic> toQueryParams() => {
    if (search != null && search!.isNotEmpty) 'search': search,
    if (categoryId != null) 'categoryId': categoryId,
    if (minRating != null) 'minRating': minRating.toString(),
    if (maxFee != null) 'maxFee': maxFee.toString(),
    if (minFee != null) 'minFee': minFee.toString(),
    if (gender != null) 'gender': gender,
    if (city != null && city!.isNotEmpty) 'city': city,
    'sortBy': sortBy,
    'page': page.toString(),
    'limit': '20',
  };
}

final searchedDoctorsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final dio = ref.watch(dioProvider);
  final filters = ref.watch(doctorSearchFiltersProvider);

  final response = await dio.get('/doctors', queryParameters: filters.toQueryParams());
  return List<Map<String, dynamic>>.from(response.data['data'] as List);
});

final doctorDetailProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>(
  (ref, doctorId) async {
    final dio = ref.watch(dioProvider);
    final response = await dio.get('/doctors/$doctorId');
    return response.data['data'] as Map<String, dynamic>;
  },
);

// Phase 2: Doctor availability (which days of week are they available)
final doctorAvailabilityProvider =
    FutureProvider.autoDispose.family<Set<String>, String>((ref, doctorId) async {
  final dio = ref.watch(dioProvider);
  try {
    final response = await dio.get('/doctors/$doctorId/availability');
    final data = response.data['data'] as List? ?? [];
    return data.map((a) => a['dayOfWeek'] as String).toSet();
  } catch (_) {
    // Fallback: return weekdays if endpoint doesn't exist yet
    return {'MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY'};
  }
});

// Phase 2: Notifier for toggling favorites
class DoctorsNotifier extends Notifier<void> {
  @override
  void build() {}

  Future<void> toggleFavorite(String doctorId) async {
    final dio = ref.read(dioProvider);
    await dio.post('/users/me/favorites/$doctorId');
    ref.invalidate(doctorDetailProvider(doctorId));
  }
}

final doctorsProviderFamily = NotifierProvider<DoctorsNotifier, void>(DoctorsNotifier.new);
