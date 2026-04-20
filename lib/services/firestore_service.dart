import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import '../models/volunteer_model.dart';
import '../models/emergency_model.dart';
import '../services/demo_service.dart';
import 'dart:math';
import 'location_service.dart';

class FirestoreService {
  static final _db = FirebaseFirestore.instance;
  static const _volunteersCol  = 'volunteers';
  static const _emergenciesCol = 'emergencies';
  static String? currentEmergencyId;

  // ── Skill-to-Emergency mapping ────────────────────────────────────────────
  static const _emergencySkillMap = <String, List<String>>{
    'Medical':      ['First Aid', 'Medical'],
    'Accident':     ['First Aid', 'Medical', 'Transport'],
    'Fire':         ['Firefighting', 'Evacuation'],
    'Safety':       ['First Aid', 'Transport'],
    'Disaster':     ['Search & Rescue', 'Shelter', 'Food & Water', 'Evacuation'],
    'Help Request': ['Transport', 'First Aid'],
  };

  // ── Volunteers ────────────────────────────────────────────────────────────

  /// In demo mode this is a no-op — volunteers come from seed data only.
  static Future<String> registerVolunteer(VolunteerModel v) async {
    // Demo mode guard: never create new volunteer docs from user input
    debugPrint('[FirestoreService] registerVolunteer skipped — demo mode. '
        'Using demo_vol_1 as default.');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('volunteer_id',   'demo_vol_1');
    await prefs.setString('volunteer_name', 'Dr. Aarav Sharma');
    await prefs.setString('volunteer_phone', '+91 98765 43210');
    return 'demo_vol_1';
  }

  static Future<void> updateAvailability(String id, bool available) async {
    if (id.startsWith('demo_')) {
      debugPrint('[FirestoreService] Demo volunteer — availability updated locally only.');
      return;
    }
    try {
      await _db.collection(_volunteersCol).doc(id).update({'available': available});
    } catch (e) {
      debugPrint('[FirestoreService] updateAvailability error: $e');
    }
  }

  static Future<VolunteerModel?> getVolunteer(String id) async {
    // Fast path: return from in-memory demo roster
    final inMemory = DemoService.findById(id);
    if (inMemory != null) return inMemory;

    try {
      final doc = await _db.collection(_volunteersCol).doc(id).get()
          .timeout(const Duration(seconds: 5));
      if (!doc.exists) return null;
      return VolunteerModel.fromMap(doc.data()!, doc.id);
    } catch (e) {
      debugPrint('[FirestoreService] getVolunteer error: $e');
      return null;
    }
  }

  static Stream<List<VolunteerModel>> nearbyVolunteers(
      double lat, double lng, double radiusKm) async* {
    try {
      await for (final snap in _db
          .collection(_volunteersCol)
          .where('available', isEqualTo: true)
          .limit(15)
          .snapshots()) {

        final list = snap.docs
            .map((d) => VolunteerModel.fromMap(d.data(), d.id))
            .toList();

        list.sort((a, b) {
          final distA = _haversine(a.lat, a.lng, lat, lng);
          final distB = _haversine(b.lat, b.lng, lat, lng);
          return distA.compareTo(distB);
        });

        if (list.isNotEmpty) {
          yield list;
        } else {
          // Firestore empty → yield demo volunteers so map never looks blank
          yield DemoService.dummyVolunteers;
        }
      }
    } catch (e) {
      debugPrint('[FirestoreService] nearbyVolunteers stream error: $e');
      yield DemoService.dummyVolunteers;
    }
  }

  /// Returns top-matching volunteers for a given emergency type.
  static Stream<List<VolunteerModel>> topMatches(String emergencyType,
      {double? lat, double? lng}) async* {
    if (lat == null || lng == null) {
      final pos = await LocationService.getCurrentLocation();
      lat = pos.latitude;
      lng = pos.longitude;
    }
    final fixedLat     = lat;
    final fixedLng     = lng;
    final relevantSkills = _emergencySkillMap[emergencyType] ?? [];

    try {
      await for (final snap in _db
          .collection(_volunteersCol)
          .where('available', isEqualTo: true)
          .limit(30)
          .snapshots()) {

        final list = snap.docs
            .map((d) => VolunteerModel.fromMap(d.data(), d.id))
            .toList();

        List<VolunteerModel> matched;
        if (relevantSkills.isNotEmpty) {
          matched = list
              .where((v) => v.skills.any((s) => relevantSkills.contains(s)))
              .toList();
          if (matched.isEmpty) matched = list;
        } else {
          matched = list;
        }

        if (matched.isEmpty) {
          // Fallback to demo filtered list so the screen is never empty
          yield DemoService.filteredVolunteers(emergencyType);
          continue;
        }

        matched.sort((a, b) {
          final distA = _haversine(a.lat, a.lng, fixedLat, fixedLng);
          final distB = _haversine(b.lat, b.lng, fixedLat, fixedLng);
          final cmp   = distA.compareTo(distB);
          if (cmp != 0) return cmp;
          return b.reliabilityScore.compareTo(a.reliabilityScore);
        });

        yield matched.take(5).toList();
      }
    } catch (e) {
      debugPrint('[FirestoreService] topMatches stream error: $e');
      yield DemoService.filteredVolunteers(emergencyType);
    }
  }

  static double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const r    = 6371000.0;
    final dLat = (lat2 - lat1) * pi / 180.0;
    final dLon = (lon2 - lon1) * pi / 180.0;
    final a    = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180.0) * cos(lat2 * pi / 180.0) *
            sin(dLon / 2) * sin(dLon / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  // ── Emergencies ───────────────────────────────────────────────────────────

  static Future<String> createEmergency(EmergencyModel req) async {
    final doc = await _db.collection(_emergenciesCol).add(req.toMap());
    currentEmergencyId = doc.id;
    return doc.id;
  }

  static Future<void> updateEmergencyType(String id, String type) async {
    try {
      await _db.collection(_emergenciesCol).doc(id).update({'type': type});
    } catch (e) {
      debugPrint('[FirestoreService] updateEmergencyType error: $e');
    }
  }

  static Future<void> updateEmergencyStatus(String id, String status) async {
    if (id.startsWith('demo')) {
      debugPrint('[FirestoreService] Demo emergency — status update skipped.');
      return;
    }
    try {
      await _db.collection(_emergenciesCol).doc(id).update({'status': status});
    } catch (e) {
      debugPrint('[FirestoreService] updateEmergencyStatus error: $e');
    }
  }

  /// Stream of pending emergencies. Falls back to demo data if Firestore
  /// returns nothing within a short timeout.
  static Stream<List<EmergencyModel>> volunteerIncomingRequests() async* {
    try {
      await for (final snap in _db
          .collection(_emergenciesCol)
          .where('status', isEqualTo: 'pending')
          .limit(5)
          .snapshots()) {
        final docs = snap.docs
            .map((d) => EmergencyModel.fromMap(d.data(), d.id))
            .toList();
        docs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        yield docs; // may be empty — widget handles that with _DemoRequests
      }
    } catch (e) {
      debugPrint('[FirestoreService] volunteerIncomingRequests error: $e');
      yield <EmergencyModel>[];
    }
  }

  static Future<void> updateVolunteerLocation(
      String volunteerId, double lat, double lng) async {
    if (volunteerId.startsWith('demo_')) return; // no-op for demo IDs
    try {
      await _db.collection(_volunteersCol).doc(volunteerId).update({
        'lat':        lat,
        'lng':        lng,
        'lastActive': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[FirestoreService] updateVolunteerLocation error: $e');
    }
  }

  /// Assigns a volunteer to an emergency.
  /// Demo emergencies (id starts with 'demo') succeed locally without
  /// a Firestore write.
  static Future<bool> assignVolunteerToEmergency(
      String emergencyId, String volunteerId) async {
    if (emergencyId.isEmpty || volunteerId.isEmpty) {
      debugPrint('assignVolunteerToEmergency: empty ID — '
          'emergencyId=$emergencyId, volunteerId=$volunteerId');
      return false;
    }

    // Demo emergency: pretend success so the map opens
    if (emergencyId.startsWith('demo')) {
      debugPrint('Demo emergency accepted! (Skipping Firestore write)');
      return true;
    }

    try {
      await _db.collection(_emergenciesCol).doc(emergencyId).update({
        'assignedVolunteerId': volunteerId,
        'status':              'accepted',
        'acceptedAt':          FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('assignVolunteerToEmergency failed: $e');
      return false;
    }
  }

  /// Real-time stream of the accepted emergency for [volunteerId].
  ///
  /// Emits a single [EmergencyModel] when the volunteer has an active accepted
  /// task, or `null` when no accepted task exists.
  ///
  /// Falls back safely on Firestore errors — the volunteer dashboard handles
  /// the null case gracefully by showing the incoming requests list.
  static Stream<EmergencyModel?> acceptedEmergencyStream(
      String volunteerId) async* {
    if (volunteerId.startsWith('demo_')) {
      // Demo volunteers never have a real Firestore accepted emergency.
      // The dashboard synthesises one locally from SharedPrefs on accept.
      yield null;
      return;
    }
    try {
      await for (final snap in _db
          .collection(_emergenciesCol)
          .where('assignedVolunteerId', isEqualTo: volunteerId)
          .where('status', isEqualTo: 'accepted')
          .limit(1)
          .snapshots()) {
        if (snap.docs.isEmpty) {
          yield null;
        } else {
          yield EmergencyModel.fromMap(
              snap.docs.first.data(), snap.docs.first.id);
        }
      }
    } catch (e) {
      debugPrint('[FirestoreService] acceptedEmergencyStream error: $e');
      yield null;
    }
  }

  /// Persists the accepted emergency ID and type in SharedPreferences so the
  /// dashboard can restore the active task state after a hot restart.
  static Future<void> persistAcceptedEmergency({
    required String emergencyId,
    required String emergencyType,
    required double victimLat,
    required double victimLng,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('accepted_emergency_id',   emergencyId);
    await prefs.setString('accepted_emergency_type', emergencyType);
    await prefs.setDouble('accepted_victim_lat',     victimLat);
    await prefs.setDouble('accepted_victim_lng',     victimLng);
  }

  /// Clears the persisted accepted emergency (call when task is completed
  /// or declined).
  static Future<void> clearAcceptedEmergency() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('accepted_emergency_id');
    await prefs.remove('accepted_emergency_type');
    await prefs.remove('accepted_victim_lat');
    await prefs.remove('accepted_victim_lng');
  }

  /// Assigns the AI-selected volunteer to an emergency and records whether
  /// Gemini was used for the match.
  ///
  /// Writes:
  ///   - assignedVolunteerId
  ///   - status        → 'accepted'
  ///   - aiMatched     → true/false
  ///   - matchedAt     → server timestamp
  ///
  /// Skips silently for demo IDs (emergencyId starts with 'demo').
  static Future<void> assignAIMatch({
    required String emergencyId,
    required String volunteerId,
    required bool   usedAI,
  }) async {
    if (emergencyId.isEmpty || volunteerId.isEmpty) {
      debugPrint('[FirestoreService] assignAIMatch: empty ID — skipped '
          '(emergencyId=$emergencyId, volunteerId=$volunteerId)');
      return;
    }
    if (emergencyId.startsWith('demo')) {
      debugPrint('[FirestoreService] assignAIMatch: demo emergency — '
          'skipping Firestore write (aiMatched=$usedAI)');
      return;
    }
    try {
      await _db.collection(_emergenciesCol).doc(emergencyId).update({
        'assignedVolunteerId': volunteerId,
        'status':              'accepted',
        'aiMatched':           usedAI,
        'matchedAt':           FieldValue.serverTimestamp(),
      });
      debugPrint('[FirestoreService] assignAIMatch: emergency $emergencyId '
          '→ volunteer $volunteerId (aiMatched=$usedAI)');
    } catch (e) {
      debugPrint('[FirestoreService] assignAIMatch error: $e');
    }
  }
}
