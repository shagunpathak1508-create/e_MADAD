import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../theme/app_theme.dart';
import '../services/location_service.dart';
import '../services/nearby_service.dart';
import '../services/connectivity_service.dart';
import '../services/sms_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  LatLng? _myLocation;
  bool _loading = true;
  bool _isOnline = true;
  List<NearbyPlace> _nearby = [];
  List<LatLng> _trail = [];
  NearbyPlace? _selected;
  String _emergencyType = 'Medical';
  String? _lastUpdated;
  String? _predictedDirection;

  final _mapController = MapController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _emergencyType =
        ModalRoute.of(context)?.settings.arguments as String? ?? 'Medical';
    _init();
  }

  Future<void> _init() async {
    _isOnline = await ConnectivityService.checkOnline();
    final pos = await LocationService.getCurrentLocation();
    final trail = await LocationService.getTrail();
    final direction = await LocationService.predictDirection();

    setState(() {
      if (pos != null) {
        _myLocation = LatLng(pos.latitude, pos.longitude);
      }
      _trail = trail.map((p) => LatLng(p['lat'], p['lng'])).toList();
      _predictedDirection = direction;
      _loading = false;
    });

    if (_myLocation != null) {
      _mapController.move(_myLocation!, 14.5);
      if (_isOnline) {
        final places = await NearbyService.fetchNearby(
          lat: _myLocation!.latitude,
          lng: _myLocation!.longitude,
          emergencyType: _emergencyType,
        );
        if (mounted) setState(() => _nearby = places);
      }
    }

    // Check last known if offline
    if (!_isOnline) {
      final last = await LocationService.getLastKnownLocation();
      if (last != null && mounted) {
        setState(() {
          _lastUpdated = _formatAgo(
              DateTime.fromMillisecondsSinceEpoch(last['ts'] as int));
        });
      }
    }
  }

  String _formatAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    return '${diff.inHours}h ago';
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'hospital': return Icons.local_hospital_rounded;
      case 'fire_station': return Icons.local_fire_department_rounded;
      case 'police': return Icons.local_police_rounded;
      case 'shelter': return Icons.home_rounded;
      default: return Icons.place_rounded;
    }
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'hospital': return AppTheme.danger;
      case 'fire_station': return Colors.deepOrange;
      case 'police': return Colors.indigo;
      case 'shelter': return AppTheme.green;
      default: return AppTheme.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ── Map ────────────────────────────────────────────────
          if (_loading)
            const Center(
                child: CircularProgressIndicator(color: AppTheme.orange))
          else
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _myLocation ?? const LatLng(19.076, 72.877),
                initialZoom: 14.5,
                onTap: (_, __) => setState(() => _selected = null),
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.emadad.app',
                ),
                // Trail polyline
                if (_trail.length > 1)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _trail,
                        strokeWidth: 3,
                        color: AppTheme.orange.withOpacity(0.7),
                        pattern: const StrokePattern.dotted(),
                      ),
                    ],
                  ),
                // Markers
                MarkerLayer(
                  markers: [
                    // My location
                    if (_myLocation != null)
                      Marker(
                        point: _myLocation!,
                        width: 48, height: 48,
                        child: Column(
                          children: [
                            Container(
                              width: 32, height: 32,
                              decoration: BoxDecoration(
                                color: AppTheme.orange,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2.5),
                                boxShadow: [
                                  BoxShadow(
                                      color: AppTheme.orange.withOpacity(0.4),
                                      blurRadius: 10)
                                ],
                              ),
                              child: const Icon(Icons.person_pin_rounded,
                                  color: Colors.white, size: 18),
                            ),
                            const Text('You',
                                style: TextStyle(
                                    fontSize: 10, fontWeight: FontWeight.w700,
                                    color: AppTheme.orange)),
                          ],
                        ),
                      ),
                    // Nearby places
                    ..._nearby.map((p) {
                      final color = _colorForType(p.type);
                      return Marker(
                        point: LatLng(p.lat, p.lng),
                        width: 40, height: 40,
                        child: GestureDetector(
                          onTap: () => setState(() => _selected = p),
                          child: Container(
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                    color: color.withOpacity(0.4),
                                    blurRadius: 8)
                              ],
                            ),
                            child: Icon(_iconForType(p.type),
                                color: Colors.white, size: 16),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ],
            ),

          // ── Top bar ───────────────────────────────────────────
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(
              child: Column(
                children: [
                  // Offline banner
                  if (!_isOnline)
                    Container(
                      color: AppTheme.danger,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.wifi_off_rounded,
                              color: Colors.white, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'User is offline · Last updated ${_lastUpdated ?? "unknown"}'
                            '${_predictedDirection != null ? " · Moving $_predictedDirection" : ""}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),

                  // App bar row
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 8)
                                ]),
                            child: const Icon(Icons.arrow_back_ios_new_rounded,
                                size: 18),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                      color: Colors.black.withOpacity(0.08),
                                      blurRadius: 10)
                                ]),
                            child: Text(
                              '$_emergencyType Emergency — Nearby Services',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 13),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Selected place popup ──────────────────────────────
          if (_selected != null)
            Positioned(
              bottom: 100, left: 16, right: 16,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 20, offset: const Offset(0, 4))
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                          color: _colorForType(_selected!.type)
                              .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12)),
                      child: Icon(_iconForType(_selected!.type),
                          color: _colorForType(_selected!.type)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_selected!.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 14),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          Text(
                              '${_selected!.distanceMeters.toInt()}m · ~${_selected!.estimatedMinutes} min',
                              style: TextStyle(
                                  color: AppTheme.textGrey, fontSize: 12)),
                        ],
                      ),
                    ),
                    if (_selected!.phone != null)
                      GestureDetector(
                        onTap: () => SmsService.callNumber(_selected!.phone!),
                        child: Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                              color: AppTheme.green,
                              borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.phone_rounded,
                              color: Colors.white, size: 18),
                        ),
                      ),
                  ],
                ),
              ),
            ),

          // ── Bottom legend ─────────────────────────────────────
          Positioned(
            bottom: 20, left: 16, right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.08), blurRadius: 10)
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _LegendDot(color: AppTheme.orange, label: 'You'),
                  _LegendDot(color: AppTheme.danger, label: 'Hospital'),
                  _LegendDot(color: Colors.indigo, label: 'Police'),
                  _LegendDot(color: Colors.deepOrange, label: 'Fire Dept'),
                  _LegendDot(color: AppTheme.green, label: 'Shelter'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
            width: 10, height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
