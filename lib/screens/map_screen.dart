import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../theme/app_theme.dart';
import '../services/location_service.dart';
import '../services/nearby_service.dart';
import '../services/connectivity_service.dart';
import '../services/sms_service.dart';
import '../services/cache_service.dart';
import '../services/firestore_service.dart';
import '../services/demo_service.dart';
import '../models/volunteer_model.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // ── State ────────────────────────────────────────────────────────────────
  LatLng? _myLocation;
  LatLng? _victimLocation;
  bool _isOnline = true;
  bool _isLoading = true;
  List<NearbyPlace> _nearby = [];
  List<VolunteerModel> _volunteers = [];
  List<LatLng> _trail = [];
  NearbyPlace? _selectedPlace;
  VolunteerModel? _selectedVolunteer;
  String _emergencyType = 'Medical';
  String? _predictedDirection;
  bool _isInit = false;

  final _mapController = MapController();
  StreamSubscription<List<VolunteerModel>>? _volunteerSub;

  // ── Arg parsing ──────────────────────────────────────────────────────────
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInit) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map) {
        _emergencyType = (args['type'] as String?) ?? 'Medical';
        final vLat = args['victimLat'];
        final vLng = args['victimLng'];
        if (vLat != null && vLng != null &&
            (vLat as num) != 0 && (vLng as num) != 0) {
          _victimLocation = LatLng(vLat.toDouble(), vLng.toDouble());
        }
      } else if (args is String) {
        _emergencyType = args;
      }
      _isInit = true;
      _init();
    }
  }

  // ── Initialisation ───────────────────────────────────────────────────────
  Future<void> _init() async {
    // Step 1: Show dummy data IMMEDIATELY so map never looks blank
    _applyDemoFallback();

    // Step 2: Restore cached trail & direction (cheap, local reads)
    _loadTrail();

    // Step 3: Get connectivity
    final online = await ConnectivityService.checkOnline();
    if (mounted) setState(() => _isOnline = online);

    // Step 4: Get location (non-null, always returns a position)
    final pos = await LocationService.getCurrentLocation();
    if (!mounted) return;

    final myLoc = LatLng(pos.latitude, pos.longitude);
    setState(() {
      _myLocation = myLoc;
      _isLoading = false;
    });

    // Step 5: Move camera (victim location takes priority for volunteer flow)
    try {
      _mapController.move(_victimLocation ?? myLoc, 14.5);
    } catch (_) {}

    // Step 6: Load cached nearby places for instant display
    final cached = await CacheService.getCachedHospitals();
    if (mounted && cached.isNotEmpty) {
      setState(() => _nearby = cached);
    } else if (mounted && _nearby.isEmpty) {
      // If no cache, fall back to demo places centred on current location
      setState(() => _nearby = DemoService.dummyNearbyPlaces(
          fromLat: pos.latitude, fromLng: pos.longitude,
          emergencyType: _emergencyType));
    }

    // Step 7: Fetch fresh nearby services in background
    NearbyService.fetchNearby(
      lat: pos.latitude, lng: pos.longitude,
      emergencyType: _emergencyType,
    ).then((places) {
      if (mounted && places.isNotEmpty) {
        setState(() => _nearby = places);
        CacheService.cacheHospitals(places);
      }
    }).catchError((_) {});

    // Step 8: Subscribe to live volunteer stream (Firestore handles offline)
    _volunteerSub?.cancel();
    _volunteerSub = FirestoreService.nearbyVolunteers(
      pos.latitude, pos.longitude, 10,
    ).listen((vols) {
      if (!mounted) return;
      if (vols.isNotEmpty) {
        setState(() => _volunteers = vols);
        CacheService.cacheVolunteers(vols);
      } else {
        // Firestore offline / empty → keep showing demo volunteers
        _applyDemoFallback();
      }
    });
  }

  void _applyDemoFallback() {
    if (!mounted) return;
    // Use cached first, else demo
    CacheService.getCachedVolunteers().then((cached) {
      if (mounted) {
        setState(() {
          if (cached.isNotEmpty) {
            _volunteers = cached;
          } else if (_volunteers.isEmpty) {
            _volunteers = DemoService.filteredVolunteers(_emergencyType);
          }
          if (_nearby.isEmpty) {
            _nearby = DemoService.dummyNearbyPlaces(
                emergencyType: _emergencyType);
          }
          _isLoading = false;
        });
      }
    });
  }

  Future<void> _loadTrail() async {
    final trail = await LocationService.getTrail();
    final dir   = await LocationService.predictDirection();
    if (mounted) {
      setState(() {
        _trail = trail
            .map((p) => LatLng(p['lat'] as double, p['lng'] as double))
            .toList();
        _predictedDirection = dir;
      });
    }
  }

  @override
  void dispose() {
    _volunteerSub?.cancel();
    super.dispose();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────
  double _distanceTo(double lat, double lng) {
    if (_myLocation == null) return 0;
    return LocationService.distanceBetween(
        _myLocation!.latitude, _myLocation!.longitude, lat, lng);
  }

  void _clearSelection() =>
      setState(() => _selectedPlace = _selectedVolunteer = null);

  IconData _iconForType(String type) {
    switch (type) {
      case 'hospital':     return Icons.local_hospital_rounded;
      case 'fire_station': return Icons.local_fire_department_rounded;
      case 'police':       return Icons.local_police_rounded;
      case 'shelter':      return Icons.home_rounded;
      default:             return Icons.place_rounded;
    }
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'hospital':     return Colors.blue;
      case 'fire_station': return Colors.deepOrange;
      case 'police':       return Colors.indigo;
      case 'shelter':      return Colors.teal;
      default:             return Colors.blueGrey;
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final defaultCenter = _victimLocation ??
        _myLocation ??
        const LatLng(DemoService.baseLat, DemoService.baseLng);

    return Scaffold(
      body: Stack(
        children: [
          // ── FlutterMap ─────────────────────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: defaultCenter,
              initialZoom: 14.5,
              onTap: (_, __) => _clearSelection(),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.emadad.emadad',
                // Fallback tile for emulators with slow network
                fallbackUrl: 'https://a.tile.openstreetmap.org/{z}/{x}/{y}.png',
              ),

              // Trail polyline
              if (_trail.length > 1)
                PolylineLayer(polylines: [
                  Polyline(
                    points: _trail,
                    strokeWidth: 3,
                    color: AppTheme.orange.withValues(alpha: 0.7),
                    pattern: const StrokePattern.dotted(),
                  ),
                ]),

              // Markers
              MarkerLayer(markers: [

                // YOUR location — RED
                if (_myLocation != null)
                  Marker(
                    point: _myLocation!,
                    width: 56, height: 56,
                    child: _MyLocationMarker(),
                  ),

                // VICTIM location (volunteer flow) — AMBER pulsing
                if (_victimLocation != null)
                  Marker(
                    point: _victimLocation!,
                    width: 60, height: 60,
                    child: _VictimMarker(),
                  ),

                // VOLUNTEER markers — GREEN
                ..._volunteers.map((vol) => Marker(
                  point: LatLng(vol.lat, vol.lng),
                  width: 44, height: 44,
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _selectedPlace = null;
                      _selectedVolunteer = vol;
                    }),
                    child: _VolunteerMarker(selected: _selectedVolunteer?.id == vol.id),
                  ),
                )),

                // NEARBY SERVICE markers — coloured by type
                ..._nearby.map((p) {
                  final color = _colorForType(p.type);
                  return Marker(
                    point: LatLng(p.lat, p.lng),
                    width: 44, height: 44,
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _selectedVolunteer = null;
                        _selectedPlace = p;
                      }),
                      child: _ServiceMarker(icon: _iconForType(p.type), color: color),
                    ),
                  );
                }),
              ]),
            ],
          ),

          // ── Loading shimmer ─────────────────────────────────────────────
          if (_isLoading)
            Positioned.fill(
              child: Container(
                color: Colors.white.withValues(alpha: 0.7),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: AppTheme.orange, strokeWidth: 2),
                      SizedBox(height: 12),
                      Text('Loading map…', style: TextStyle(fontSize: 13, color: AppTheme.textGrey)),
                    ],
                  ),
                ),
              ),
            ),

          // ── Top bar ─────────────────────────────────────────────────────
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(
              child: Column(children: [
                if (!_isOnline)
                  Container(
                    color: AppTheme.danger,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Row(children: [
                      const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 14),
                      const SizedBox(width: 8),
                      Expanded(child: Text(
                        'Offline — showing cached data'
                        '${_predictedDirection != null ? " · Moving $_predictedDirection" : ""}',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                      )),
                    ]),
                  ),

                // App bar
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(children: [
                    // Back button
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8)],
                        ),
                        child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Title pill
                    Expanded(child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10)],
                      ),
                      child: Text(
                        _victimLocation != null
                            ? '$_emergencyType Emergency · Navigating to Victim'
                            : '$_emergencyType Emergency · Nearby Services',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    )),

                    // Re-centre button
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        if (_myLocation != null) {
                          _mapController.move(_victimLocation ?? _myLocation!, 14.5);
                        }
                      },
                      child: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8)],
                        ),
                        child: const Icon(Icons.my_location_rounded, size: 20, color: AppTheme.orange),
                      ),
                    ),
                  ]),
                ),

                // Stats bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8)],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _InfoPill(icon: Icons.people_rounded, color: AppTheme.green,
                            label: '${_volunteers.length} Volunteers'),
                        _InfoPill(icon: Icons.local_hospital_rounded, color: Colors.blue,
                            label: '${_nearby.length} Services'),
                        if (_victimLocation != null && _myLocation != null)
                          _InfoPill(icon: Icons.place_rounded, color: Colors.amber,
                              label: '${(_distanceTo(_victimLocation!.latitude, _victimLocation!.longitude) / 1000).toStringAsFixed(1)} km'),
                      ],
                    ),
                  ),
                ),
              ]),
            ),
          ),

          // ── Volunteer popup ──────────────────────────────────────────────
          if (_selectedVolunteer != null)
            Positioned(
              bottom: 80, left: 16, right: 16,
              child: _VolunteerPopup(
                vol: _selectedVolunteer!,
                distance: _distanceTo(_selectedVolunteer!.lat, _selectedVolunteer!.lng),
                emergencyType: _emergencyType,
              ),
            ),

          // ── Service popup ────────────────────────────────────────────────
          if (_selectedPlace != null)
            Positioned(
              bottom: 80, left: 16, right: 16,
              child: _ServicePopup(
                place: _selectedPlace!,
                iconForType: _iconForType,
                colorForType: _colorForType,
              ),
            ),

          // ── Bottom legend ─────────────────────────────────────────────────
          Positioned(
            bottom: 16, left: 16, right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10)],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _LegendDot(color: AppTheme.danger, label: 'You'),
                  _LegendDot(color: Colors.amber,     label: 'Emergency'),
                  _LegendDot(color: AppTheme.green,   label: 'Volunteer'),
                  _LegendDot(color: Colors.blue,      label: 'Services'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Marker widgets ────────────────────────────────────────────────────────────

class _MyLocationMarker extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Column(children: [
    Container(
      width: 36, height: 36,
      decoration: BoxDecoration(
        color: AppTheme.danger, shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: [BoxShadow(color: AppTheme.danger.withValues(alpha: 0.5), blurRadius: 12)],
      ),
      child: const Icon(Icons.person_pin_rounded, color: Colors.white, size: 20),
    ),
    const Text('You', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.danger)),
  ]);
}

class _VictimMarker extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Column(children: [
    Container(
      width: 40, height: 40,
      decoration: BoxDecoration(
        color: Colors.amber, shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [BoxShadow(color: Colors.amber.withValues(alpha: 0.7), blurRadius: 14, spreadRadius: 2)],
      ),
      child: const Icon(Icons.warning_rounded, color: Colors.white, size: 24),
    ),
    const Text('EMERGENCY', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.amber)),
  ]);
}

class _VolunteerMarker extends StatelessWidget {
  final bool selected;
  const _VolunteerMarker({this.selected = false});
  @override
  Widget build(BuildContext context) => Container(
    width: selected ? 40 : 34, height: selected ? 40 : 34,
    decoration: BoxDecoration(
      color: selected ? AppTheme.orange : AppTheme.green,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 2),
      boxShadow: [BoxShadow(
          color: (selected ? AppTheme.orange : AppTheme.green).withValues(alpha: 0.5),
          blurRadius: 8)],
    ),
    child: const Icon(Icons.person_rounded, color: Colors.white, size: 18),
  );
}

class _ServiceMarker extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _ServiceMarker({required this.icon, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    width: 34, height: 34,
    decoration: BoxDecoration(
      color: color, shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 2),
      boxShadow: [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 8)],
    ),
    child: Icon(icon, color: Colors.white, size: 16),
  );
}

// ── Info pill ─────────────────────────────────────────────────────────────────
class _InfoPill extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  const _InfoPill({required this.icon, required this.color, required this.label});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, color: color, size: 14),
    const SizedBox(width: 4),
    Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
  ]);
}

// ── Volunteer popup ───────────────────────────────────────────────────────────
class _VolunteerPopup extends StatelessWidget {
  final VolunteerModel vol;
  final double distance;
  final String emergencyType;
  const _VolunteerPopup({required this.vol, required this.distance, required this.emergencyType});

  @override
  Widget build(BuildContext context) {
    final distKm = (distance / 1000).toStringAsFixed(1);
    final eta    = (distance / 250).round().clamp(1, 60);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 20, offset: const Offset(0, 4))],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppTheme.green.withValues(alpha: 0.15),
            child: Text(vol.name.isNotEmpty ? vol.name[0].toUpperCase() : '?',
                style: const TextStyle(color: AppTheme.green, fontWeight: FontWeight.w800, fontSize: 18)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(vol.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            Text('⭐ ${vol.displayRating.toStringAsFixed(1)} · $distKm km · ~$eta min',
                style: TextStyle(color: AppTheme.textGrey, fontSize: 12)),
          ])),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _PopupBtn(
            label: 'Call', icon: Icons.phone_rounded, color: AppTheme.green,
            onTap: () => SmsService.callNumber(vol.phone),
          )),
          const SizedBox(width: 10),
          Expanded(child: _PopupBtn(
            label: 'SMS', icon: Icons.sms_rounded, color: AppTheme.orange, outlined: true,
            onTap: () => SmsService.sendEmergencySMS(
                emergencyType: emergencyType, action: 'Need help nearby',
                lat: null, lng: null, recipients: [vol.phone]),
          )),
        ]),
      ]),
    );
  }
}

// ── Service popup ─────────────────────────────────────────────────────────────
class _ServicePopup extends StatelessWidget {
  final NearbyPlace place;
  final IconData Function(String) iconForType;
  final Color Function(String) colorForType;
  const _ServicePopup({required this.place, required this.iconForType, required this.colorForType});

  @override
  Widget build(BuildContext context) {
    final color = colorForType(place.type);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 20, offset: const Offset(0, 4))],
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
          child: Icon(iconForType(place.type), color: color),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(place.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          Text('${(place.distanceMeters / 1000).toStringAsFixed(1)} km · ~${place.estimatedMinutes} min',
              style: TextStyle(color: AppTheme.textGrey, fontSize: 12)),
        ])),
        if (place.phone != null)
          GestureDetector(
            onTap: () => SmsService.callNumber(place.phone!),
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: AppTheme.green, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.phone_rounded, color: Colors.white, size: 18),
            ),
          ),
      ]),
    );
  }
}

class _PopupBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool outlined;
  final VoidCallback onTap;
  const _PopupBtn({required this.label, required this.icon, required this.color, this.outlined = false, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: outlined ? color.withValues(alpha: 0.1) : color,
        borderRadius: BorderRadius.circular(10),
        border: outlined ? Border.all(color: color.withValues(alpha: 0.3)) : null,
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: outlined ? color : Colors.white, size: 16),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: outlined ? color : Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
      ]),
    ),
  );
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});
  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    const SizedBox(width: 4),
    Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500)),
  ]);
}
