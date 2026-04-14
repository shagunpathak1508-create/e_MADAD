import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme/app_theme.dart';
import '../models/volunteer_model.dart';
import '../models/help_request_model.dart';
import '../services/firestore_service.dart';


class VolunteerDashboardScreen extends StatefulWidget {
  const VolunteerDashboardScreen({super.key});
  @override
  State<VolunteerDashboardScreen> createState() =>
      _VolunteerDashboardScreenState();
}

class _VolunteerDashboardScreenState extends State<VolunteerDashboardScreen> {
  VolunteerModel? _volunteer;
  bool _loading = true;
  String? _vid;

  @override
  void initState() {
    super.initState();
    _loadVolunteer();
  }

  Future<void> _loadVolunteer() async {
    final prefs = await SharedPreferences.getInstance();
    _vid = prefs.getString('volunteer_id');
    if (_vid != null) {
      final vol = await FirestoreService.getVolunteer(_vid!);
      if (!mounted) return;
      setState(() { _volunteer = vol; _loading = false; });
    } else {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _toggleAvailability() {
    if (_volunteer == null || _vid == null) return;
    final newVal = !_volunteer!.isAvailable;
    final label = newVal ? 'Go Active' : 'Turn Off Availability';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(label,
            style: const TextStyle(fontWeight: FontWeight.w800)),
        content: Text('Are you sure you want to $label?',
            style: TextStyle(color: AppTheme.textGrey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL',
                style: TextStyle(color: AppTheme.textGrey, fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await FirestoreService.updateAvailability(_vid!, newVal);
              setState(() {
                _volunteer = _volunteer!.copyWith(isAvailable: newVal);
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: newVal ? AppTheme.green : AppTheme.danger,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('YES',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator(color: AppTheme.green)));
    }

    if (_volunteer == null) {
      return Scaffold(
        backgroundColor: AppTheme.offWhite,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.person_off_rounded, size: 64, color: AppTheme.textGrey),
              const SizedBox(height: 16),
              const Text('Not registered as volunteer',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pushNamed(context, '/volunteer-signup'),
                child: const Text('Register Now'),
              ),
            ],
          ),
        ),
      );
    }

    final vol = _volunteer!;
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
          GestureDetector(
            onTap: () => Navigator.pushReplacementNamed(context, '/home'),
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              width: 38, height: 38,
              decoration: BoxDecoration(
                  color: AppTheme.orange,
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.home_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Profile Card ──────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [AppTheme.green, Color(0xFF0D6B05)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                    color: AppTheme.green.withOpacity(0.35),
                    blurRadius: 20, offset: const Offset(0, 6))
              ],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  child: Text(vol.name.isNotEmpty ? vol.name[0].toUpperCase() : '?',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(vol.name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800, fontSize: 17)),
                      Text(vol.phone,
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.8), fontSize: 13)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6, runSpacing: 4,
                        children: vol.skills.map((s) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8)),
                          child: Text(s,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                        )).toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Reliability score bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Reliability Score',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    Text('$score%',
                        style: const TextStyle(
                            color: AppTheme.orange,
                            fontWeight: FontWeight.w800, fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: score / 100,
                    minHeight: 10,
                    backgroundColor: Colors.grey.shade100,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      score >= 70 ? AppTheme.green : score >= 40 ? AppTheme.orange : AppTheme.danger,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${vol.tasksCompleted} tasks completed',
                        style: TextStyle(color: AppTheme.textGrey, fontSize: 12)),
                    Text('${(vol.responseRate * 100).toInt()}% response rate',
                        style: TextStyle(color: AppTheme.textGrey, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── Stats Row ─────────────────────────────────────────
          Row(
            children: [
              Expanded(child: _StatCard(
                icon: Icons.task_alt_rounded,
                label: 'Tasks Done',
                value: '${vol.tasksCompleted}',
                color: AppTheme.green,
              )),
              const SizedBox(width: 12),
              Expanded(child: _StatCard(
                icon: Icons.speed_rounded,
                label: 'Response Rate',
                value: '${(vol.responseRate * 100).toInt()}%',
                color: AppTheme.orange,
              )),
            ],
          ),
          const SizedBox(height: 14),

          // ── Charts ───────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Tasks Completed This Month',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 14),
                SizedBox(
                  height: 110,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: 15,
                      barTouchData: BarTouchData(enabled: false),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (v, _) => Text(
                              ['W1','W2','W3','W4'][v.toInt().clamp(0,3)],
                              style: TextStyle(
                                  fontSize: 10, color: AppTheme.textGrey),
                            ),
                          ),
                        ),
                        leftTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                      ),
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      barGroups: [
                        _bar(0, 6),
                        _bar(1, 9),
                        _bar(2, 7),
                        _bar(3, vol.tasksCompleted > 28
                            ? vol.tasksCompleted - 28
                            : 4),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Response rate line chart
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Rate of Response',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 14),
                SizedBox(
                  height: 100,
                  child: LineChart(
                    LineChartData(
                      lineBarsData: [
                        LineChartBarData(
                          spots: [
                            const FlSpot(0, 60),
                            const FlSpot(1, 72),
                            const FlSpot(2, 68),
                            const FlSpot(3, 75),
                            FlSpot(4, vol.responseRate * 100),
                          ],
                          isCurved: true,
                          color: AppTheme.orange,
                          barWidth: 2.5,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: AppTheme.orange.withOpacity(0.08),
                          ),
                        ),
                      ],
                      titlesData: const FlTitlesData(show: false),
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      minY: 0, maxY: 100,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── Availability Toggle ───────────────────────────────
          GestureDetector(
            onTap: _toggleAvailability,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: vol.isAvailable
                    ? AppTheme.danger.withOpacity(0.07)
                    : AppTheme.green.withOpacity(0.07),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: vol.isAvailable
                      ? AppTheme.danger.withOpacity(0.25)
                      : AppTheme.green.withOpacity(0.25),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    vol.isAvailable
                        ? Icons.power_settings_new_rounded
                        : Icons.check_circle_outline_rounded,
                    color: vol.isAvailable ? AppTheme.danger : AppTheme.green,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    vol.isAvailable ? 'Turn Off Availability' : 'Go Active',
                    style: TextStyle(
                      color: vol.isAvailable ? AppTheme.danger : AppTheme.green,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ── Incoming Requests ─────────────────────────────────
          Row(
            children: [
              Container(width: 8, height: 8,
                  decoration: const BoxDecoration(
                      color: AppTheme.danger, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              const Text('Incoming Requests',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            ],
          ),
          const SizedBox(height: 12),

          StreamBuilder<List<HelpRequestModel>>(
            stream: FirestoreService.volunteerIncomingRequests(),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(color: AppTheme.orange));
              }
              final requests = snap.data ?? [];
              if (requests.isEmpty) {
                return _DemoRequests(volunteerId: _vid ?? '');
              }
              return Column(
                children: requests.map((r) => _RequestCard(
                  request: r,
                  volunteerId: _vid ?? '',
                )).toList(),
              );
            },
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  BarChartGroupData _bar(int x, double y) => BarChartGroupData(
    x: x,
    barRods: [
      BarChartRodData(
        toY: y,
        color: x == 3 ? AppTheme.orange : AppTheme.green.withOpacity(0.5),
        width: 20,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
      ),
    ],
  );
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _StatCard({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: TextStyle(
                      color: color, fontWeight: FontWeight.w800, fontSize: 22)),
              Text(label,
                  style: TextStyle(color: AppTheme.textGrey, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final HelpRequestModel request;
  final String volunteerId;
  const _RequestCard({required this.request, required this.volunteerId});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.danger.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
              color: AppTheme.danger.withOpacity(0.08),
              blurRadius: 12, offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          // Type header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.danger.withOpacity(0.06),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.warning_rounded,
                        color: AppTheme.danger, size: 16),
                    const SizedBox(width: 6),
                    Text(request.emergencyType,
                        style: const TextStyle(
                            color: AppTheme.danger,
                            fontWeight: FontWeight.w800, fontSize: 15)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('PENDING',
                      style: TextStyle(
                          color: Colors.amber,
                          fontSize: 11, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(request.specificAction,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          await FirestoreService.updateRequestStatus(
                              request.id, 'accepted');
                          if (!context.mounted) return;
                          Navigator.pushNamed(context, '/map',
                              arguments: request.emergencyType);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: AppTheme.green,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_rounded,
                                  color: Colors.white, size: 18),
                              SizedBox(width: 6),
                              Text('Accept',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => FirestoreService.updateRequestStatus(
                            request.id, 'declined'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: AppTheme.danger.withOpacity(0.07),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: AppTheme.danger.withOpacity(0.25)),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.close_rounded,
                                  color: AppTheme.danger, size: 18),
                              SizedBox(width: 6),
                              Text('Decline',
                                  style: TextStyle(
                                      color: AppTheme.danger,
                                      fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DemoRequests extends StatelessWidget {
  final String volunteerId;
  const _DemoRequests({required this.volunteerId});

  @override
  Widget build(BuildContext context) {
    final demos = [
      HelpRequestModel(
        id: 'demo1',
        victimId: 'v1',
        emergencyType: 'Medical',
        specificAction: 'Request medical volunteer',
        status: 'pending',
        timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
      ),
      HelpRequestModel(
        id: 'demo2',
        victimId: 'v2',
        emergencyType: 'Fire',
        specificAction: 'Request help with evacuation',
        status: 'pending',
        timestamp: DateTime.now().subtract(const Duration(minutes: 12)),
      ),
    ];
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amber.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.withOpacity(0.3)),
          ),
          child: const Row(
            children: [
              Icon(Icons.wifi_off_rounded, color: Colors.amber, size: 16),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Demo data — Connect Firebase to see live requests',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        ...demos.map((r) => _RequestCard(request: r, volunteerId: volunteerId)),
      ],
    );
  }
}
