import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import '../models/volunteer_model.dart';
import '../models/emergency_model.dart';
import 'dart:math';
import 'location_service.dart';

class FirestoreService {
  static final _db = FirebaseFirestore.instance;
  static const _volunteersCol = 'volunteers';
  static const _emergenciesCol = 'emergencies';
  static String? currentEmergencyId;

  // ── Skill-to-Emergency mapping ─────────────────────────────
  // Emergency types use different names than volunteer skills.
  // This map bridges the two so matching actually works.
  static const _emergencySkillMap = <String, List<String>>{
    'Medical': ['First Aid', 'Medical'],
    'Accident': ['First Aid', 'Medical', 'Transport'],
    'Fire': ['Firefighting', 'Evacuation'],
    'Safety': ['First Aid', 'Transport'],
    'Disaster': ['Search & Rescue', 'Shelter', 'Food & Water', 'Evacuation'],
    'Help Request': ['Transport', 'First Aid'],
  };

  // ── Volunteers ──────────────────────────────────────────────

  static Future<String> registerVolunteer(VolunteerModel v) async {
    final data = v.toMap();
    data['createdAt'] = FieldValue.serverTimestamp();
    final doc = await _db.collection(_volunteersCol).add(data);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('volunteer_id', doc.id);
    await prefs.setString('volunteer_name', v.name);
    await prefs.setString('volunteer_phone', v.phone);
    return doc.id;
  }

  static Future<void> updateAvailability(String id, bool available) async {
    await _db.collection(_volunteersCol).doc(id).update({'available': available});
  }

  static Future<VolunteerModel?> getVolunteer(String id) async {
    final doc = await _db.collection(_volunteersCol).doc(id).get();
    if (!doc.exists) return null;
    return VolunteerModel.fromMap(doc.data()!, doc.id);
  }

  static Stream<List<VolunteerModel>> nearbyVolunteers(
      double lat, double lng, double radiusKm) {
    return _db
        .collection(_volunteersCol)
        .where('available', isEqualTo: true)
        .limit(15) 
        .snapshots()
        .map((snap) {
          final list = snap.docs
            .map((d) => VolunteerModel.fromMap(d.data(), d.id))
            .toList();
          
          list.sort((a, b) {
            final distA = _haversine(a.lat, a.lng, lat, lng);
            final distB = _haversine(b.lat, b.lng, lat, lng);
            return distA.compareTo(distB);
          });
          
          return list;
        });
  }

  /// Returns top matching volunteers for an emergency type.
  /// Uses proper skill-to-emergency mapping so 'Medical' matches 'First Aid', etc.
  static Stream<List<VolunteerModel>> topMatches(String emergencyType, {double? lat, double? lng}) async* {
    // Get location — will return cached instantly if available (< 60s)
    if (lat == null || lng == null) {
      final pos = await LocationService.getCurrentLocation();
      lat = pos.latitude;
      lng = pos.longitude;
    }

    final double? fixedLat = lat;
    final double? fixedLng = lng;
    final relevantSkills = _emergencySkillMap[emergencyType] ?? [];

    yield* _db
        .collection(_volunteersCol)
        .where('available', isEqualTo: true)
        .limit(30)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((d) => VolunteerModel.fromMap(d.data(), d.id))
          .toList();

      // Filter: volunteer has at least one skill that matches the emergency type
      List<VolunteerModel> matched;
      if (relevantSkills.isNotEmpty) {
        matched = list.where((v) =>
            v.skills.any((skill) => relevantSkills.contains(skill))).toList();
        // If no skill-matched volunteers, fall back to ALL available volunteers
        if (matched.isEmpty) matched = list;
      } else {
        matched = list;
      }

      // Sort: by distance first (if we have coords), then by reliability score
      if (fixedLat != null && fixedLng != null) {
        matched.sort((a, b) {
          final distA = _haversine(a.lat, a.lng, fixedLat, fixedLng);
          final distB = _haversine(b.lat, b.lng, fixedLat, fixedLng);
          final cmp = distA.compareTo(distB);
          if (cmp != 0) return cmp;
          return b.reliabilityScore.compareTo(a.reliabilityScore);
        });
      } else {
        matched.sort((a, b) => b.reliabilityScore.compareTo(a.reliabilityScore));
      }

      return matched.take(5).toList();
    });
  }

  static double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0;
    final dLat = (lat2 - lat1) * pi / 180.0;
    final dLon = (lon2 - lon1) * pi / 180.0;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180.0) * cos(lat2 * pi / 180.0) * sin(dLon / 2) * sin(dLon / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  // ── Emergencies ─────────────────────────────────────────────

  static Future<String> createEmergency(EmergencyModel req) async {
    final doc = await _db.collection(_emergenciesCol).add(req.toMap());
    currentEmergencyId = doc.id;
    return doc.id;
  }

  static Future<void> updateEmergencyType(String id, String type) async {
    await _db.collection(_emergenciesCol).doc(id).update({'type': type});
  }

  static Future<void> updateEmergencyStatus(String id, String status) async {
    await _db.collection(_emergenciesCol).doc(id).update({'status': status});
  }

  static Stream<List<EmergencyModel>> volunteerIncomingRequests() {
    return _db
        .collection(_emergenciesCol)
        .where('status', isEqualTo: 'pending')
        .limit(5) // Performance: only show latest pending
        .snapshots()
        .map((snap) {
          final docs = snap.docs
              .map((d) => EmergencyModel.fromMap(d.data(), d.id))
              .toList();
          // Sort locally to bypass Firebase composite index requirement
          docs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          return docs;
        });
  }

  static Future<void> updateVolunteerLocation(
      String volunteerId, double lat, double lng) async {
    await _db.collection(_volunteersCol).doc(volunteerId).update({
      'lat': lat,
      'lng': lng,
      'lastActive': FieldValue.serverTimestamp(),
    });
  }

  /// Assigns a volunteer to an emergency. Guards against empty IDs.
  static Future<bool> assignVolunteerToEmergency(String emergencyId, String volunteerId) async {
    if (emergencyId.isEmpty || volunteerId.isEmpty) {
      debugPrint('assignVolunteerToEmergency: empty ID — emergencyId=$emergencyId, volunteerId=$volunteerId');
      return false;
    }
    
    // Fallback Mock: If this is a demo/dummy request, pretend we successfully updated it.
    if (emergencyId.startsWith('demo')) {
      debugPrint('Demo emergency accepted! (Skipping Firestore write)');
      return true;
    }

    try {
      await _db.collection(_emergenciesCol).doc(emergencyId).update({
        'assignedVolunteerId': volunteerId,
        'status': 'accepted',
        'acceptedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('assignVolunteerToEmergency failed: $e');
      return false;
    }
  }
}
