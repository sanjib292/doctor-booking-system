import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../providers/doctors_provider.dart';

/// Full-screen map view of nearby doctors.
/// Requires a Google Maps API key in AndroidManifest.xml:
///   <meta-data android:name="com.google.android.geo.API_KEY"
///              android:value="YOUR_API_KEY"/>
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  GoogleMapController? _mapController;
  String? _selectedDoctorId;

  static const _defaultCenter = LatLng(28.6139, 77.2090); // Delhi

  @override
  Widget build(BuildContext context) {
    final doctorsAsync = ref.watch(nearbyDoctorsProvider);
    final locationAsync = ref.watch(locationProvider);

    final initialPosition = locationAsync.whenData(
      (pos) => pos != null
          ? LatLng(pos.latitude, pos.longitude)
          : _defaultCenter,
    );

    return Scaffold(
      body: Stack(
        children: [
          // ── Map ─────────────────────────────────────────────────
          doctorsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => _buildMap(const {}, initialPosition.value ?? _defaultCenter),
            data: (doctors) {
              final markers = _buildMarkers(doctors);
              return _buildMap(markers, initialPosition.value ?? _defaultCenter);
            },
          ),

          // ── App bar overlay ──────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Semantics(
                    label: 'Go back',
                    child: FloatingActionButton.small(
                      heroTag: 'back',
                      onPressed: () => context.pop(),
                      backgroundColor: Theme.of(context).colorScheme.surface,
                      child: Icon(
                        Icons.arrow_back_rounded,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Material(
                      borderRadius: BorderRadius.circular(12),
                      elevation: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Nearby Doctors',
                          style: AppTextStyles.titleSmall,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Selected doctor card ─────────────────────────────────
          if (_selectedDoctorId != null)
            Align(
              alignment: Alignment.bottomCenter,
              child: _DoctorBottomCard(
                doctorId: _selectedDoctorId!,
                onClose: () => setState(() => _selectedDoctorId = null),
                onViewProfile: () {
                  context.pushNamed(
                    'doctorProfile',
                    pathParameters: {'id': _selectedDoctorId!},
                  );
                },
              ),
            ),

          // ── My location FAB ──────────────────────────────────────
          Positioned(
            right: 16,
            bottom: _selectedDoctorId != null ? 200 : 24,
            child: Semantics(
              label: 'Center map on my location',
              child: FloatingActionButton.small(
                heroTag: 'myLocation',
                onPressed: () {
                  final pos = locationAsync.value;
                  if (pos != null && _mapController != null) {
                    _mapController!.animateCamera(
                      CameraUpdate.newLatLngZoom(
                        LatLng(pos.latitude, pos.longitude),
                        14,
                      ),
                    );
                  }
                },
                child: const Icon(Icons.my_location_rounded),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMap(Set<Marker> markers, LatLng center) {
    return GoogleMap(
      initialCameraPosition: CameraPosition(target: center, zoom: 13),
      markers: markers,
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      onMapCreated: (c) => _mapController = c,
      onTap: (_) => setState(() => _selectedDoctorId = null),
    );
  }

  Set<Marker> _buildMarkers(List<Map<String, dynamic>> doctors) {
    return doctors
        .where((d) {
          final clinics = d['clinics'] as List?;
          if (clinics == null || clinics.isEmpty) return false;
          final clinic = (clinics.first as Map)['clinic'] as Map?;
          return clinic?['lat'] != null && clinic?['lng'] != null;
        })
        .map((d) {
          final clinic =
              ((d['clinics'] as List).first as Map)['clinic'] as Map;
          final lat = (clinic['lat'] as num).toDouble();
          final lng = (clinic['lng'] as num).toDouble();
          final id = d['id'] as String;

          return Marker(
            markerId: MarkerId(id),
            position: LatLng(lat, lng),
            infoWindow: InfoWindow(title: 'Dr. ${d['name']}'),
            onTap: () => setState(() => _selectedDoctorId = id),
          );
        })
        .toSet();
  }
}

// ── Doctor bottom card ────────────────────────────────────────────────────

class _DoctorBottomCard extends ConsumerWidget {
  const _DoctorBottomCard({
    required this.doctorId,
    required this.onClose,
    required this.onViewProfile,
  });

  final String doctorId;
  final VoidCallback onClose;
  final VoidCallback onViewProfile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doctorAsync = ref.watch(doctorDetailProvider(doctorId));

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Material(
        borderRadius: BorderRadius.circular(20),
        elevation: 8,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: doctorAsync.when(
            loading: () => const SizedBox(
              height: 80,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, __) => const SizedBox(height: 80),
            data: (doctor) {
              final clinics = doctor['clinics'] as List? ?? [];
              final fee = clinics.isNotEmpty
                  ? (clinics.first as Map)['consultationFee'] as num?
                  : null;
              final category = _getCategory(doctor);

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      // Avatar
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: AppColors.primaryContainer,
                        child: Text(
                          (doctor['name'] as String).substring(0, 1).toUpperCase(),
                          style: AppTextStyles.titleMedium
                              .copyWith(color: AppColors.primary),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Dr. ${doctor['name']}',
                                style: AppTextStyles.titleSmall),
                            Text(category, style: AppTextStyles.bodySmall),
                            if (fee != null)
                              Text('₹${fee.toStringAsFixed(0)} per visit',
                                  style: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.primary)),
                          ],
                        ),
                      ),
                      Semantics(
                        label: 'Close doctor card',
                        child: IconButton(
                          onPressed: onClose,
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: onViewProfile,
                      child: const Text('View Profile & Book'),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  String _getCategory(Map<String, dynamic> doc) {
    final cats = doc['categories'] as List?;
    if (cats == null || cats.isEmpty) return 'General Physician';
    final primary = cats.firstWhere(
      (c) => c['isPrimary'] == true,
      orElse: () => cats.first,
    );
    return (primary['category'] as Map?)?['name'] as String? ?? 'Specialist';
  }
}
