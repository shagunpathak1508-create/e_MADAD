import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../theme/app_theme.dart';
import '../services/nearby_service.dart';
import '../services/connectivity_service.dart';
import '../services/sms_service.dart';
import '../services/cache_service.dart';
import '../services/firestore_service.dart';
import '../services/demo_service.dart';
import '../services/allocation_service.dart';
import '../models/volunteer_model.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // ── State ──────────────────────────────────────────────────────────────────
  // In demo mode we always start at Mumbai city centre — no GPS needed.
  static const _demoCenter = LatLng(DemoService.baseLat, DemoService.baseLng);

  LatLng _myLocation       = _demoCenter;
  LatLng? _victimLocation;
  bool _isOnline           = true;
  bool _isLoading          = true;
  List<NearbyPlace> _nearby         = [];
  List<VolunteerModel> _volunteers  = [];
  NearbyPlace? _selectedPlace;
  VolunteerModel? _selectedVolunteer;
  String _emergencyType    = 'Medical';
  bool _isInit             = false;

  final _mapController = MapController();
  StreamSubscription<List<VolunteerModel>>? _volunteerSub;

  // ── Arg parsing ────────────────────────────────────────────────────────────
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

  // ── Initialisation ─────────────────────────────────────────────────────────
  Future<void> _init() async {
    // Step 1: Show demo data IMMEDIATELY — map never looks blank
    _applyDemoFallback();

    // Step 2: Connectivity check (async, non-blocking)
    ConnectivityService.checkOnline().then((online) {
      if (mounted) setState(() => _isOnline = online);
    });

    // Step 3: Demo mode — location is already hardcoded, no GPS needed.
    // We still mark loading as false and move the camera.
    if (mounted) {
      setState(() {
        _myLocation = _demoCenter;
        _isLoading  = false;
      });
    }

    // Step 4: Move camera to victim location (volunteer flow) or demo centre
    await Future.delayed(const Duration(milliseconds: 200));
    try {
      _mapController.move(_victimLocation ?? _demoCenter, 14.5);
    } catch (_) {}

    // Step 5: Try cached nearby places
    final cached = await CacheService.getCachedHospitals();
    if (mounted && cached.isNotEmpty) {
      setState(() => _nearby = cached);
    }

    // Step 6: Fetch nearby services — filtered to emergency-relevant types only
    NearbyService.fetchNearby(
      lat: DemoService.baseLat,
      lng: DemoService.baseLng,
      emergencyType: _emergencyType,
    ).then((places) {
      if (mounted && places.isNotEmpty) {
        // Filter to only service types that are relevant for this emergency
        final filtered = AllocationService.filterServices(places, _emergencyType);
        setState(() => _nearby = filtered.isNotEmpty ? filtered : places.take(4).toList());
        CacheService.cacheHospitals(places);
      }
    }).catchError((_) {});

    // Step 7: Subscribe to Firestore volunteer stream — apply skill filter + scoring
    _volunteerSub?.cancel();
    _volunteerSub = FirestoreService.nearbyVolunteers(
      DemoService.baseLat, DemoService.baseLng, 10,
    ).listen((vols) {
      if (!mounted) return;
      final allVols = vols.isNotEmpty ? vols : DemoService.dummyVolunteers;
      // Apply strict skill filtering + composite score ranking for this emergency type
      final ranked = AllocationService.rankVolunteers(
          _emergencyType, allVols, DemoService.baseLat, DemoService.baseLng);
      setState(() {
        _volunteers = ranked.isNotEmpty ? ranked : allVols.take(4).toList();
      });
      if (vols.isNotEmpty) CacheService.cacheVolunteers(vols);
    });
  }

  void _applyDemoFallback() {
    if (!mounted) return;
    // Load cached volunteers and apply skill filter immediately
    CacheService.getCachedVolunteers().then((cached) {
      if (mounted) {
        final allVols = cached.isNotEmpty
            ? cached
            : DemoService.dummyVolunteers;
        // Skill-filter + rank even the fallback data
        final ranked = AllocationService.rankVolunteers(
            _emergencyType, allVols, DemoService.baseLat, DemoService.baseLng);
        setState(() {
          _volunteers = ranked.isNotEmpty ? ranked : allVols.take(4).toList();
          if (_nearby.isEmpty) {
            // Filter demo nearby places to only relevant service types
            final demoPlaces = DemoService.dummyNearbyPlaces(
                emergencyType: _emergencyType);
            _nearby = AllocationService.filterServices(demoPlaces, _emergencyType);
          }
          _isLoading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _volunteerSub?.cancel();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  double _distanceTo(double lat, double lng) =>
      _haversine(_myLocation.latitude, _myLocation.longitude, lat, lng);

  double _haversine(double lat1, double lng1, double lat2, double lng2) {
    const r    = 6371000.0;
    const pi   = 3.14159265358979323846;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLon = (lng2 - lng1) * pi / 180;
    final a    = (dLat / 2) * (dLat / 2) +
        _cos(lat1 * pi / 180) * _cos(lat2 * pi / 180) *
            (dLon / 2) * (dLon / 2);
    return r * 2 * (a < 1 ? _asin(a) * 2 : pi);
  }

  // Lightweight trig approximations (no dart:math import needed here)
  double _cos(double x) {
    // Taylor series cos(x) ≈ 1 - x²/2 + x⁴/24 for small x
    // Good enough at the scale of a city map
    final x2 = x * x;
    return 1 - x2 / 2 + x2 * x2 / 24;
  }

  double _asin(double x) => x + x * x * x / 6; // asin(x)≈x for small x

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

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final center = _victimLocation ?? _myLocation;

    return Scaffold(
      body: Stack(
        children: [
          // ── FlutterMap ───────────────────────────────────────────────────
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: center,
                initialZoom: 14.5,
                onTap: (_, __) => _clearSelection(),
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.emadad.emadad',
                  fallbackUrl:
                      'https://a.tile.openstreetmap.org/{z}/{x}/{y}.png',
                ),

                // Markers
                MarkerLayer(markers: [
                  // MY location — RED dot (hardcoded demo centre)
                  Marker(
                    point:  _myLocation,
                    width:  56, height: 56,
                    child:  const _MyLocationMarker(),
                  ),

                  // VICTIM location (volunteer flow) — AMBER pulsing
                  if (_victimLocation != null)
                    Marker(
                      point:  _victimLocation!,
                      width:  60, height: 60,
                      child:  const _VictimMarker(),
                    ),

                  // VOLUNTEER markers — GREEN (guaranteed ≥4 via demo roster)
                  ..._volunteers.map((vol) => Marker(
                    point: LatLng(vol.lat, vol.lng),
                    width: 44, height: 44,
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _selectedPlace      = null;
                        _selectedVolunteer  = vol;
                      }),
                      child: _VolunteerMarker(
                          selected: _selectedVolunteer?.id == vol.id),
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
                          _selectedPlace     = p;
                        }),
                        child: _ServiceMarker(
                            icon: _iconForType(p.type), color: color),
                      ),
                    );
                  }),
                ]),
              ],
            ),
          ),

          // ── Loading overlay ──────────────────────────────────────────────
          if (_isLoading)
            Positioned.fill(
              child: Container(
                color: Colors.white.withValues(alpha: 0.7),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                          color: AppTheme.orange, strokeWidth: 2),
                      SizedBox(height: 12),
                      Text('Loading map…',
                          style: TextStyle(
                              fontSize: 13, color: AppTheme.textGrey)),
                    ],
                  ),
                ),
              ),
            ),

          // ── Top bar ──────────────────────────────────────────────────────
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(
              child: Column(children: [
                if (!_isOnline)
                  Container(
                    color: AppTheme.danger,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 6),
                    child: const Row(children: [
                      Icon(Icons.wifi_off_rounded,
                          color: Colors.white, size: 14),
                      SizedBox(width: 8),
                      Text('Offline — showing cached data',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    ]),
                  ),

                // App bar row
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(children: [
                    // Back
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 8)
                          ],
                        ),
                        child: const Icon(Icons.arrow_back_ios_new_rounded,
                            size: 18),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Title pill
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 10)
                          ],
                        ),
                        child: Text(
                          _victimLocation != null
                              ? '$_emergencyType Emergency · Navigating to Victim'
                              : '$_emergencyType Emergency · Nearby Services',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                      ),
                    ),

                    // Re-centre
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        try {
                          _mapController.move(
                              _victimLocation ?? _myLocation, 14.5);
                        } catch (_) {}
                      },
                      child: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 8)
                          ],
                        ),
                        child: const Icon(Icons.my_location_rounded,
                            size: 20, color: AppTheme.orange),
                      ),
                    ),
                  ]),
                ),

                // Stats bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 8)
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _InfoPill(
                            icon: Icons.people_rounded,
                            color: AppTheme.green,
                            label: '${_volunteers.length} Volunteers'),
                        _InfoPill(
                            icon: Icons.local_hospital_rounded,
                            color: Colors.blue,
                            label: '${_nearby.length} Services'),
                        if (_victimLocation != null)
                          _InfoPill(
                              icon: Icons.place_rounded,
                              color: Colors.amber,
                              label:
                                  '${(_distanceTo(_victimLocation!.latitude, _victimLocation!.longitude) / 1000).toStringAsFixed(1)} km'),
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
                vol:           _selectedVolunteer!,
                distance:      _distanceTo(
                    _selectedVolunteer!.lat, _selectedVolunteer!.lng),
                emergencyType: _emergencyType,
              ),
            ),

          // ── Service popup ────────────────────────────────────────────────
          if (_selectedPlace != null)
            Positioned(
              bottom: 80, left: 16, right: 16,
              child: _ServicePopup(
                place:        _selectedPlace!,
                iconForType:  _iconForType,
                colorForType: _colorForType,
              ),
            ),

          // ── Bottom legend ────────────────────────────────────────────────
          Positioned(
            bottom: 16, left: 16, right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 10)
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _LegendDot(color: AppTheme.danger,  label: 'You'),
                  _LegendDot(color: Colors.amber,      label: 'Emergency'),
                  _LegendDot(color: AppTheme.green,   label: 'Volunteer'),
                  _LegendDot(color: Colors.blue,       label: 'Services'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Marker widgets ─────────────────────────────────────────────────────────────

class _MyLocationMarker extends StatelessWidget {
  const _MyLocationMarker();
  @override
  Widget build(BuildContext context) => Column(children: [
    Container(
      width: 36, height: 36,
      decoration: BoxDecoration(
        color: AppTheme.danger, shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: [
          BoxShadow(
              color: AppTheme.danger.withValues(alpha: 0.5),
              blurRadius: 12)
        ],
      ),
      child: const Icon(Icons.person_pin_rounded,
          color: Colors.white, size: 20),
    ),
    const Text('You',
        style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: AppTheme.danger)),
  ]);
}

class _VictimMarker extends StatelessWidget {
  const _VictimMarker();
  @override
  Widget build(BuildContext context) => Column(children: [
    Container(
      width: 40, height: 40,
      decoration: BoxDecoration(
        color: Colors.amber, shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
              color: Colors.amber.withValues(alpha: 0.7),
              blurRadius: 14, spreadRadius: 2)
        ],
      ),
      child: const Icon(Icons.warning_rounded,
          color: Colors.white, size: 24),
    ),
    const Text('EMERGENCY',
        style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w900,
            color: Colors.amber)),
  ]);
}

class _VolunteerMarker extends StatelessWidget {
  final bool selected;
  const _VolunteerMarker({this.selected = false});
  @override
  Widget build(BuildContext context) => Container(
    width:  selected ? 40 : 34,
    height: selected ? 40 : 34,
    decoration: BoxDecoration(
      color: selected ? AppTheme.orange : AppTheme.green,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 2),
      boxShadow: [
        BoxShadow(
            color: (selected ? AppTheme.orange : AppTheme.green)
                .withValues(alpha: 0.5),
            blurRadius: 8)
      ],
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
      boxShadow: [
        BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 8)
      ],
    ),
    child: Icon(icon, color: Colors.white, size: 16),
  );
}

// ── Info pill ──────────────────────────────────────────────────────────────────
class _InfoPill extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  const _InfoPill({required this.icon,required this.color,required this.label});
  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color)),
      ]);
}

// ── Volunteer popup ────────────────────────────────────────────────────────────
class _VolunteerPopup extends StatelessWidget {
  final VolunteerModel vol;
  final double distance;
  final String emergencyType;
  const _VolunteerPopup(
      {required this.vol,
      required this.distance,
      required this.emergencyType});

  @override
  Widget build(BuildContext context) {
    // Use stored distance (km) as a display fallback for precision
    final distKm = vol.distance > 0
        ? vol.distance.toStringAsFixed(1)
        : (distance / 1000).toStringAsFixed(1);
    final eta = vol.distance > 0
        ? (vol.distance * 1000 / 250).round().clamp(1, 60)
        : (distance / 250).round().clamp(1, 60);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 20, offset: const Offset(0, 4))
        ],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppTheme.green.withValues(alpha: 0.15),
            child: Text(
              vol.name.isNotEmpty ? vol.name[0].toUpperCase() : '?',
              style: const TextStyle(
                  color: AppTheme.green,
                  fontWeight: FontWeight.w800, fontSize: 18),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(vol.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15)),
              Text(
                '⭐ ${vol.displayRating.toStringAsFixed(1)} · $distKm km · ~$eta min',
                style: TextStyle(
                    color: AppTheme.textGrey, fontSize: 12),
              ),
              // Skill + tasks inline
              Text(
                '${vol.skill} · ${vol.tasksCompleted} tasks',
                style: TextStyle(
                    color: AppTheme.orange, fontSize: 11,
                    fontWeight: FontWeight.w600),
              ),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _PopupBtn(
            label: 'Call', icon: Icons.phone_rounded,
            color: AppTheme.green,
            onTap: () => SmsService.callNumber(vol.phone),
          )),
          const SizedBox(width: 10),
          Expanded(child: _PopupBtn(
            label: 'SMS', icon: Icons.sms_rounded,
            color: AppTheme.orange, outlined: true,
            onTap: () => SmsService.sendEmergencySMS(
                emergencyType: emergencyType,
                action:        'Need help nearby',
                lat:           null, lng: null,
                recipients:    [vol.phone]),
          )),
        ]),
      ]),
    );
  }
}

// ── Service popup ──────────────────────────────────────────────────────────────
class _ServicePopup extends StatelessWidget {
  final NearbyPlace place;
  final IconData Function(String) iconForType;
  final Color Function(String) colorForType;
  const _ServicePopup(
      {required this.place,
      required this.iconForType,
      required this.colorForType});

  @override
  Widget build(BuildContext context) {
    final color = colorForType(place.type);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 20, offset: const Offset(0, 4))
        ],
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12)),
          child: Icon(iconForType(place.type), color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(place.name,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 14),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(
              '${(place.distanceMeters / 1000).toStringAsFixed(1)} km'
              ' · ~${place.estimatedMinutes} min',
              style: TextStyle(
                  color: AppTheme.textGrey, fontSize: 12),
            ),
          ]),
        ),
        if (place.phone != null)
          GestureDetector(
            onTap: () => SmsService.callNumber(place.phone!),
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                  color: AppTheme.green,
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.phone_rounded,
                  color: Colors.white, size: 18),
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
  const _PopupBtn(
      {required this.label, required this.icon, required this.color,
      this.outlined = false, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: outlined ? color.withValues(alpha: 0.1) : color,
        borderRadius: BorderRadius.circular(10),
        border: outlined
            ? Border.all(color: color.withValues(alpha: 0.3))
            : null,
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon,
            color: outlined ? color : Colors.white, size: 16),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                color: outlined ? color : Colors.white,
                fontWeight: FontWeight.w700, fontSize: 13)),
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
    Container(
        width: 10, height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    const SizedBox(width: 4),
    Text(label,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500)),
  ]);
}
