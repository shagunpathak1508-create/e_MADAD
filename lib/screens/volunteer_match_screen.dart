import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/volunteer_model.dart';
import '../services/firestore_service.dart';
import '../services/sms_service.dart';
import '../services/cache_service.dart';
import '../services/demo_service.dart';
import '../services/location_service.dart';

class VolunteerMatchScreen extends StatefulWidget {
  const VolunteerMatchScreen({super.key});
  @override
  State<VolunteerMatchScreen> createState() => _VolunteerMatchScreenState();
}

class _VolunteerMatchScreenState extends State<VolunteerMatchScreen> {
  String _emergencyType = '';
  String _action = '';
  Stream<List<VolunteerModel>>? _matchStream;
  bool _isInit = false;

  // Immediate fallback — shown while Firestore stream loads
  List<VolunteerModel> _fallback = [];

  @override
  void initState() {
    super.initState();
    _bootstrapFallback();
  }

  /// Load cached + demo data synchronously so the list is never blank.
  Future<void> _bootstrapFallback() async {
    final cached = await CacheService.getCachedVolunteers();
    if (mounted) {
      setState(() {
        _fallback = cached.isNotEmpty
            ? cached
            : DemoService.dummyVolunteers;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInit) {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      _emergencyType = args?['emergencyType'] ?? 'Medical';
      _action        = args?['action']        ?? '';
      _matchStream   = FirestoreService.topMatches(_emergencyType);
      _isInit = true;

      // Refine fallback to match emergency type
      _fallback = DemoService.filteredVolunteers(_emergencyType);
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppTheme.offWhite, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppTheme.textDark),
          ),
        ),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Available Volunteers', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          Text('Best matched for $_emergencyType', style: TextStyle(fontSize: 12, color: AppTheme.textGrey)),
        ]),
      ),
      body: StreamBuilder<List<VolunteerModel>>(
        stream: _matchStream,
        builder: (context, snap) {
          // Priority: Firestore → fallback (cached / demo) — NEVER empty
          final List<VolunteerModel> allVolunteers;
          if (snap.hasData && snap.data!.isNotEmpty) {
            allVolunteers = snap.data!;
            CacheService.cacheVolunteers(snap.data!);
          } else {
            allVolunteers = _fallback;
          }

          final volunteers = allVolunteers.take(3).toList();

          return ListView(padding: const EdgeInsets.all(16), children: [
            // Request info banner
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.orange.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.orange.withValues(alpha: 0.2)),
              ),
              child: Row(children: [
                const Icon(Icons.info_outline_rounded, color: AppTheme.orange, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(
                  _action.isEmpty ? 'Emergency help needed' : _action,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                )),
              ]),
            ),
            const SizedBox(height: 16),

            // Volunteer cards
            if (volunteers.isEmpty)
              const Center(child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('Searching for volunteers…',
                    style: TextStyle(color: AppTheme.textGrey, fontSize: 14)),
              ))
            else
              ...volunteers.map((vol) => _VolunteerCard(
                vol: vol, emergencyType: _emergencyType,
              )),

            const SizedBox(height: 80),
          ]);
        },
      ),
    );
  }
}

// ── Volunteer card ────────────────────────────────────────────────────────────
class _VolunteerCard extends StatelessWidget {
  final VolunteerModel vol;
  final String emergencyType;
  const _VolunteerCard({required this.vol, required this.emergencyType});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.green.withValues(alpha: 0.05),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
          ),
          child: Row(children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: AppTheme.green.withValues(alpha: 0.15),
              child: Text(vol.name.isNotEmpty ? vol.name[0].toUpperCase() : '?',
                  style: const TextStyle(color: AppTheme.green, fontWeight: FontWeight.w800, fontSize: 18)),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(vol.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              Text('⭐ ${vol.displayRating.toStringAsFixed(1)} reliability',
                  style: TextStyle(color: AppTheme.textGrey, fontSize: 12)),
            ])),
            // Distance badge
            FutureBuilder<String>(
              future: _distanceLabel(vol),
              builder: (ctx, snap) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: AppTheme.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Text(snap.data ?? '…', style: const TextStyle(color: AppTheme.green, fontWeight: FontWeight.w700, fontSize: 12)),
              ),
            ),
          ]),
        ),

        // Skills + response time
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            Expanded(child: Wrap(spacing: 6, runSpacing: 4,
              children: vol.skills.map((s) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.orange.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(s, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.orange)),
              )).toList(),
            )),
            const SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${vol.tasksCompleted} tasks', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
              Text('~${vol.avgResponseTime.toStringAsFixed(0)} min avg',
                  style: TextStyle(color: AppTheme.textGrey, fontSize: 11)),
            ]),
          ]),
        ),

        // Buttons
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: Row(children: [
            Expanded(child: _Btn(
              label: 'Call', icon: Icons.phone_rounded, color: AppTheme.green,
              onTap: () => SmsService.callNumber(vol.phone),
            )),
            const SizedBox(width: 10),
            Expanded(child: _Btn(
              label: 'SMS', icon: Icons.sms_rounded, color: AppTheme.orange, outlined: true,
              onTap: () => SmsService.sendEmergencySMS(
                  emergencyType: emergencyType, action: 'I need help urgently',
                  lat: null, lng: null, recipients: [vol.phone]),
            )),
          ]),
        ),
      ]),
    );
  }

  Future<String> _distanceLabel(VolunteerModel vol) async {
    try {
      final pos = await LocationService.getCurrentLocation();
      final dist = LocationService.distanceBetween(
          pos.latitude, pos.longitude, vol.lat, vol.lng);
      final km = dist / 1000;
      return km < 1 ? '${dist.toInt()}m' : '${km.toStringAsFixed(1)} km';
    } catch (_) {
      return '…';
    }
  }
}

class _Btn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool outlined;
  final VoidCallback onTap;
  const _Btn({required this.label, required this.icon, required this.color, this.outlined = false, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: outlined ? color.withValues(alpha: 0.08) : color,
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
