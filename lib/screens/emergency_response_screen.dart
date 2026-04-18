import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/sms_service.dart';
import '../services/nearby_service.dart';
import '../services/location_service.dart';
import '../services/cache_service.dart';
import '../services/connectivity_service.dart';
import '../services/demo_service.dart';

class EmergencyResponseScreen extends StatefulWidget {
  const EmergencyResponseScreen({super.key});
  @override
  State<EmergencyResponseScreen> createState() => _EmergencyResponseScreenState();
}

class _EmergencyResponseScreenState extends State<EmergencyResponseScreen> {
  String emergencyType = '';
  List<NearbyPlace> _nearby = [];
  bool _loadingNearby = true;
  double? _lat, _lng;
  bool _isOnline = true;
  bool _isInit = false;
  StreamSubscription<bool>? _connectivitySub;

  static const _emergencyNumbers = [
    {'number': '100',  'label': 'Police',       'icon': Icons.local_police_rounded},
    {'number': '101',  'label': 'Fire Services', 'icon': Icons.local_fire_department_rounded},
    {'number': '108',  'label': 'Ambulance',     'icon': Icons.emergency_rounded},
    {'number': '1091', 'label': 'Women Safety',  'icon': Icons.shield_rounded},
    {'number': '1070', 'label': 'Disaster Mgmt', 'icon': Icons.warning_rounded},
  ];

  static const _actions = {
    'Medical':      ['Request medical volunteer', 'Request transport to hospital'],
    'Accident':     ['Request medical volunteer', 'Request immediate transport'],
    'Fire':         ['Alert nearby to evacuate',  'Request evacuation help'],
    'Safety':       ['Request someone to accompany', 'Request quick pickup'],
    'Disaster':     ['Find/request shelter', 'Request food & water', 'Search & rescue'],
    'Help Request': ['Request transport', 'Ask for nearby assistance'],
  };

  @override
  void initState() {
    super.initState();
    ConnectivityService.checkOnline().then((v) {
      if (mounted) setState(() => _isOnline = v);
    });
    _connectivitySub = ConnectivityService.onlineStream.listen((online) {
      if (mounted) setState(() => _isOnline = online);
    });
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInit) {
      emergencyType =
          ModalRoute.of(context)?.settings.arguments as String? ?? 'Medical';
      _isInit = true;
      _loadNearby();
    }
  }

  Future<void> _loadNearby() async {
    if (!mounted) return;
    setState(() {
      _nearby = [];
      _loadingNearby = true;
    });

    // Step 1: Show demo places immediately (no network wait)
    final demoPlaaces = DemoService.dummyNearbyPlaces(emergencyType: emergencyType);
    if (mounted) {
      setState(() {
        _nearby = demoPlaaces;
        _loadingNearby = false;
      });
    }

    // Step 2: Try cached
    final cached = await CacheService.getCachedHospitals();
    if (mounted && cached.isNotEmpty) {
      setState(() => _nearby = cached);
    }

    // Step 3: Get location (non-null)
    final pos = await LocationService.getCurrentLocation();
    _lat = pos.latitude;
    _lng = pos.longitude;

    // Step 4: Fetch live nearby services
    try {
      final places = await NearbyService.fetchNearby(
        lat: pos.latitude, lng: pos.longitude,
        emergencyType: emergencyType,
      );
      if (mounted && places.isNotEmpty) {
        setState(() => _nearby = places);
        CacheService.cacheHospitals(places);
      }
    } catch (e) {
      debugPrint('[EmergencyResponse] NearbyService error: $e');
    }
    if (mounted) setState(() => _loadingNearby = false);
  }

  void _sendSMS(String action) {
    SmsService.sendEmergencySMS(
      emergencyType: emergencyType, action: action,
      lat: _lat, lng: _lng,
    );
  }

  @override
  Widget build(BuildContext context) {
    final actions = _actions[emergencyType] ?? ['Request assistance'];
    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: AppTheme.offWhite, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppTheme.textDark),
          ),
        ),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Emergency Response',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          Text('$emergencyType Emergency',
              style: TextStyle(fontSize: 12, color: AppTheme.textGrey)),
        ]),
        actions: [
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/home'),
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              width: 38, height: 38,
              decoration: BoxDecoration(color: AppTheme.orange, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.home_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [

        // Offline banner
        if (!_isOnline)
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.danger.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.danger.withValues(alpha: 0.2)),
            ),
            child: Row(children: [
              const Icon(Icons.wifi_off_rounded, color: AppTheme.danger, size: 18),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('You are offline',
                    style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.danger, fontSize: 13)),
                Text('Showing demo data · SMS available',
                    style: TextStyle(color: AppTheme.textGrey, fontSize: 11)),
              ])),
            ]),
          ),

        // ── Call Emergency Services ──────────────────────────────────────
        _SectionHeader(label: 'Call Emergency Services', color: AppTheme.danger, badge: 'Priority'),
        const SizedBox(height: 12),

        // 112 hero button
        GestureDetector(
          onTap: () => SmsService.callNumber('112'),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFD32F2F), Color(0xFFB71C1C)]),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [BoxShadow(color: AppTheme.danger.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 6))],
            ),
            child: Row(children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.phone_rounded, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('112', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
                Text('National Emergency', style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13)),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                child: const Text('CALL NOW', style: TextStyle(color: AppTheme.danger, fontSize: 12, fontWeight: FontWeight.w800)),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 12),

        // Grid of other numbers
        GridView.count(
          crossAxisCount: 2, shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 2.4,
          children: _emergencyNumbers.map((n) => GestureDetector(
            onTap: () => SmsService.callNumber(n['number'] as String),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.danger.withValues(alpha: 0.12)),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
              ),
              child: Row(children: [
                Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(color: AppTheme.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(9)),
                  child: Icon(n['icon'] as IconData, color: AppTheme.orange, size: 16),
                ),
                const SizedBox(width: 10),
                Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(n['number'] as String, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  Text(n['label'] as String, style: TextStyle(color: AppTheme.textGrey, fontSize: 10)),
                ]),
              ]),
            ),
          )).toList(),
        ),
        const SizedBox(height: 20),

        // ── Nearby on Map ────────────────────────────────────────────────
        Row(children: [
          _SectionHeader(label: 'Nearby on Map', color: AppTheme.green),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: AppTheme.green.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 6, height: 6,
                  decoration: BoxDecoration(color: _isOnline ? AppTheme.green : AppTheme.danger, shape: BoxShape.circle)),
              const SizedBox(width: 4),
              Text(_isOnline ? 'Live' : 'Demo',
                  style: TextStyle(color: _isOnline ? AppTheme.green : AppTheme.danger, fontSize: 11, fontWeight: FontWeight.w600)),
            ]),
          ),
        ]),
        const SizedBox(height: 12),

        // Mini map tap button
        GestureDetector(
          onTap: () => Navigator.pushNamed(context, '/map', arguments: emergencyType),
          child: Container(
            height: 100,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.green.withValues(alpha: 0.2)),
            ),
            child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.map_rounded, color: AppTheme.green, size: 32),
              SizedBox(height: 6),
              Text('Open Full Map', style: TextStyle(color: AppTheme.green, fontWeight: FontWeight.w700)),
              Text('Volunteers & services near you', style: TextStyle(color: AppTheme.textGrey, fontSize: 12)),
            ]),
          ),
        ),
        const SizedBox(height: 8),

        // Nearby places list
        if (_loadingNearby)
          ...List.generate(3, (_) => _SkeletonTile())
        else ..._nearby.take(4).map((p) => _NearbyPlaceTile(place: p)),

        const SizedBox(height: 20),

        // ── Get Help Nearby (volunteer match) ────────────────────────────
        _SectionHeader(label: 'Find Volunteers Nearby', color: AppTheme.orange),
        const SizedBox(height: 12),

        ...actions.map((action) => _ActionCard(
          action: action, emergencyType: emergencyType,
          onTap: () => Navigator.pushNamed(context, '/volunteer-match',
              arguments: {'emergencyType': emergencyType, 'action': action}),
        )),
        const SizedBox(height: 20),

        // Emergency SMS button
        GestureDetector(
          onTap: () => _sendSMS(actions.first),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              color: AppTheme.danger,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: AppTheme.danger.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 4))],
            ),
            child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.sms_rounded, color: Colors.white, size: 24),
              SizedBox(width: 10),
              Text('Send Emergency SMS', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white)),
            ]),
          ),
        ),
        const SizedBox(height: 32),
      ]),
    );
  }
}

// ── Reusable widgets ──────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  final Color color;
  final String? badge;
  const _SectionHeader({required this.label, required this.color, this.badge});

  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    const SizedBox(width: 8),
    Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
    if (badge != null) ...[
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
        child: Text(badge!, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
      ),
    ],
  ]);
}

class _SkeletonTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
    child: Row(children: [
      Container(width: 40, height: 40,
          decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(10))),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 140, height: 14,
            decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4))),
        const SizedBox(height: 6),
        Container(width: 80, height: 12,
            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(4))),
      ])),
    ]),
  );
}

class _NearbyPlaceTile extends StatelessWidget {
  final NearbyPlace place;
  const _NearbyPlaceTile({required this.place});

  IconData get _icon {
    switch (place.type) {
      case 'hospital':     return Icons.local_hospital_rounded;
      case 'fire_station': return Icons.local_fire_department_rounded;
      case 'police':       return Icons.local_police_rounded;
      case 'shelter':      return Icons.home_rounded;
      default:             return Icons.place_rounded;
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white, borderRadius: BorderRadius.circular(14),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
    ),
    child: Row(children: [
      Container(
        width: 40, height: 40,
        decoration: BoxDecoration(color: AppTheme.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
        child: Icon(_icon, color: AppTheme.green, size: 20),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(place.name,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        Text('${(place.distanceMeters / 1000).toStringAsFixed(1)} km · ~${place.estimatedMinutes} min',
            style: TextStyle(color: AppTheme.textGrey, fontSize: 12)),
      ])),
      if (place.phone != null)
        GestureDetector(
          onTap: () => SmsService.callNumber(place.phone!),
          child: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: AppTheme.green, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.phone_rounded, color: Colors.white, size: 18),
          ),
        ),
    ]),
  );
}

class _ActionCard extends StatelessWidget {
  final String action;
  final String emergencyType;
  final VoidCallback onTap;
  const _ActionCard({required this.action, required this.emergencyType, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.orange.withValues(alpha: 0.2)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
      ),
      child: Row(children: [
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(color: AppTheme.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.volunteer_activism_rounded, color: AppTheme.orange, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(child: Text(action, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
        const Icon(Icons.arrow_forward_ios_rounded, size: 15, color: Color(0xFF999999)),
      ]),
    ),
  );
}
