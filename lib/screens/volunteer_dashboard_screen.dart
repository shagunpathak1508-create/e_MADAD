import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme/app_theme.dart';
import '../models/volunteer_model.dart';
import '../models/emergency_model.dart';
import '../services/firestore_service.dart';
import '../services/cache_service.dart';
import '../services/demo_service.dart';
import '../services/allocation_service.dart';

class VolunteerDashboardScreen extends StatefulWidget {
  const VolunteerDashboardScreen({super.key});
  @override
  State<VolunteerDashboardScreen> createState() =>
      _VolunteerDashboardScreenState();
}

class _VolunteerDashboardScreenState extends State<VolunteerDashboardScreen> {
  VolunteerModel? _volunteer;
  String? _vid;
  bool _showAllTasks = false;

  // ── Accepted task state ────────────────────────────────────────────────────
  String? _acceptedId;
  String? _acceptedType;
  double? _acceptedVictimLat;
  double? _acceptedVictimLng;

  late Stream<List<EmergencyModel>> _requestsStream;

  @override
  void initState() {
    super.initState();
    _requestsStream = FirestoreService.volunteerIncomingRequests();
    _loadVolunteer();
  }

  Future<void> _loadVolunteer() async {
    final prefs = await SharedPreferences.getInstance();
    _vid = prefs.getString('volunteer_id') ?? 'demo_vol_1';

    // ── Restore accepted task from SharedPrefs ─────────────────────────────
    final aid = prefs.getString('accepted_emergency_id');
    if (aid != null && mounted) {
      setState(() {
        _acceptedId        = aid;
        _acceptedType      = prefs.getString('accepted_emergency_type') ?? 'Medical';
        _acceptedVictimLat = prefs.getDouble('accepted_victim_lat');
        _acceptedVictimLng = prefs.getDouble('accepted_victim_lng');
      });
    }

    // ── Step 1: In-memory demo roster (instant) ────────────────────────────
    final inMemory = DemoService.findById(_vid!);
    if (inMemory != null && mounted) setState(() => _volunteer = inMemory);

    // ── Step 2: Cached profile ─────────────────────────────────────────────
    if (_volunteer == null) {
      final cached = await CacheService.getCachedProfile();
      if (mounted && cached != null) setState(() => _volunteer = cached);
    }

    // ── Step 3: Placeholder so UI is never null ────────────────────────────
    if (mounted && _volunteer == null) {
      setState(() => _volunteer = VolunteerModel(
        id: _vid!, name: 'Loading…',
        phone: '', skills: [], available: false, tasksCompleted: 0,
      ));
    }

    // ── Step 4: Firestore (latest data) ───────────────────────────────────
    try {
      final vol = await FirestoreService.getVolunteer(_vid!);
      if (!mounted) return;
      if (vol != null) {
        setState(() => _volunteer = vol);
        CacheService.cacheProfile(vol);
      }
    } catch (e) {
      debugPrint('Dashboard: getVolunteer error: $e');
    }
  }

  Future<void> _clearAcceptedTask() async {
    await FirestoreService.clearAcceptedEmergency();
    if (mounted) {
      setState(() {
        _acceptedId        = null;
        _acceptedType      = null;
        _acceptedVictimLat = null;
        _acceptedVictimLng = null;
      });
    }
  }

  void _toggleAvailability() {
    if (_volunteer == null || _vid == null) return;
    final newVal = !_volunteer!.available;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(newVal ? 'Go Active' : 'Turn Off Availability',
            style: const TextStyle(fontWeight: FontWeight.w800)),
        content: Text(
            'Are you sure you want to '
            '${newVal ? "go active and receive requests" : "turn off availability"}?',
            style: TextStyle(color: AppTheme.textGrey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL',
                style: TextStyle(
                    color: AppTheme.textGrey, fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await FirestoreService.updateAvailability(_vid!, newVal);
              if (mounted) setState(() => _volunteer = _volunteer!.copyWith(available: newVal));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: newVal ? AppTheme.green : AppTheme.danger,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('YES',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_volunteer == null) {
      return Scaffold(
        backgroundColor: AppTheme.offWhite,
        body: Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.person_off_rounded, size: 64, color: AppTheme.textGrey),
            const SizedBox(height: 16),
            const Text('No volunteer profile found',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () =>
                  Navigator.pushReplacementNamed(context, '/demo-login'),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.green),
              child: const Text('Select Demo Profile',
                  style: TextStyle(color: Colors.white)),
            ),
          ]),
        ),
      );
    }

    final vol   = _volunteer!;
    final score = vol.reliabilityScore.toInt();

    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text('Volunteer Dashboard',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        actions: [
          // Switch volunteer
          GestureDetector(
            onTap: () => Navigator.pushReplacementNamed(context, '/demo-login'),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.green.withValues(alpha: 0.3)),
              ),
              child: const Row(children: [
                Icon(Icons.swap_horiz_rounded, color: AppTheme.green, size: 16),
                SizedBox(width: 4),
                Text('Switch', style: TextStyle(
                    color: AppTheme.green, fontSize: 12, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.pushReplacementNamed(context, '/home'),
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              width: 38, height: 38,
              decoration: BoxDecoration(
                  color: AppTheme.orange, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.home_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        // ── Profile Card ───────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [AppTheme.green, Color(0xFF0D6B05)],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(
                color: AppTheme.green.withValues(alpha: 0.35),
                blurRadius: 20, offset: const Offset(0, 6))],
          ),
          child: Row(children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              child: Text(
                vol.name.isNotEmpty ? vol.name[0].toUpperCase() : '?',
                style: const TextStyle(
                    color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(vol.name,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
              Text(vol.phone,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8), fontSize: 13)),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 4,
                children: vol.skills.map((s) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(s,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                )).toList(),
              ),
            ])),
          ]),
        ),
        const SizedBox(height: 14),

        // ── Reliability Score Bar ──────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('⭐ ${vol.displayRating.toStringAsFixed(1)} Reliability',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              if (score >= 80)
                _Badge('Highly Reliable', AppTheme.green)
              else if (score >= 60)
                _Badge('Good Standing', AppTheme.orange),
            ]),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: score / 100,
                minHeight: 10,
                backgroundColor: Colors.grey.shade100,
                valueColor: AlwaysStoppedAnimation<Color>(
                    score >= 70 ? AppTheme.green
                    : score >= 40 ? AppTheme.orange
                    : AppTheme.danger),
              ),
            ),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('${vol.tasksCompleted} tasks completed',
                  style: TextStyle(color: AppTheme.textGrey, fontSize: 12)),
              Text('${(vol.responseRate * 100).toInt()}% response rate',
                  style: TextStyle(color: AppTheme.textGrey, fontSize: 12)),
            ]),
          ]),
        ),
        const SizedBox(height: 14),

        // ── Stats Row ──────────────────────────────────────────────────────
        Row(children: [
          Expanded(child: _StatCard(
            icon: Icons.task_alt_rounded, label: 'Tasks Done',
            value: '${vol.tasksCompleted}', color: AppTheme.green,
          )),
          const SizedBox(width: 12),
          Expanded(child: _StatCard(
            icon: Icons.speed_rounded, label: 'Response Rate',
            value: '${(vol.responseRate * 100).toInt()}%', color: AppTheme.orange,
          )),
        ]),
        const SizedBox(height: 14),

        // ── Tasks Chart ────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Tasks Completed by Week',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 14),
            SizedBox(
              height: 110,
              child: BarChart(BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 15,
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (v, _) => Text(
                      ['W1', 'W2', 'W3', 'W4'][v.toInt().clamp(0, 3)],
                      style: TextStyle(fontSize: 10, color: AppTheme.textGrey),
                    ),
                  )),
                  leftTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles:    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles:  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData:   const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups:  _buildBarGroups(vol.tasksCompleted),
              )),
            ),
          ]),
        ),
        const SizedBox(height: 14),

        // ── Response Rate Chart ────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Response Rate Trend',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 14),
            SizedBox(
              height: 100,
              child: LineChart(LineChartData(
                lineBarsData: [LineChartBarData(
                  spots: _buildResponseSpots(vol.responseRate),
                  isCurved: true,
                  color: AppTheme.orange, barWidth: 2.5,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                      show: true,
                      color: AppTheme.orange.withValues(alpha: 0.08)),
                )],
                titlesData: const FlTitlesData(show: false),
                gridData:   const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                minY: 0, maxY: 100,
              )),
            ),
          ]),
        ),
        const SizedBox(height: 14),

        // ── Performance Insights ───────────────────────────────────────────
        _PerformanceInsightsSection(volunteer: vol),
        const SizedBox(height: 14),

        // ── Availability Toggle ────────────────────────────────────────────
        GestureDetector(
          onTap: _toggleAvailability,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: vol.available
                  ? AppTheme.danger.withValues(alpha: 0.07)
                  : AppTheme.green.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: vol.available
                    ? AppTheme.danger.withValues(alpha: 0.25)
                    : AppTheme.green.withValues(alpha: 0.25),
              ),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(
                vol.available
                    ? Icons.power_settings_new_rounded
                    : Icons.check_circle_outline_rounded,
                color: vol.available ? AppTheme.danger : AppTheme.green,
                size: 22,
              ),
              const SizedBox(width: 10),
              Text(
                vol.available ? 'Turn Off Availability' : 'Go Active',
                style: TextStyle(
                  color: vol.available ? AppTheme.danger : AppTheme.green,
                  fontWeight: FontWeight.w700, fontSize: 15,
                ),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 24),

        // ── Active Task (if accepted) or Incoming Requests ─────────────────
        if (_acceptedId != null) ...[
          _SectionHeader(icon: Icons.navigation_rounded,
              label: 'Active Task', color: AppTheme.green),
          const SizedBox(height: 12),
          _ActiveTaskCard(
            emergencyId:  _acceptedId!,
            emergencyType: _acceptedType ?? 'Medical',
            victimLat:    _acceptedVictimLat ?? DemoService.baseLat,
            victimLng:    _acceptedVictimLng ?? DemoService.baseLng,
            volunteer:    vol,
            onComplete:   _clearAcceptedTask,
          ),
        ] else ...[
          _SectionHeader(icon: Icons.notification_important_rounded,
              label: 'Incoming Requests', color: AppTheme.danger),
          const SizedBox(height: 12),
          StreamBuilder<List<EmergencyModel>>(
            stream: _requestsStream,
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return _DemoRequests(volunteer: vol, showAll: _showAllTasks);
              }
              final requests = snap.data ?? [];
              if (requests.isEmpty) {
                return _DemoRequests(volunteer: vol, showAll: _showAllTasks);
              }
              final displayed = _showAllTasks ? requests : requests.take(1).toList();
              return Column(children: [
                ...displayed.map((r) => _RequestCard(request: r, volunteer: vol)),
                if (requests.length > 1 && !_showAllTasks)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: TextButton.icon(
                      onPressed: () => setState(() => _showAllTasks = true),
                      icon: const Icon(Icons.list_alt_rounded, size: 18),
                      label: Text('View ${requests.length - 1} More Requests'),
                      style: TextButton.styleFrom(foregroundColor: AppTheme.textGrey),
                    ),
                  ),
              ]);
            },
          ),
        ],

        const SizedBox(height: 80),
      ]),
    );
  }

  // ── Chart helpers ──────────────────────────────────────────────────────────
  List<BarChartGroupData> _buildBarGroups(int tasks) {
    final w4 = (tasks * 0.35).clamp(1, 14).toDouble();
    final w3 = (tasks * 0.25).clamp(1, 14).toDouble();
    final w2 = (tasks * 0.22).clamp(1, 12).toDouble();
    final w1 = (tasks * 0.18).clamp(1, 10).toDouble();
    return [_bar(0, w1), _bar(1, w2), _bar(2, w3), _bar(3, w4)];
  }

  BarChartGroupData _bar(int x, double y) => BarChartGroupData(x: x, barRods: [
    BarChartRodData(
      toY: y,
      color: x == 3 ? AppTheme.orange : AppTheme.green.withValues(alpha: 0.5),
      width: 20,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
    ),
  ]);

  List<FlSpot> _buildResponseSpots(double rate) {
    final cur = (rate * 100).clamp(0, 100).toDouble();
    return [
      FlSpot(0, (cur * 0.80).clamp(40, 95)),
      FlSpot(1, (cur * 0.88).clamp(45, 97)),
      FlSpot(2, (cur * 0.92).clamp(50, 98)),
      FlSpot(3, (cur * 0.96).clamp(55, 99)),
      FlSpot(4, cur),
    ];
  }
}

// ── Section header ─────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _SectionHeader({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, color: color, size: 18),
    const SizedBox(width: 8),
    Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
  ]);
}

// ── Small badge ────────────────────────────────────────────────────────────────
class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge(this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
    child: Text(label,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
  );
}

// ── Stat card ──────────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _StatCard({required this.icon, required this.label,
      required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(16)),
    child: Row(children: [
      Container(
        width: 42, height: 42,
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: color, size: 22),
      ),
      const SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: TextStyle(
            color: color, fontWeight: FontWeight.w800, fontSize: 22)),
        Text(label, style: TextStyle(color: AppTheme.textGrey, fontSize: 11)),
      ]),
    ]),
  );
}

// ── Performance Insights Section ───────────────────────────────────────────────
class _PerformanceInsightsSection extends StatelessWidget {
  final VolunteerModel volunteer;
  const _PerformanceInsightsSection({required this.volunteer});

  @override
  Widget build(BuildContext context) {
    final insights = AllocationService.generateInsights(volunteer);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Row(children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: Colors.indigo.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.psychology_rounded,
                color: Colors.indigo, size: 18),
          ),
          const SizedBox(width: 10),
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Performance Insights',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            Text('AI-powered tips based on your data',
                style: TextStyle(color: AppTheme.textGrey, fontSize: 11)),
          ]),
        ]),
        const SizedBox(height: 14),
        // Insight cards
        ...insights.map((ins) => _InsightCard(insight: ins)),
      ]),
    );
  }
}

class _InsightCard extends StatelessWidget {
  final VolunteerInsight insight;
  const _InsightCard({required this.insight});

  (Color, IconData) get _visual => switch (insight.level) {
    InsightLevel.positive => (AppTheme.green, Icons.star_rounded),
    InsightLevel.info     => (Colors.blue,    Icons.info_rounded),
    InsightLevel.warning  => (AppTheme.orange, Icons.warning_rounded),
    InsightLevel.urgent   => (AppTheme.danger, Icons.report_rounded),
  };

  @override
  Widget build(BuildContext context) {
    final (color, icon) = _visual;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(insight.title,
              style: TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 13, color: color)),
          const SizedBox(height: 3),
          Text(insight.message,
              style: const TextStyle(fontSize: 12, height: 1.4),
              maxLines: 3, overflow: TextOverflow.ellipsis),
        ])),
      ]),
    );
  }
}

// ── Active task card ───────────────────────────────────────────────────────────
class _ActiveTaskCard extends StatelessWidget {
  final String  emergencyId;
  final String  emergencyType;
  final double  victimLat;
  final double  victimLng;
  final VolunteerModel volunteer;
  final VoidCallback onComplete;
  const _ActiveTaskCard({
    required this.emergencyId, required this.emergencyType,
    required this.victimLat,  required this.victimLng,
    required this.volunteer,  required this.onComplete,
  });

  double get _distKm => AllocationService.haversineMeters(
          volunteer.lat, volunteer.lng, victimLat, victimLng) / 1000;

  @override
  Widget build(BuildContext context) {
    final distKm = _distKm;
    final eta    = (distKm * 2).round().clamp(1, 60);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.green.withValues(alpha: 0.3)),
        boxShadow: [BoxShadow(
            color: AppTheme.green.withValues(alpha: 0.12),
            blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: Column(children: [
        // Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.green.withValues(alpha: 0.07),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
          ),
          child: Row(children: [
            const Icon(Icons.navigation_rounded, color: AppTheme.green, size: 16),
            const SizedBox(width: 8),
            Text(emergencyType, style: const TextStyle(
                color: AppTheme.green, fontWeight: FontWeight.w800, fontSize: 15)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('ACTIVE',
                  style: TextStyle(color: AppTheme.green, fontSize: 11,
                      fontWeight: FontWeight.w800)),
            ),
          ]),
        ),
        // Stats
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Row(children: [
              _ATStat(icon: Icons.place_rounded, color: AppTheme.orange,
                  label: 'Distance',
                  value: distKm < 1 ? '${(distKm * 1000).toInt()} m'
                      : '${distKm.toStringAsFixed(1)} km'),
              Container(width: 1, height: 40, color: Colors.grey.shade100),
              _ATStat(icon: Icons.timer_rounded, color: Colors.blue,
                  label: 'ETA', value: '$eta min'),
              Container(width: 1, height: 40, color: Colors.grey.shade100),
              _ATStat(icon: Icons.local_fire_department_rounded, color: AppTheme.danger,
                  label: 'Priority', value: 'HIGH'),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/volunteer-map',
                    arguments: {
                      'type':         emergencyType,
                      'victimLat':    victimLat,
                      'victimLng':    victimLng,
                      'emergencyId':  emergencyId,
                      'volunteerLat': volunteer.lat,
                      'volunteerLng': volunteer.lng,
                    }),
                  icon: const Icon(Icons.map_rounded,
                      color: Colors.white, size: 18),
                  label: const Text('Open Map',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.green,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: onComplete,
                icon: const Icon(Icons.check_rounded,
                    color: AppTheme.danger, size: 18),
                label: const Text('Complete',
                    style: TextStyle(
                        color: AppTheme.danger, fontWeight: FontWeight.w700)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      vertical: 13, horizontal: 12),
                  side: BorderSide(
                      color: AppTheme.danger.withValues(alpha: 0.35)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _ATStat extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  const _ATStat({required this.icon, required this.color,
      required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Expanded(child: Column(children: [
    Icon(icon, color: color, size: 18),
    const SizedBox(height: 2),
    Text(value, style: TextStyle(
        fontWeight: FontWeight.w800, fontSize: 15, color: color)),
    Text(label, style: TextStyle(color: AppTheme.textGrey, fontSize: 10)),
  ]));
}

// ── Request card ───────────────────────────────────────────────────────────────
class _RequestCard extends StatefulWidget {
  final EmergencyModel request;
  final VolunteerModel  volunteer;
  const _RequestCard({required this.request, required this.volunteer});
  @override
  State<_RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends State<_RequestCard> {
  bool _accepting = false;

  String _formatAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    return '${diff.inHours}h ago';
  }

  String _victimDistance() {
    final distM = AllocationService.haversineMeters(
        widget.volunteer.lat, widget.volunteer.lng,
        widget.request.userLat, widget.request.userLng);
    final km = distM / 1000;
    return km < 1 ? '${distM.toInt()} m away' : '${km.toStringAsFixed(1)} km away';
  }

  Future<void> _onAccept() async {
    setState(() => _accepting = true);

    final success = await FirestoreService.assignVolunteerToEmergency(
        widget.request.id, widget.volunteer.id);

    if (!mounted) return;
    setState(() => _accepting = false);

    if (success) {
      // Persist so the dashboard restores active task on next visit
      await FirestoreService.persistAcceptedEmergency(
        emergencyId:   widget.request.id,
        emergencyType: widget.request.type,
        victimLat:     widget.request.userLat,
        victimLng:     widget.request.userLng,
      );
      if (!mounted) return;
      // Navigate to VOLUNTEER-only map (not the victim's map)
      Navigator.pushNamed(context, '/volunteer-map', arguments: {
        'type':         widget.request.type,
        'victimLat':    widget.request.userLat,
        'victimLng':    widget.request.userLng,
        'emergencyId':  widget.request.id,
        'volunteerLat': widget.volunteer.lat,
        'volunteerLng': widget.volunteer.lng,
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Failed to accept request. Please try again.'),
        backgroundColor: AppTheme.danger,
        duration: Duration(seconds: 3),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final distLabel = _victimDistance();
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.danger.withValues(alpha: 0.2)),
        boxShadow: [BoxShadow(
            color: AppTheme.danger.withValues(alpha: 0.08),
            blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(children: [
        // Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.danger.withValues(alpha: 0.06),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Row(children: [
              const Icon(Icons.warning_rounded, color: AppTheme.danger, size: 16),
              const SizedBox(width: 6),
              Text(widget.request.type,
                  style: const TextStyle(
                      color: AppTheme.danger, fontWeight: FontWeight.w800,
                      fontSize: 15)),
            ]),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('PENDING',
                  style: TextStyle(
                      color: Colors.amber, fontSize: 11,
                      fontWeight: FontWeight.w800)),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              widget.request.specificAction.isEmpty
                  ? widget.request.type
                  : widget.request.specificAction,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.place_rounded, size: 13, color: AppTheme.orange),
              const SizedBox(width: 3),
              Text(distLabel,
                  style: const TextStyle(
                      color: AppTheme.orange, fontSize: 12,
                      fontWeight: FontWeight.w600)),
              const SizedBox(width: 10),
              Text('· ${_formatAgo(widget.request.timestamp)}',
                  style: TextStyle(
                      color: AppTheme.textGrey, fontSize: 11,
                      fontStyle: FontStyle.italic)),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              // Accept
              Expanded(child: GestureDetector(
                onTap: _accepting ? null : _onAccept,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: _accepting
                        ? AppTheme.green.withValues(alpha: 0.5)
                        : AppTheme.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _accepting
                      ? const Center(child: SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2)))
                      : const Row(mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_rounded, color: Colors.white, size: 18),
                            SizedBox(width: 6),
                            Text('Accept', style: TextStyle(
                                color: Colors.white, fontWeight: FontWeight.w700)),
                          ]),
                ),
              )),
              const SizedBox(width: 10),
              // Decline
              Expanded(child: GestureDetector(
                onTap: () => FirestoreService.updateEmergencyStatus(
                    widget.request.id, 'declined'),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.danger.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppTheme.danger.withValues(alpha: 0.25)),
                  ),
                  child: const Row(mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.close_rounded, color: AppTheme.danger, size: 18),
                        SizedBox(width: 6),
                        Text('Decline', style: TextStyle(
                            color: AppTheme.danger, fontWeight: FontWeight.w700)),
                      ]),
                ),
              )),
            ]),
          ]),
        ),
      ]),
    );
  }
}

// ── Demo requests fallback ─────────────────────────────────────────────────────
class _DemoRequests extends StatelessWidget {
  final VolunteerModel volunteer;
  final bool showAll;
  const _DemoRequests({required this.volunteer, this.showAll = false});

  @override
  Widget build(BuildContext context) {
    final demos = [
      EmergencyModel(
        id: 'demo1', victimId: 'v1', type: 'Medical',
        specificAction: 'Request medical volunteer — 0.4 km away',
        status: 'pending',
        timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
        userLat: DemoService.baseLat + 0.003, userLng: DemoService.baseLng + 0.002,
      ),
      EmergencyModel(
        id: 'demo2', victimId: 'v2', type: 'Fire',
        specificAction: 'Request evacuation help — 0.9 km away',
        status: 'pending',
        timestamp: DateTime.now().subtract(const Duration(minutes: 12)),
        userLat: DemoService.baseLat - 0.008, userLng: DemoService.baseLng + 0.004,
      ),
    ];
    final displayed = showAll ? demos : [demos.first];
    return Column(children: [
      // Demo mode info chip
      Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.green.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.green.withValues(alpha: 0.25)),
        ),
        child: const Row(children: [
          Icon(Icons.check_circle_outline_rounded,
              color: AppTheme.green, size: 16),
          SizedBox(width: 8),
          Expanded(child: Text(
            'Demo Mode — showing sample emergency requests',
            style: TextStyle(fontSize: 12, color: AppTheme.green),
          )),
        ]),
      ),
      ...displayed.map((r) => _RequestCard(request: r, volunteer: volunteer)),
    ]);
  }
}
