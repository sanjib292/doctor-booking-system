import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/network/api_client.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final MapController _mapController = MapController();

  LatLng? _userPosition;
  bool _locating = true;
  String? _locationError;
  List<_NearbyDoctor> _doctors = [];
  bool _loadingDoctors = false;

  _NearbyDoctor? _selectedDoctor;

  @override
  void initState() {
    super.initState();
    _fetchLocation();
  }

  Future<void> _fetchLocation() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        final fallback = const LatLng(12.9716, 77.5946);
        setState(() {
          _locationError = 'Location permission denied. Showing Bangalore.';
          _userPosition = fallback;
          _locating = false;
        });
        await _fetchDoctors(fallback);
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      final userLatLng = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _userPosition = userLatLng;
        _locating = false;
      });
      _mapController.move(userLatLng, 14.0);
      await _fetchDoctors(userLatLng);
    } catch (e) {
      final fallback = const LatLng(12.9716, 77.5946);
      setState(() {
        _userPosition = fallback;
        _locating = false;
        _locationError = 'Using default location: Bangalore';
      });
      await _fetchDoctors(fallback);
    }
  }

  Future<void> _fetchDoctors(LatLng position) async {
    setState(() => _loadingDoctors = true);
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get('/doctors', queryParameters: {
        'lat': position.latitude.toString(),
        'lng': position.longitude.toString(),
        'radiusKm': '20',
        'limit': '30',
        'page': '1',
        'sortBy': 'distance',
      });
      final list = response.data['data'] as List? ?? [];
      final doctors = <_NearbyDoctor>[];
      for (final d in list) {
        final clinics = (d['clinics'] as List?) ?? [];
        final primaryClinic = clinics.isNotEmpty ? clinics.first as Map : null;
        final clinicInfo = primaryClinic?['clinic'] as Map?;
        final lat = clinicInfo?['lat'] as num?;
        final lng = clinicInfo?['lng'] as num?;
        if (lat == null || lng == null) continue;
        doctors.add(_NearbyDoctor(
          id: d['id'] as String,
          name: d['name'] as String? ?? '',
          specialty: (d['specialization'] as String?) ??
              ((d['categories'] as List?)?.isNotEmpty == true
                  ? (d['categories'] as List).first['name'] as String? ?? ''
                  : ''),
          rating: (d['averageRating'] as num?)?.toDouble() ?? 0,
          fee: (primaryClinic?['consultationFee'] as num?)?.toInt() ?? 0,
          avatarUrl: d['avatarUrl'] as String? ?? '',
          position: LatLng(lat.toDouble(), lng.toDouble()),
        ));
      }
      setState(() => _doctors = doctors);
    } catch (_) {
      // silently fail — map still shows user location
    } finally {
      setState(() => _loadingDoctors = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final center = _userPosition ?? const LatLng(12.9716, 77.5946);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby Doctors'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            tooltip: 'My location',
            onPressed: _locating ? null : _fetchLocation,
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 14.0,
              onTap: (_, __) => setState(() => _selectedDoctor = null),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.doctorbook.patientapp',
                maxZoom: 19,
              ),

              if (_userPosition != null)
                MarkerLayer(markers: [
                  Marker(
                    point: _userPosition!,
                    width: 48,
                    height: 48,
                    child: Semantics(
                      label: 'Your location',
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withOpacity(0.4),
                              blurRadius: 12,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.person, color: Colors.white, size: 22),
                      ),
                    ),
                  ),
                ]),

              MarkerLayer(
                markers: _doctors.map((doc) {
                  final isSelected = _selectedDoctor?.id == doc.id;
                  return Marker(
                    point: doc.position,
                    width: isSelected ? 56 : 44,
                    height: isSelected ? 56 : 44,
                    child: Semantics(
                      label: 'Doctor marker: ${doc.name}',
                      button: true,
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedDoctor = doc),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.primaryContainer,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: theme.colorScheme.primary,
                              width: isSelected ? 3 : 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: theme.colorScheme.primary.withOpacity(0.3),
                                blurRadius: isSelected ? 12 : 6,
                                spreadRadius: isSelected ? 2 : 0,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.medical_services_rounded,
                            color: isSelected ? Colors.white : theme.colorScheme.primary,
                            size: isSelected ? 28 : 22,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const RichAttributionWidget(
                attributions: [
                  TextSourceAttribution('OpenStreetMap contributors'),
                ],
              ),
            ],
          ),

          if (_locating)
            const Center(child: CircularProgressIndicator()),

          if (_loadingDoctors && !_locating)
            const Positioned(
              bottom: 80,
              left: 0,
              right: 0,
              child: Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text('Loading doctors…'),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          if (_locationError != null)
            Positioned(
              top: 12,
              left: 16,
              right: 16,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade800,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.white, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _locationError!,
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _locationError = null),
                        child: const Icon(Icons.close, color: Colors.white, size: 16),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          Positioned(
            top: _locationError != null ? 56 : 12,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 6),
                ],
              ),
              child: Text(
                '${_doctors.length} doctors nearby',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ),

          if (_selectedDoctor != null)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: _DoctorCard(
                doctor: _selectedDoctor!,
                onViewProfile: () => context.push('/doctors/${_selectedDoctor!.id}'),
                onDismiss: () => setState(() => _selectedDoctor = null),
              ),
            ),
        ],
      ),
    );
  }
}

class _DoctorCard extends StatelessWidget {
  const _DoctorCard({
    required this.doctor,
    required this.onViewProfile,
    required this.onDismiss,
  });

  final _NearbyDoctor doctor;
  final VoidCallback onViewProfile;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: doctor.avatarUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: doctor.avatarUrl,
                      imageBuilder: (ctx, img) =>
                          CircleAvatar(radius: 28, backgroundImage: img),
                      placeholder: (_, __) =>
                          const CircularProgressIndicator(strokeWidth: 2),
                      errorWidget: (_, __, ___) => _initials(doctor.name),
                    )
                  : _initials(doctor.name),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    doctor.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    doctor.specialty,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, size: 14, color: Colors.amber),
                      const SizedBox(width: 3),
                      Text(
                        doctor.rating.toStringAsFixed(1),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      if (doctor.fee > 0) ...[
                        const SizedBox(width: 10),
                        Icon(Icons.currency_rupee, size: 13, color: theme.colorScheme.secondary),
                        Text('${doctor.fee}', style: const TextStyle(fontSize: 12)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: onDismiss,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: onViewProfile,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                  child: const Text('View'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _initials(String name) {
    final parts = name.split(' ');
    final initials = parts.length >= 2
        ? '${parts[0][0]}${parts[1][0]}'
        : parts[0].substring(0, 1);
    return Text(
      initials.toUpperCase(),
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
    );
  }
}

class _NearbyDoctor {
  const _NearbyDoctor({
    required this.id,
    required this.name,
    required this.specialty,
    required this.rating,
    required this.fee,
    required this.avatarUrl,
    required this.position,
  });

  final String id;
  final String name;
  final String specialty;
  final double rating;
  final int fee;
  final String avatarUrl;
  final LatLng position;
}
