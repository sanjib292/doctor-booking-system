import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Nearby doctors map screen using OpenStreetMap via flutter_map.
/// No API key required — tiles served by OpenStreetMap.org.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();

  LatLng? _userPosition;
  bool _locating = true;
  String? _locationError;

  // Nearby doctors — in production fetched from GET /doctors?lat=&lng=&radius=10
  final List<_NearbyDoctor> _doctors = [
    _NearbyDoctor(
      id: 'seed-doc-1',
      name: 'Dr. Rajesh Sharma',
      specialty: 'Cardiology',
      rating: 4.8,
      fee: 800,
      avatarUrl: '',
      position: const LatLng(12.9716, 77.5946),
    ),
    _NearbyDoctor(
      id: 'seed-doc-2',
      name: 'Dr. Priya Nair',
      specialty: 'Dermatology',
      rating: 4.6,
      fee: 600,
      avatarUrl: '',
      position: const LatLng(12.9756, 77.5986),
    ),
    _NearbyDoctor(
      id: 'seed-doc-3',
      name: 'Dr. Arjun Mehta',
      specialty: 'General Physician',
      rating: 4.4,
      fee: 400,
      avatarUrl: '',
      position: const LatLng(12.9680, 77.5900),
    ),
    _NearbyDoctor(
      id: 'seed-doc-4',
      name: 'Dr. Kavitha Rao',
      specialty: 'Pediatrics',
      rating: 4.9,
      fee: 700,
      avatarUrl: '',
      position: const LatLng(12.9740, 77.5870),
    ),
  ];

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
        setState(() {
          _locationError = 'Location permission denied. Showing Bangalore.';
          _userPosition = const LatLng(12.9716, 77.5946);
          _locating = false;
        });
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      setState(() {
        _userPosition = LatLng(pos.latitude, pos.longitude);
        _locating = false;
      });
      _mapController.move(_userPosition!, 14.0);
    } catch (e) {
      // Fallback to Bangalore city centre
      setState(() {
        _userPosition = const LatLng(12.9716, 77.5946);
        _locating = false;
        _locationError = 'Using default location: Bangalore';
      });
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
          // ── Map ──
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 14.0,
              onTap: (_, __) => setState(() => _selectedDoctor = null),
            ),
            children: [
              // OpenStreetMap tile layer — no API key needed
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.ambytechnologies.patientapp',
                maxZoom: 19,
              ),

              // User location marker
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

              // Doctor markers
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
                            color: isSelected
                                ? Colors.white
                                : theme.colorScheme.primary,
                            size: isSelected ? 28 : 22,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              // OSM attribution (required by tile terms)
              const RichAttributionWidget(
                attributions: [
                  TextSourceAttribution('OpenStreetMap contributors'),
                ],
              ),
            ],
          ),

          // ── Loading overlay ──
          if (_locating)
            const Center(child: CircularProgressIndicator()),

          // ── Location error snack ──
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

          // ── Doctor count chip ──
          Positioned(
            top: _locationError != null ? 56 : 12,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 6,
                  ),
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

          // ── Selected doctor card ──
          if (_selectedDoctor != null)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: _DoctorCard(
                doctor: _selectedDoctor!,
                onViewProfile: () => context.push('/doctor/${_selectedDoctor!.id}'),
                onDismiss: () => setState(() => _selectedDoctor = null),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Doctor card shown at bottom of map ─────────────────────────────────────

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
            // Avatar
            CircleAvatar(
              radius: 28,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: doctor.avatarUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: doctor.avatarUrl,
                      imageBuilder: (ctx, img) => CircleAvatar(radius: 28, backgroundImage: img),
                      placeholder: (_, __) => const CircularProgressIndicator(strokeWidth: 2),
                      errorWidget: (_, __, ___) => _initials(doctor.name),
                    )
                  : _initials(doctor.name),
            ),
            const SizedBox(width: 14),
            // Info
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
                        '${doctor.rating}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 10),
                      Icon(Icons.currency_rupee, size: 13, color: theme.colorScheme.secondary),
                      Text(
                        '${doctor.fee}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Actions
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

// ── Data model ─────────────────────────────────────────────────────────────

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
