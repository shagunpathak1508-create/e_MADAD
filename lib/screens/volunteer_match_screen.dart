import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/volunteer_model.dart';
import '../services/firestore_service.dart';
import '../services/sms_service.dart';
import '../services/cache_service.dart';
import '../services/demo_service.dart';
import '../services/allocation_service.dart';
import '../services/location_service.dart';
import '../services/gemini_matching_service.dart';

class VolunteerMatchScreen extends StatefulWidget {
  const VolunteerMatchScreen({super.key});
  @override
  State<VolunteerMatchScreen> createState() => _VolunteerMatchScreenState();
}

class _VolunteerMatchScreenState extends State<VolunteerMatchScreen>
    with SingleTickerProviderStateMixin {
  String _emergencyType = '';
  String _action        = '';
  bool   _isInit        = false;

  // Victim position — default to demo base coords
  double _victimLat = DemoService.baseLat;
  double _victimLng = DemoService.baseLng;

  // Volunteer data: Firestore stream + in-memory fallback
  Stream<List<VolunteerModel>>? _rawStream;
  List<VolunteerModel> _fallback = [];

  // ── AI Matching state ─────────────────────────────────────────────────────
  GeminiMatchResult? _aiResult;      // null until AI has responded
  bool _isAiLoading = false;         // shows shimmer/spinner
  bool _aiCalled    = false;         // prevents duplicate calls
  late final AnimationController _pulseCtrl;
  late final Animation<double>   _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _bootstrapFallback();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  /// Pre-load cached / demo data so the list is never empty on load.
  Future<void> _bootstrapFallback() async {
    final pos     = await LocationService.getCurrentLocation();
    final cached  = await CacheService.getCachedVolunteers();
    final allVols = cached.isNotEmpty ? cached : DemoService.dummyVolunteers;

    if (mounted) {
      setState(() {
        _victimLat = pos.latitude;
        _victimLng = pos.longitude;
        _fallback  = AllocationService.rankVolunteers(
            _emergencyType.isEmpty ? 'Medical' : _emergencyType,
            allVols, _victimLat, _victimLng);
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInit) {
      final args = ModalRoute.of(context)?.settings.arguments
          as Map<String, dynamic>?;
      _emergencyType = args?['emergencyType'] ?? 'Medical';
      _action        = args?['action']        ?? '';
      _rawStream     = FirestoreService.topMatches(_emergencyType,
          lat: _victimLat, lng: _victimLng);
      _isInit = true;

      // Refine fallback for this specific emergency type
      _fallback = AllocationService.rankVolunteers(
          _emergencyType,
          DemoService.filteredVolunteers(_emergencyType),
          _victimLat, _victimLng);
    }
  }

  // ── AI Matching trigger ───────────────────────────────────────────────────

  /// Called ONCE when "Find Best Match" is tapped.
  /// Runs asynchronously — UI stays fully responsive.
  Future<void> _runAiMatching(List<VolunteerModel> pool) async {
    if (_aiCalled || _isAiLoading) return; // guard: no repeated calls
    setState(() {
      _isAiLoading = true;
      _aiCalled    = true;
    });

    final emergencyId = FirestoreService.currentEmergencyId ?? '';

    try {
      final result = await GeminiMatchingService.findBestVolunteer(
        emergencyType: _emergencyType,
        victimLat:     _victimLat,
        victimLng:     _victimLng,
        allVolunteers: pool,
        emergencyId:   emergencyId,
      );

      if (!mounted) return;
      setState(() {
        _aiResult    = result;
        _isAiLoading = false;
      });

      // Assign best volunteer to the emergency in Firestore (non-blocking)
      if (result.bestVolunteer.id.isNotEmpty) {
        FirestoreService.assignAIMatch(
          emergencyId: emergencyId,
          volunteerId: result.bestVolunteer.id,
          usedAI:      result.usedAI,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isAiLoading = false);
      debugPrint('[VolunteerMatchScreen] _runAiMatching error: $e');
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
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
                borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                size: 18, color: AppTheme.textDark),
          ),
        ),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Best Matched Volunteers',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          Text('Sorted by skill · distance · reliability',
              style: TextStyle(fontSize: 11, color: AppTheme.textGrey)),
        ]),
        actions: [
          // ── "AI Matching Enabled" badge ─────────────────────────────────
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6C47FF), Color(0xFF9B7BFF)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6C47FF).withValues(alpha: 0.30),
                  blurRadius: 8, offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.auto_awesome_rounded,
                  size: 12, color: Colors.white),
              const SizedBox(width: 4),
              const Text('AI Matching',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3)),
            ]),
          ),
        ],
      ),

      // ── Floating "Find Best Match" button ─────────────────────────────────
      floatingActionButton: !_aiCalled
          ? _FindBestButton(
              onTap: () {
                // Pull the current pool from wherever we have it
                final pool = _aiResult?.rankedList.isNotEmpty == true
                    ? _aiResult!.rankedList
                    : _fallback;
                _runAiMatching(pool);
              },
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,

      body: StreamBuilder<List<VolunteerModel>>(
        stream: _rawStream,
        builder: (context, snap) {
          // Apply AllocationService ranking to whatever comes from Firestore
          final List<VolunteerModel> ranked;
          if (snap.hasData && snap.data!.isNotEmpty) {
            ranked = AllocationService.rankVolunteers(
                _emergencyType, snap.data!, _victimLat, _victimLng);
            CacheService.cacheVolunteers(snap.data!);
          } else {
            ranked = _fallback;
          }

          // After AI responds, use AI-ranked list; otherwise use AllocationService list
          final List<VolunteerModel> display =
              (_aiResult?.rankedList.isNotEmpty == true)
                  ? _aiResult!.rankedList
                  : ranked.take(3).toList();

          // Best volunteer ID (for badge)
          final bestId = _aiResult?.bestVolunteer.id ?? '';

          return Stack(
            children: [
              ListView(
                padding: EdgeInsets.only(
                  left: 16, right: 16, top: 16,
                  // Extra bottom padding so FAB doesn't cover last card
                  bottom: _aiCalled ? 24 : 100,
                ),
                children: [
                  // ── Request banner ────────────────────────────────────────
                  _RequestBanner(
                    action:        _action,
                    emergencyType: _emergencyType,
                  ),
                  const SizedBox(height: 14),

                  // ── AI result summary banner ──────────────────────────────
                  if (_aiResult != null)
                    _AiResultBanner(
                      usedAI:   _aiResult!.usedAI,
                      bestName: _aiResult!.bestVolunteer.name,
                    ),
                  if (_aiResult != null) const SizedBox(height: 14),

                  // ── Skill filter caption ──────────────────────────────────
                  _SkillFilterChip(emergencyType: _emergencyType),
                  const SizedBox(height: 14),

                  // ── Volunteer cards ───────────────────────────────────────
                  if (display.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text('Searching for volunteers…',
                            style: TextStyle(
                                color: AppTheme.textGrey, fontSize: 14)),
                      ),
                    )
                  else
                    ...display.asMap().entries.map((e) => _VolunteerCard(
                          vol:           e.value,
                          rank:          e.key + 1,
                          emergencyType: _emergencyType,
                          victimLat:     _victimLat,
                          victimLng:     _victimLng,
                          isAiBest:      _aiResult != null &&
                                         e.value.id == bestId &&
                                         e.value.id.isNotEmpty,
                        )),

                  const SizedBox(height: 24),
                ],
              ),

              // ── AI Loading overlay ────────────────────────────────────────
              if (_isAiLoading) _AiLoadingOverlay(pulseAnim: _pulseAnim),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// "Find Best Match" FAB
// ─────────────────────────────────────────────────────────────────────────────
class _FindBestButton extends StatelessWidget {
  final VoidCallback onTap;
  const _FindBestButton({required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 28),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6C47FF), Color(0xFF9B7BFF)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6C47FF).withValues(alpha: 0.45),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: const [
            Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text(
              'Find Best Match',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  letterSpacing: 0.3),
            ),
          ]),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// AI Loading Overlay
// ─────────────────────────────────────────────────────────────────────────────
class _AiLoadingOverlay extends StatelessWidget {
  final Animation<double> pulseAnim;
  const _AiLoadingOverlay({required this.pulseAnim});

  @override
  Widget build(BuildContext context) => Positioned.fill(
        child: Container(
          color: Colors.black.withValues(alpha: 0.30),
          child: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 40),
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                      color: const Color(0xFF6C47FF).withValues(alpha: 0.25),
                      blurRadius: 32,
                      offset: const Offset(0, 8)),
                ],
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                // Pulsing AI icon
                AnimatedBuilder(
                  animation: pulseAnim,
                  builder: (_, __) => Opacity(
                    opacity: pulseAnim.value,
                    child: Container(
                      width: 64, height: 64,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6C47FF), Color(0xFF9B7BFF)],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6C47FF)
                                .withValues(alpha: pulseAnim.value * 0.5),
                            blurRadius: 20,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.auto_awesome_rounded,
                          color: Colors.white, size: 30),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text('AI Matching Volunteers',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: AppTheme.textDark)),
                const SizedBox(height: 8),
                Text('Analysing skills, distance\n& reliability…',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textGrey,
                        height: 1.5)),
                const SizedBox(height: 18),
                const SizedBox(
                  width: 160,
                  child: LinearProgressIndicator(
                    backgroundColor: Color(0xFFEDE9FF),
                    color: Color(0xFF6C47FF),
                    minHeight: 3,
                    borderRadius: BorderRadius.all(Radius.circular(4)),
                  ),
                ),
              ]),
            ),
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// AI result summary banner
// ─────────────────────────────────────────────────────────────────────────────
class _AiResultBanner extends StatelessWidget {
  final bool   usedAI;
  final String bestName;
  const _AiResultBanner({required this.usedAI, required this.bestName});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: usedAI
                ? [const Color(0xFF6C47FF).withValues(alpha: 0.08),
                   const Color(0xFF9B7BFF).withValues(alpha: 0.04)]
                : [AppTheme.orange.withValues(alpha: 0.08),
                   AppTheme.orange.withValues(alpha: 0.04)],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: usedAI
                ? const Color(0xFF6C47FF).withValues(alpha: 0.25)
                : AppTheme.orange.withValues(alpha: 0.25),
          ),
        ),
        child: Row(children: [
          Icon(
            usedAI ? Icons.auto_awesome_rounded : Icons.sort_rounded,
            color: usedAI ? const Color(0xFF6C47FF) : AppTheme.orange,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 12, color: AppTheme.textDark),
                children: [
                  TextSpan(
                    text: usedAI ? 'AI recommends ' : 'Best match (score-based): ',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  TextSpan(
                    text: bestName,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: usedAI ? const Color(0xFF6C47FF) : AppTheme.green,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ]),
      );
}

// ── Request banner ─────────────────────────────────────────────────────────────
class _RequestBanner extends StatelessWidget {
  final String action;
  final String emergencyType;
  const _RequestBanner({required this.action, required this.emergencyType});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppTheme.orange.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppTheme.orange.withValues(alpha: 0.25)),
    ),
    child: Row(children: [
      const Icon(Icons.info_outline_rounded, color: AppTheme.orange, size: 20),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          action.isEmpty ? '$emergencyType emergency — help needed' : action,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ),
    ]),
  );
}

// ── Skill filter chip ──────────────────────────────────────────────────────────
class _SkillFilterChip extends StatelessWidget {
  final String emergencyType;
  const _SkillFilterChip({required this.emergencyType});

  @override
  Widget build(BuildContext context) {
    final skills = AllocationService.skillsForEmergency(emergencyType);
    return Wrap(
      spacing: 6, runSpacing: 4,
      children: [
        Text('Filtering by:',
            style: TextStyle(color: AppTheme.textGrey, fontSize: 12)),
        ...skills.map((s) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: AppTheme.green.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.green.withValues(alpha: 0.3)),
          ),
          child: Text(s,
              style: const TextStyle(
                  color: AppTheme.green, fontSize: 11,
                  fontWeight: FontWeight.w600)),
        )),
      ],
    );
  }
}

// ── Volunteer card ────────────────────────────────────────────────────────────
class _VolunteerCard extends StatelessWidget {
  final VolunteerModel vol;
  final int    rank;
  final String emergencyType;
  final double victimLat;
  final double victimLng;
  final bool   isAiBest;          // true → show "AI Pick 🤖" badge

  const _VolunteerCard({
    required this.vol,  required this.rank,
    required this.emergencyType, required this.victimLat, required this.victimLng,
    this.isAiBest = false,
  });

  @override
  Widget build(BuildContext context) {
    final matchPct   = AllocationService.matchPercent(vol, victimLat, victimLng);
    final skillMatch = AllocationService.hasSkillMatch(vol, emergencyType);
    final distM      = AllocationService.haversineMeters(
        vol.lat, vol.lng, victimLat, victimLng);
    final distKm     = distM / 1000;
    final distLabel  = distKm < 1
        ? '${distM.toInt()} m'
        : '${distKm.toStringAsFixed(1)} km';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(
            color: isAiBest
                ? const Color(0xFF6C47FF).withValues(alpha: 0.15)
                : Colors.black.withValues(alpha: 0.06),
            blurRadius: isAiBest ? 18 : 12,
            offset: const Offset(0, 4))],
        border: isAiBest
            ? Border.all(
                color: const Color(0xFF6C47FF).withValues(alpha: 0.35),
                width: 1.5)
            : null,
      ),
      child: Column(children: [
        // ── Header ──────────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isAiBest
                ? const Color(0xFF6C47FF).withValues(alpha: 0.05)
                : AppTheme.green.withValues(alpha: 0.05),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
          ),
          child: Row(children: [
            // Rank badge
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: rank == 1
                    ? Colors.amber
                    : rank == 2 ? Colors.grey.shade400 : Colors.brown.shade300,
                shape: BoxShape.circle,
              ),
              child: Center(child: Text('$rank',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 12,
                      fontWeight: FontWeight.w900))),
            ),
            const SizedBox(width: 10),
            // Avatar
            CircleAvatar(
              radius: 20,
              backgroundColor: isAiBest
                  ? const Color(0xFF6C47FF).withValues(alpha: 0.12)
                  : AppTheme.green.withValues(alpha: 0.15),
              child: Text(
                vol.name.isNotEmpty ? vol.name[0].toUpperCase() : '?',
                style: TextStyle(
                    color: isAiBest ? const Color(0xFF6C47FF) : AppTheme.green,
                    fontWeight: FontWeight.w800,
                    fontSize: 16),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Row(children: [
                  Flexible(child: Text(vol.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14))),
                  // AI Pick badge
                  if (isAiBest) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6C47FF), Color(0xFF9B7BFF)],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('AI Pick 🤖',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800)),
                    ),
                  ],
                ]),
                Text('⭐ ${vol.displayRating.toStringAsFixed(1)} · $distLabel',
                    style: TextStyle(color: AppTheme.textGrey, fontSize: 12)),
              ]),
            ),
            // Match % badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _matchColor(matchPct).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: _matchColor(matchPct).withValues(alpha: 0.35)),
              ),
              child: Text('$matchPct%',
                  style: TextStyle(
                      color: _matchColor(matchPct), fontSize: 13,
                      fontWeight: FontWeight.w900)),
            ),
          ]),
        ),

        // ── Skills + skill-match indicator ───────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Row(children: [
            Expanded(
              child: Wrap(spacing: 6, runSpacing: 4,
                children: vol.skills.map((s) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.orange.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(s,
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w600,
                          color: AppTheme.orange)),
                )).toList(),
              ),
            ),
            const SizedBox(width: 8),
            // Skill match indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: skillMatch
                    ? AppTheme.green.withValues(alpha: 0.08)
                    : Colors.grey.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(
                  skillMatch
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: skillMatch ? AppTheme.green : AppTheme.textGrey,
                  size: 13,
                ),
                const SizedBox(width: 4),
                Text(
                  skillMatch ? 'Skill Match' : 'General',
                  style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w700,
                      color: skillMatch ? AppTheme.green : AppTheme.textGrey),
                ),
              ]),
            ),
          ]),
        ),

        // ── Stats ────────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(children: [
            _MiniStat(
                icon: Icons.task_alt_rounded,
                color: AppTheme.green,
                label: '${vol.tasksCompleted} tasks'),
            const SizedBox(width: 12),
            _MiniStat(
                icon: Icons.speed_rounded,
                color: Colors.blue,
                label: '~${vol.avgResponseTime.toStringAsFixed(0)} min avg'),
            const SizedBox(width: 12),
            _MiniStat(
                icon: Icons.place_rounded,
                color: AppTheme.orange,
                label: distLabel),
          ]),
        ),

        // ── Action buttons ───────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: Row(children: [
            Expanded(child: _Btn(
              label: 'Call', icon: Icons.phone_rounded, color: AppTheme.green,
              onTap: () => SmsService.callNumber(vol.phone),
            )),
            const SizedBox(width: 10),
            Expanded(child: _Btn(
              label: 'SMS', icon: Icons.sms_rounded,
              color: AppTheme.orange, outlined: true,
              onTap: () => SmsService.sendEmergencySMS(
                  emergencyType: emergencyType,
                  action: 'I need urgent help',
                  lat: null, lng: null, recipients: [vol.phone]),
            )),
          ]),
        ),
      ]),
    );
  }

  Color _matchColor(int pct) {
    if (pct >= 75) return AppTheme.green;
    if (pct >= 50) return AppTheme.orange;
    return AppTheme.danger;
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  const _MiniStat({required this.icon,required this.color,required this.label});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, color: color, size: 13),
      const SizedBox(width: 3),
      Text(label, style: TextStyle(color: AppTheme.textGrey, fontSize: 11)),
    ],
  );
}

class _Btn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool outlined;
  final VoidCallback onTap;
  const _Btn({required this.label, required this.icon, required this.color,
      this.outlined = false, required this.onTap});

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
        Text(label,
            style: TextStyle(
                color: outlined ? color : Colors.white,
                fontWeight: FontWeight.w700, fontSize: 13)),
      ]),
    ),
  );
}
