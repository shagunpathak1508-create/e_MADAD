import 'dart:math' as math;
import '../models/volunteer_model.dart';
import '../services/nearby_service.dart';

// ── Insight level enum ────────────────────────────────────────────────────────
enum InsightLevel { positive, info, warning, urgent }

// ── Volunteer insight data object ─────────────────────────────────────────────
class VolunteerInsight {
  final String title;
  final String message;
  final InsightLevel level;
  const VolunteerInsight({
    required this.title,
    required this.message,
    required this.level,
  });
}

// Internal helper for sorting before exposing insights
class _RankedInsight {
  final int priority; // higher = shown first
  final VolunteerInsight insight;
  const _RankedInsight({required this.priority, required this.insight});
}

/// Intelligent volunteer matching, filtering, and insight engine.
///
/// Provides:
///   - Skill-based emergency ↔ volunteer matching
///   - Service-type filtering per emergency type
///   - Composite allocation scoring (distance + reliability + response rate)
///   - Dynamic performance insights from volunteer statistics
class AllocationService {
  // ── Emergency type → required volunteer skills ──────────────────────────────
  static const Map<String, List<String>> _emergencySkillMap = {
    'Medical':      ['Medical', 'First Aid'],
    'Fire':         ['Firefighting', 'Evacuation'],
    'Accident':     ['First Aid', 'Medical', 'Transport'],
    'Disaster':     ['Search & Rescue', 'Shelter', 'Food & Water', 'Evacuation'],
    'Safety':       ['First Aid', 'Transport'],
    'Help Request': ['Transport', 'First Aid'],
  };

  // ── Emergency type → relevant place types ───────────────────────────────────
  static const Map<String, List<String>> _emergencyServiceMap = {
    'Medical':      ['hospital'],
    'Fire':         ['fire_station', 'hospital'],
    'Accident':     ['hospital', 'police'],
    'Disaster':     ['shelter', 'hospital', 'police'],
    'Safety':       ['police', 'hospital'],
    'Help Request': ['hospital', 'police'],
  };

  /// Volunteer skills required for the given emergency type.
  static List<String> skillsForEmergency(String type) =>
      _emergencySkillMap[type] ?? ['First Aid', 'Medical'];

  /// Nearby-place types relevant to the given emergency type.
  static List<String> servicesForEmergency(String type) =>
      _emergencyServiceMap[type] ?? ['hospital', 'police'];

  // ── Composite allocation score (0.0–1.0) ────────────────────────────────────
  //
  //   40%  distance    (closer = better; 10 km normalisation cap)
  //   35%  reliability (from VolunteerModel.reliabilityScore / 100)
  //   25%  response rate (0.0–1.0 stored in Firestore)
  //
  static double scoreVolunteer(
      VolunteerModel vol, double victimLat, double victimLng) {
    final distM         = haversineMeters(vol.lat, vol.lng, victimLat, victimLng);
    final distKm        = distM / 1000;
    final distScore     = (1.0 - distKm / 10.0).clamp(0.0, 1.0);
    final relScore      = (vol.reliabilityScore / 100.0).clamp(0.0, 1.0);
    final responseScore = vol.responseRate.clamp(0.0, 1.0);

    return (0.40 * distScore) + (0.35 * relScore) + (0.25 * responseScore);
  }

  /// Match percentage (0–100) displayed as a UI badge.
  static int matchPercent(
          VolunteerModel vol, double victimLat, double victimLng) =>
      (scoreVolunteer(vol, victimLat, victimLng) * 100).round().clamp(0, 100);

  /// True if the volunteer's skill list overlaps the emergency type's
  /// required skills.
  static bool hasSkillMatch(VolunteerModel vol, String emergencyType) {
    final required = skillsForEmergency(emergencyType);
    return vol.skills.any((s) => required.contains(s));
  }

  // ── Ranked allocation ────────────────────────────────────────────────────────
  /// Returns up to [limit] volunteers ranked by composite score.
  ///
  /// Algorithm:
  ///   1. Keep only available volunteers whose skills match the emergency type.
  ///   2. If the strict filter yields nothing, fall back to all available volunteers.
  ///   3. Sort descending by composite score.
  ///   4. Return top [limit] results.
  static List<VolunteerModel> rankVolunteers(
    String emergencyType,
    List<VolunteerModel> volunteers,
    double victimLat,
    double victimLng, {
    int limit = 5,
  }) {
    final required = skillsForEmergency(emergencyType);

    // Strict filter — available + skill match
    final matched = volunteers
        .where((v) => v.available && v.skills.any((s) => required.contains(s)))
        .toList();

    // Fallback: all available volunteers if strict filter is empty
    final pool = matched.isNotEmpty
        ? matched
        : volunteers.where((v) => v.available).toList();

    // Sort by composite score descending
    pool.sort((a, b) {
      final sa = scoreVolunteer(a, victimLat, victimLng);
      final sb = scoreVolunteer(b, victimLat, victimLng);
      return sb.compareTo(sa);
    });

    return pool.take(limit).toList();
  }

  // ── Service filtering ────────────────────────────────────────────────────────
  /// Filters [places] to those relevant to [emergencyType].
  /// Falls back to the first 3 places if filter yields nothing.
  static List<NearbyPlace> filterServices(
      List<NearbyPlace> places, String emergencyType) {
    final types    = servicesForEmergency(emergencyType);
    final filtered = places.where((p) => types.contains(p.type)).toList();
    return filtered.isNotEmpty ? filtered : places.take(3).toList();
  }

  // ── Dynamic performance insights ─────────────────────────────────────────────
  /// Generates 2–3 tailored performance tips for the volunteer dashboard.
  ///
  /// Tips are driven by:
  ///   - responseRate     (percentage of requests accepted)
  ///   - tasksCompleted   (experience-based tier system)
  ///   - avgResponseTime  (speed of initial response)
  ///   - reliabilityScore (composite reliability metric)
  static List<VolunteerInsight> generateInsights(VolunteerModel vol) {
    final candidates = <_RankedInsight>[];
    final ratePct    = (vol.responseRate * 100).toInt();

    // ── Response rate ─────────────────────────────────────────────────────────
    if (vol.responseRate < 0.70) {
      candidates.add(_RankedInsight(
        priority: 3,
        insight:  VolunteerInsight(
          title:   'Low Response Rate',
          message: 'You accept only $ratePct% of requests. Accepting more '
              'tasks moves you up in priority matching — try to reach 70%+ first.',
          level:   InsightLevel.urgent,
        ),
      ));
    } else if (vol.responseRate < 0.85) {
      candidates.add(_RankedInsight(
        priority: 1,
        insight:  VolunteerInsight(
          title:   'Improve Response Rate',
          message: 'Your rate is $ratePct%. Reaching 85%+ unlocks Silver tier '
              'and significantly increases how often you are matched first.',
          level:   InsightLevel.warning,
        ),
      ));
    } else {
      candidates.add(_RankedInsight(
        priority: 0,
        insight:  VolunteerInsight(
          title:   'Top Response Rate ⚡',
          message: '$ratePct% places you among the top volunteers. '
              'This directly boosts your position in every match ranking.',
          level:   InsightLevel.positive,
        ),
      ));
    }

    // ── Tasks completed (tier system) ─────────────────────────────────────────
    final tasks = vol.tasksCompleted;
    if (tasks < 10) {
      candidates.add(_RankedInsight(
        priority: 2,
        insight:  VolunteerInsight(
          title:   'Build Your Track Record',
          message: 'Complete ${10 - tasks} more task${tasks == 9 ? '' : 's'} '
              'to reach Rookie tier and increase your chance of being matched first.',
          level:   InsightLevel.info,
        ),
      ));
    } else if (tasks < 30) {
      candidates.add(_RankedInsight(
        priority: 1,
        insight:  VolunteerInsight(
          title:   'Silver Tier: ${30 - tasks} Tasks Away',
          message: 'Great progress! ${30 - tasks} more completed tasks unlocks '
              'Silver tier with 20% higher matching priority in your zone.',
          level:   InsightLevel.info,
        ),
      ));
    } else if (tasks < 50) {
      candidates.add(_RankedInsight(
        priority: 0,
        insight:  VolunteerInsight(
          title:   'Gold Tier Almost There! 🏅',
          message: 'Just ${50 - tasks} tasks from Gold tier — the highest '
              'matching priority in the entire network.',
          level:   InsightLevel.positive,
        ),
      ));
    } else {
      candidates.add(_RankedInsight(
        priority: 0,
        insight:  VolunteerInsight(
          title:   'Gold Volunteer 🥇',
          message: '$tasks tasks completed! You have maximum matching priority. '
              'You are one of the most trusted responders in the network.',
          level:   InsightLevel.positive,
        ),
      ));
    }

    // ── Response time ─────────────────────────────────────────────────────────
    if (vol.avgResponseTime > 10) {
      candidates.add(_RankedInsight(
        priority: 2,
        insight:  VolunteerInsight(
          title:   'Reduce Response Time',
          message: 'Avg ${vol.avgResponseTime.toInt()} min is above the ideal '
              '5-min target. Staying closer to active areas will lower this significantly.',
          level:   InsightLevel.warning,
        ),
      ));
    } else if (vol.avgResponseTime > 0 && vol.avgResponseTime <= 4) {
      candidates.add(_RankedInsight(
        priority: 0,
        insight:  VolunteerInsight(
          title:   'Lightning Fast Response! ⚡',
          message: '${vol.avgResponseTime.toStringAsFixed(1)} min average — '
              'top 10% for speed. Response time is weighted 25% in your match score.',
          level:   InsightLevel.positive,
        ),
      ));
    } else if (vol.avgResponseTime > 0) {
      candidates.add(_RankedInsight(
        priority: 0,
        insight:  VolunteerInsight(
          title:   'Good Response Time',
          message: 'Avg ${vol.avgResponseTime.toStringAsFixed(1)} min. '
              'Reducing below 5 min will add a noticeable boost to your allocation score.',
          level:   InsightLevel.info,
        ),
      ));
    }

    // ── Reliability score ─────────────────────────────────────────────────────
    if (vol.reliabilityScore < 50) {
      candidates.add(_RankedInsight(
        priority: 3,
        insight:  VolunteerInsight(
          title:   'Reliability Needs Attention',
          message: 'Score: ${vol.reliabilityScore.toInt()}/100. Consistent task '
              'completion is the fastest way to rebuild your reliability rating.',
          level:   InsightLevel.urgent,
        ),
      ));
    }

    // Sort by priority descending, return top 3 insights
    candidates.sort((a, b) => b.priority.compareTo(a.priority));
    return candidates.take(3).map((r) => r.insight).toList();
  }

  // ── Haversine (public so screens can use it) ──────────────────────────────
  static double haversineMeters(
      double lat1, double lng1, double lat2, double lng2) {
    const r    = 6371000.0;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLon = (lng2 - lng1) * math.pi / 180;
    final a    = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) *
            math.cos(lat2 * math.pi / 180) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }
}
