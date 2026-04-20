import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../theme/app_theme.dart';
import '../services/demo_service.dart';
import '../services/allocation_service.dart';
import '../services/firestore_service.dart';

/// Volunteer navigation map — displayed immediately after accepting an emergency.
///
/// Shows ONLY:
///   🟢  Volunteer's current position (demo: hardcoded to their Firestore coords)
///   🟡  Victim / emergency location (pulsing amber)
///   🟢  Curved polyline route between them (Bézier approximation)
///   📊  Bottom panel: type, distance, ETA, navigate/arrived actions
///
/// Explicitly does NOT show:
///   ✗  Other volunteers
///   ✗  Hospitals / services / nearby places
class VolunteerMapScreen extends StatefulWidget {
  const VolunteerMapScreen({super.key});
  @override
  State<VolunteerMapScreen> createState() => _VolunteerMapScreenState();
}

class _VolunteerMapScreenState extends State<VolunteerMapScreen>
    with TickerProviderStateMixin {
  // ── Position state ──────────────────────────────────────────────────────────
  static const _demoCenter    = LatLng(DemoService.baseLat, DemoService.baseLng);
  LatLng _volunteerPos        = _demoCenter;
  LatLng? _victimPos;

  // ── Emergency metadata ──────────────────────────────────────────────────────
  String _emergencyType = 'Medical';
  bool   _isInit        = false;
  bool   _isLoading     = true;

  // ── Map + animation ─────────────────────────────────────────────────────────
  final _mapController = MapController();
  late AnimationController _pulseCtrl;
  late Animation<double>   _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.2).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

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
          _victimPos = LatLng(vLat.toDouble(), vLng.toDouble());
        }

        // Use volunteer's own coordinates if provided (from DemoService data)
        final myLat = args['volunteerLat'];
        final myLng = args['volunteerLng'];
        if (myLat != null && myLng != null &&
            (myLat as num) != 0 && (myLng as num) != 0) {
          _volunteerPos = LatLng(myLat.toDouble(), myLng.toDouble());
        }
      }
      _isInit = true;
      _initMap();
    }
  }

  Future<void> _initMap() async {
    // Default victim to a realistic nearby point if not passed
    _victimPos ??= LatLng(
      DemoService.baseLat + 0.003,
      DemoService.baseLng + 0.002,
    );

    if (mounted) setState(() => _isLoading = false);

    await Future.delayed(const Duration(milliseconds: 200));
    try {
      // Centre camera between volunteer and victim
      _mapController.move(_midpoint(), 14.2);
    } catch (_) {}
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ── Geometric helpers ───────────────────────────────────────────────────────

  LatLng _midpoint() {
    final victim = _victimPos ?? _demoCenter;
    return LatLng(
      (_volunteerPos.latitude + victim.latitude) / 2,
      (_volunteerPos.longitude + victim.longitude) / 2,
    );
  }

  /// Quadratic Bézier curved polyline between volunteer and victim.
  /// Adds a perpendicular offset at the midpoint to simulate a road curve.
  List<LatLng> _routePoints() {
    if (_victimPos == null) return [_volunteerPos];
    final p1 = _volunteerPos;
    final p2 = _victimPos!;

    // Direction vector
    final dLat = p2.latitude  - p1.latitude;
    final dLon = p2.longitude - p1.longitude;

    // Perpendicular offset (rotate 90° and scale)
    const curveFactor = 0.18;
    final cpLat = (p1.latitude  + p2.latitude)  / 2 + dLon * curveFactor;
    final cpLng = (p1.longitude + p2.longitude) / 2 - dLat * curveFactor;

    // Sample 24 points along the Bézier curve
    final pts = <LatLng>[];
    const steps = 24;
    for (int i = 0; i <= steps; i++) {
      final t  = i / steps;
      final mt = 1 - t;
      pts.add(LatLng(
        mt * mt * p1.latitude  + 2 * mt * t * cpLat + t * t * p2.latitude,
        mt * mt * p1.longitude + 2 * mt * t * cpLng + t * t * p2.longitude,
      ));
    }
    return pts;
  }

  double _distanceKm() {
    if (_victimPos == null) return 0;
    return AllocationService.haversineMeters(
          _volunteerPos.latitude, _volunteerPos.longitude,
          _victimPos!.latitude,   _victimPos!.longitude) /
        1000;
  }

  int _etaMinutes() => (_distanceKm() * 2).round().clamp(1, 60);

  // ── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final routePts = _routePoints();
    final distKm   = _distanceKm();
    final eta      = _etaMinutes();

    return Scaffold(
      body: Stack(children: [
        // ── Map ───────────────────────────────────────────────────────────────
        Positioned.fill(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppTheme.orange))
              : FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _midpoint(),
                    initialZoom: 14.2,
                    onTap: (_, __) {}, // no selection on volunteer map
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.emadad.emadad',
                      fallbackUrl:
                          'https://a.tile.openstreetmap.org/{z}/{x}/{y}.png',
                    ),

                    // ── Route polylines (shadow + colour) ─────────────────────
                    if (routePts.length > 1) ...[
                      PolylineLayer(polylines: [
                        // Drop shadow
                        Polyline(
                          points:      routePts,
                          strokeWidth: 8.0,
                          color:       Colors.black.withValues(alpha: 0.10),
                        ),
                        // Dashed-look base
                        Polyline(
                          points:      routePts,
                          strokeWidth: 5.0,
                          color:       AppTheme.green.withValues(alpha: 0.9),
                        ),
                      ]),
                    ],

                    // ── Markers ───────────────────────────────────────────────
                    MarkerLayer(markers: [
                      // Volunteer (YOU)
                      Marker(
                        point:  _volunteerPos,
                        width:  64, height: 64,
                        child:  const _VolunteerPinMarker(),
                      ),
                      // Victim (EMERGENCY)
                      if (_victimPos != null)
                        Marker(
                          point:  _victimPos!,
                          width:  68, height: 68,
                          child:  AnimatedBuilder(
                            animation: _pulseAnim,
                            builder: (_, child) => Transform.scale(
                              scale: _pulseAnim.value,
                              child: child,
                            ),
                            child: const _VictimPinMarker(),
                          ),
                        ),
                    ]),
                  ],
                ),
        ),

        // ── Top bar ───────────────────────────────────────────────────────────
        Positioned(
          top: 0, left: 0, right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(children: [
                // Back
                _MapBtn(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                ),
                const SizedBox(width: 10),
                // Title pill
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [BoxShadow(
                          color: Colors.black.withValues(alpha: 0.10),
                          blurRadius: 12)],
                    ),
                    child: Row(children: [
                      Container(
                        width: 8, height: 8,
                        decoration: const BoxDecoration(
                            color: AppTheme.danger, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          const Text('Navigating to Emergency',
                              style: TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 13)),
                          Text(_emergencyType,
                              style: TextStyle(
                                  color: AppTheme.textGrey, fontSize: 11)),
                        ]),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(width: 8),
                // Re-centre
                _MapBtn(
                  onTap: () {
                    try { _mapController.move(_midpoint(), 14.2); } catch (_) {}
                  },
                  child: const Icon(Icons.center_focus_strong_rounded,
                      size: 20, color: AppTheme.orange),
                ),
              ]),
            ),
          ),
        ),

        // ── Bottom info panel ─────────────────────────────────────────────────
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: _BottomPanel(
            emergencyType: _emergencyType,
            distKm:        distKm,
            eta:           eta,
            victimPos:     _victimPos,
            onNavigate: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Navigation started — follow the route'),
                backgroundColor: AppTheme.green,
                duration: Duration(seconds: 2),
              ),
            ),
            onArrived: () async {
              final nav = Navigator.of(context);
              await FirestoreService.clearAcceptedEmergency();
              if (mounted) nav.pop();
            },
          ),
        ),
      ]),
    );
  }
}



// ── Marker widgets ─────────────────────────────────────────────────────────────

class _VolunteerPinMarker extends StatelessWidget {
  const _VolunteerPinMarker();
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: AppTheme.green, shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [BoxShadow(
              color: AppTheme.green.withValues(alpha: 0.55), blurRadius: 14)],
        ),
        child: const Icon(Icons.person_rounded, color: Colors.white, size: 24),
      ),
      Container(
        margin: const EdgeInsets.only(top: 2),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: AppTheme.green,
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text('You',
            style: TextStyle(
                color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
      ),
    ],
  );
}

class _VictimPinMarker extends StatelessWidget {
  const _VictimPinMarker();
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 48, height: 48,
        decoration: BoxDecoration(
          color: Colors.amber.shade700, shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3.5),
          boxShadow: [BoxShadow(
              color: Colors.amber.withValues(alpha: 0.80), blurRadius: 20,
              spreadRadius: 4)],
        ),
        child: const Icon(Icons.warning_rounded, color: Colors.white, size: 28),
      ),
      Container(
        margin: const EdgeInsets.only(top: 2),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: Colors.amber.shade700,
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text('VICTIM',
            style: TextStyle(
                color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900)),
      ),
    ],
  );
}

// ── Icon map button ────────────────────────────────────────────────────────────
class _MapBtn extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  const _MapBtn({required this.child, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 44, height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.12), blurRadius: 10)],
      ),
      child: child,
    ),
  );
}

// ── Bottom panel ───────────────────────────────────────────────────────────────
class _BottomPanel extends StatelessWidget {
  final String    emergencyType;
  final double    distKm;
  final int       eta;
  final LatLng?   victimPos;
  final VoidCallback onNavigate;
  final VoidCallback onArrived;
  const _BottomPanel({
    required this.emergencyType, required this.distKm, required this.eta,
    required this.victimPos, required this.onNavigate, required this.onArrived,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 20, offset: const Offset(0, -4))],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Drag handle
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),

            // Emergency type + accepted badge
            Row(children: [
              _EmergencyTypeBadge(type: emergencyType),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.green.withValues(alpha: 0.3)),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.check_circle_rounded,
                      color: AppTheme.green, size: 14),
                  SizedBox(width: 5),
                  Text('ACCEPTED',
                      style: TextStyle(
                          color: AppTheme.green, fontSize: 11,
                          fontWeight: FontWeight.w800)),
                ]),
              ),
            ]),
            const SizedBox(height: 16),

            // Stats row
            Row(children: [
              _StatTile(
                icon:  Icons.place_rounded,
                color: AppTheme.orange,
                label: 'Distance',
                value: distKm < 1
                    ? '${(distKm * 1000).toInt()} m'
                    : '${distKm.toStringAsFixed(1)} km',
              ),
              Container(width: 1, height: 44, color: Colors.grey.shade100),
              _StatTile(
                icon:  Icons.timer_rounded,
                color: Colors.blue,
                label: 'ETA',
                value: '$eta min',
              ),
              Container(width: 1, height: 44, color: Colors.grey.shade100),
              _StatTile(
                icon:  Icons.local_fire_department_rounded,
                color: AppTheme.danger,
                label: 'Priority',
                value: 'HIGH',
              ),
            ]),
            const SizedBox(height: 14),

            // Victim location chip
            if (victimPos != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                ),
                child: Row(children: [
                  Container(width: 7, height: 7,
                      decoration: const BoxDecoration(
                          color: Colors.amber, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Victim: ${victimPos!.latitude.toStringAsFixed(4)}, '
                      '${victimPos!.longitude.toStringAsFixed(4)}',
                      style: TextStyle(
                          color: Colors.amber.shade800, fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ]),
              ),
            const SizedBox(height: 14),

            // Action buttons
            Row(children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onNavigate,
                  icon:  const Icon(Icons.navigation_rounded,
                      color: Colors.white, size: 18),
                  label: const Text('Navigate',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.green,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: onArrived,
                icon:  const Icon(Icons.check_rounded,
                    color: AppTheme.orange, size: 18),
                label: const Text('Arrived',
                    style: TextStyle(
                        color: AppTheme.orange, fontWeight: FontWeight.w700)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      vertical: 14, horizontal: 18),
                  side: BorderSide(color: AppTheme.orange.withValues(alpha: 0.4)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _EmergencyTypeBadge extends StatelessWidget {
  final String type;
  const _EmergencyTypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (type) {
      'Medical'  => (Colors.blue,       Icons.medical_services_rounded),
      'Fire'     => (Colors.deepOrange, Icons.local_fire_department_rounded),
      'Accident' => (Colors.red,        Icons.car_crash_rounded),
      'Disaster' => (Colors.purple,     Icons.warning_amber_rounded),
      'Safety'   => (Colors.teal,       Icons.shield_rounded),
      _          => (AppTheme.orange,   Icons.emergency_rounded),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 6),
        Text(type,
            style: TextStyle(
                color: color, fontWeight: FontWeight.w800, fontSize: 13)),
      ]),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  const _StatTile({required this.icon, required this.color,
      required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: color, size: 20),
      const SizedBox(height: 3),
      Text(value,
          style: TextStyle(
              fontWeight: FontWeight.w800, fontSize: 16, color: color)),
      Text(label,
          style: TextStyle(color: AppTheme.textGrey, fontSize: 10)),
    ]),
  );
}
