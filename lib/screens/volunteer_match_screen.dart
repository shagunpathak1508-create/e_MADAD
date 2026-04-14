import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/volunteer_model.dart';
import '../services/firestore_service.dart';
import '../services/sms_service.dart';

class VolunteerMatchScreen extends StatefulWidget {
  const VolunteerMatchScreen({super.key});
  @override
  State<VolunteerMatchScreen> createState() => _VolunteerMatchScreenState();
}

class _VolunteerMatchScreenState extends State<VolunteerMatchScreen> {
  String _emergencyType = '';
  String _action = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    _emergencyType = args?['emergencyType'] ?? 'Medical';
    _action = args?['action'] ?? '';
  }

  @override
  Widget build(BuildContext context) {
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
              color: AppTheme.offWhite,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                size: 18, color: AppTheme.textDark),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Available Volunteers',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            Text('Best matched for $_emergencyType',
                style: TextStyle(fontSize: 12, color: AppTheme.textGrey)),
          ],
        ),
      ),
      body: StreamBuilder<List<VolunteerModel>>(
        stream: FirestoreService.topMatches(_emergencyType),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: AppTheme.orange));
          }
          final volunteers = snap.data ?? _demoVolunteers();
          if (volunteers.isEmpty) {
            return _buildEmpty();
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Request info banner
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.orange.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border:
                      Border.all(color: AppTheme.orange.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        color: AppTheme.orange, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _action,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text('${volunteers.length} volunteers found',
                  style: TextStyle(
                      color: AppTheme.textGrey,
                      fontSize: 13,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 10),
              ...volunteers.asMap().entries.map((entry) =>
                  _VolunteerCard(
                    vol: entry.value,
                    isBestMatch: entry.key == 0,
                    action: _action,
                    emergencyType: _emergencyType,
                  )),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmpty() {
    final demos = _demoVolunteers();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.amber.withOpacity(0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.amber.withOpacity(0.3)),
          ),
          child: const Row(
            children: [
              Icon(Icons.wifi_off_rounded, color: Colors.amber),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Showing cached volunteers. Connect to internet for live matching.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ...demos.asMap().entries.map((e) => _VolunteerCard(
              vol: e.value,
              isBestMatch: e.key == 0,
              action: _action,
              emergencyType: _emergencyType,
            )),
      ],
    );
  }

  List<VolunteerModel> _demoVolunteers() => [
        VolunteerModel(
            id: '1', name: 'Rajesh Kumar', phone: '+91 98765 43210',
            skills: ['First Aid', 'Transport'], isAvailable: true,
            tasksCompleted: 34, responseRate: 0.91),
        VolunteerModel(
            id: '2', name: 'Priya Sharma', phone: '+91 87654 32109',
            skills: ['First Aid', 'Shelter'], isAvailable: true,
            tasksCompleted: 22, responseRate: 0.78),
        VolunteerModel(
            id: '3', name: 'Arjun Mehta', phone: '+91 76543 21098',
            skills: ['Transport', 'Search & Rescue'], isAvailable: true,
            tasksCompleted: 15, responseRate: 0.65),
      ];
}

class _VolunteerCard extends StatelessWidget {
  final VolunteerModel vol;
  final bool isBestMatch;
  final String action;
  final String emergencyType;

  const _VolunteerCard({
    required this.vol,
    required this.isBestMatch,
    required this.action,
    required this.emergencyType,
  });

  @override
  Widget build(BuildContext context) {
    final score = vol.reliabilityScore.toInt();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: isBestMatch
            ? Border.all(color: AppTheme.orange, width: 2)
            : Border.all(color: Colors.transparent),
        boxShadow: [
          BoxShadow(
              color: isBestMatch
                  ? AppTheme.orange.withOpacity(0.15)
                  : Colors.black.withOpacity(0.05),
              blurRadius: 16,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          if (isBestMatch)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.orange,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: const Text('⭐ Best Match',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12)),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppTheme.orange.withOpacity(0.15),
                      child: Text(
                        vol.name.isNotEmpty ? vol.name[0].toUpperCase() : '?',
                        style: const TextStyle(
                            color: AppTheme.orange,
                            fontWeight: FontWeight.w800,
                            fontSize: 20),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(vol.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 15)),
                          const SizedBox(height: 3),
                          Wrap(
                            spacing: 6,
                            children: vol.skills.take(3).map((s) =>
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                    color: AppTheme.green.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8)),
                                child: Text(s,
                                    style: const TextStyle(
                                        color: AppTheme.green, fontSize: 11,
                                        fontWeight: FontWeight.w600)),
                              )).toList(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Reliability score
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Reliability Score',
                                  style: TextStyle(
                                      color: AppTheme.textGrey, fontSize: 12)),
                              Text('$score%',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                      color: AppTheme.orange)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: score / 100,
                              minHeight: 6,
                              backgroundColor: Colors.grey.shade200,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                score >= 70
                                    ? AppTheme.green
                                    : score >= 40
                                        ? AppTheme.orange
                                        : AppTheme.danger,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('${vol.tasksCompleted} tasks done',
                                  style: TextStyle(
                                      color: AppTheme.textGrey, fontSize: 11)),
                              Text(
                                  '${(vol.responseRate * 100).toInt()}% response rate',
                                  style: TextStyle(
                                      color: AppTheme.textGrey, fontSize: 11)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Call + SMS buttons
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => SmsService.callNumber(vol.phone),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                              color: AppTheme.green,
                              borderRadius: BorderRadius.circular(12)),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.phone_rounded,
                                  color: Colors.white, size: 18),
                              SizedBox(width: 8),
                              Text('Call',
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
                        onTap: () => SmsService.sendEmergencySMS(
                          emergencyType: emergencyType,
                          action: action,
                          lat: null, lng: null,
                          recipients: [vol.phone],
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                              color: AppTheme.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: AppTheme.orange.withOpacity(0.3))),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.sms_rounded,
                                  color: AppTheme.orange, size: 18),
                              SizedBox(width: 8),
                              Text('SMS',
                                  style: TextStyle(
                                      color: AppTheme.orange,
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
