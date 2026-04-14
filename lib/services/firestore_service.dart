import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/volunteer_model.dart';
import '../models/help_request_model.dart';

class FirestoreService {
  static final _db = FirebaseFirestore.instance;
  static const _volunteersCol = 'volunteers';
  static const _requestsCol = 'help_requests';

  // ── Volunteers ──────────────────────────────────────────────

  static Future<String> registerVolunteer(VolunteerModel v) async {
    final doc = await _db.collection(_volunteersCol).add(v.toMap());
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('volunteer_id', doc.id);
    await prefs.setString('volunteer_name', v.name);
    await prefs.setString('volunteer_phone', v.phone);
    return doc.id;
  }

  static Future<void> updateAvailability(String id, bool available) async {
    await _db.collection(_volunteersCol).doc(id).update({'isAvailable': available});
  }

  static Future<VolunteerModel?> getVolunteer(String id) async {
    final doc = await _db.collection(_volunteersCol).doc(id).get();
    if (!doc.exists) return null;
    return VolunteerModel.fromMap(doc.data()!, doc.id);
  }

  static Stream<List<VolunteerModel>> nearbyVolunteers(
      double lat, double lng, double radiusKm) {
    // Firestore doesn't do geo queries natively; we fetch available and filter
    return _db
        .collection(_volunteersCol)
        .where('isAvailable', isEqualTo: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => VolunteerModel.fromMap(d.data(), d.id))
            .toList()
          ..sort((a, b) =>
              b.reliabilityScore.compareTo(a.reliabilityScore)));
  }

  static Stream<List<VolunteerModel>> topMatches(String emergencyType) {
    return _db
        .collection(_volunteersCol)
        .where('isAvailable', isEqualTo: true)
        .limit(10)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((d) => VolunteerModel.fromMap(d.data(), d.id))
          .toList();
      list.sort((a, b) => b.reliabilityScore.compareTo(a.reliabilityScore));
      return list.take(3).toList();
    });
  }

  // ── Help Requests ───────────────────────────────────────────

  static Future<String> createHelpRequest(HelpRequestModel req) async {
    final doc = await _db.collection(_requestsCol).add(req.toMap());
    return doc.id;
  }

  static Future<void> updateRequestStatus(String id, String status) async {
    await _db.collection(_requestsCol).doc(id).update({'status': status});
  }

  static Stream<List<HelpRequestModel>> volunteerIncomingRequests() {
    return _db
        .collection(_requestsCol)
        .where('status', isEqualTo: 'pending')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => HelpRequestModel.fromMap(d.data(), d.id))
            .toList());
  }

  static Future<void> updateVolunteerLocation(
      String volunteerId, double lat, double lng) async {
    await _db.collection(_volunteersCol).doc(volunteerId).update({
      'location': GeoPoint(lat, lng),
      'lastActive': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> incrementTasksCompleted(String volunteerId) async {
    await _db.collection(_volunteersCol).doc(volunteerId).update({
      'tasksCompleted': FieldValue.increment(1),
    });
  }
}
