import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../models/volunteer_model.dart';
import '../services/demo_service.dart';

/// Demo Login Screen — replaces volunteer signup during demo mode.
///
/// Presents the 8 pre-seeded demo volunteers for the user to "log in as".
/// On selection, the chosen volunteer's ID is persisted in SharedPreferences
/// and the app navigates directly to the Volunteer Dashboard.
class DemoLoginScreen extends StatefulWidget {
  const DemoLoginScreen({super.key});
  @override
  State<DemoLoginScreen> createState() => _DemoLoginScreenState();
}

class _DemoLoginScreenState extends State<DemoLoginScreen> {
  String? _selectedId;
  bool _loading = false;

  Future<void> _loginAs(VolunteerModel vol) async {
    setState(() {
      _selectedId = vol.id;
      _loading    = true;
    });

    // Persist choice so the Dashboard can load this volunteer's profile
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('volunteer_id',    vol.id);
    await prefs.setString('volunteer_name',  vol.name);
    await prefs.setString('volunteer_phone', vol.phone);

    if (!mounted) return;
    setState(() => _loading = false);
    Navigator.pushReplacementNamed(context, '/dashboard');
  }

  @override
  Widget build(BuildContext context) {
    final volunteers = DemoService.dummyVolunteers;
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
        title: const Text('Select Demo Volunteer',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
      ),
      body: Column(
        children: [
          // ── Demo mode banner ─────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [AppTheme.green, Color(0xFF0D6B05)]),
            ),
            child: Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.volunteer_activism_rounded,
                      color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Demo Mode — Pick a Profile',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 14)),
                      Text('Select any volunteer to log in instantly',
                          style: TextStyle(
                              color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Volunteer list ───────────────────────────────────────────────
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: volunteers.length,
              itemBuilder: (context, index) {
                final vol      = volunteers[index];
                final selected = _selectedId == vol.id;
                return _VolunteerTile(
                  vol:      vol,
                  selected: selected,
                  loading:  _loading && selected,
                  onTap:    () => _loginAs(vol),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Volunteer tile card ────────────────────────────────────────────────────────
class _VolunteerTile extends StatelessWidget {
  final VolunteerModel vol;
  final bool selected;
  final bool loading;
  final VoidCallback onTap;

  const _VolunteerTile({
    required this.vol,
    required this.selected,
    required this.loading,
    required this.onTap,
  });

  Color get _skillColor {
    switch (vol.skill) {
      case 'Medical':    return Colors.blue;
      case 'Fire':       return Colors.deepOrange;
      case 'Rescue':     return Colors.purple;
      case 'First Aid':  return Colors.teal;
      default:           return AppTheme.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final reliabilityStars = vol.displayRating;

    return GestureDetector(
      onTap: loading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.green.withValues(alpha: 0.06)
              : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? AppTheme.green
                : const Color(0xFFE8E8E8),
            width: selected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: selected ? 0.08 : 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 26,
              backgroundColor: _skillColor.withValues(alpha: 0.15),
              child: Text(
                vol.name[0].toUpperCase(),
                style: TextStyle(
                    color: _skillColor,
                    fontSize: 22,
                    fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 14),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(vol.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      // Skill badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _skillColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(vol.skill,
                            style: TextStyle(
                                color: _skillColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(width: 8),
                      // Distance
                      Icon(Icons.place_rounded,
                          size: 12, color: AppTheme.textGrey),
                      const SizedBox(width: 2),
                      Text('${vol.distance.toStringAsFixed(1)} km',
                          style: TextStyle(
                              color: AppTheme.textGrey, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Stars + tasks
                  Row(
                    children: [
                      ...List.generate(5, (i) {
                        final filled = i < reliabilityStars.floor();
                        final half   = !filled &&
                            i < reliabilityStars &&
                            (reliabilityStars - i) >= 0.5;
                        return Icon(
                          half
                              ? Icons.star_half_rounded
                              : filled
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                          size: 14,
                          color: Colors.amber,
                        );
                      }),
                      const SizedBox(width: 4),
                      Text(reliabilityStars.toStringAsFixed(1),
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 8),
                      Text('${vol.tasksCompleted} tasks',
                          style: TextStyle(
                              color: AppTheme.textGrey, fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ),

            // Right: select button or loader
            if (loading)
              const SizedBox(
                width: 22, height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppTheme.green),
              )
            else
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: selected ? AppTheme.green : AppTheme.offWhite,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  selected
                      ? Icons.check_rounded
                      : Icons.arrow_forward_ios_rounded,
                  color: selected ? Colors.white : AppTheme.textGrey,
                  size: 16,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
