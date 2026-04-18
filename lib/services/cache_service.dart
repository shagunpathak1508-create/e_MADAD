import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/volunteer_model.dart';
import '../services/nearby_service.dart';
import '../services/demo_service.dart';

class CacheService {
  static const _volunteersKey = 'cached_volunteers';
  static const _hospitalsKey  = 'cached_hospitals';
  static const _profileKey    = 'volunteer_profile';

  // ── Volunteers ─────────────────────────────────────────────────────────────

  static Future<void> cacheVolunteers(List<VolunteerModel> volunteers) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _volunteersKey, jsonEncode(volunteers.map((v) => v.toMap()).toList()));
  }

  static Future<List<VolunteerModel>> getCachedVolunteers() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_volunteersKey);
    if (raw == null) return [];
    try {
      final List data = jsonDecode(raw);
      return data
          .map((item) => VolunteerModel.fromMap(item as Map<String, dynamic>, ''))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Always returns at least the demo volunteers (NEVER empty).
  static List<VolunteerModel> getDummyVolunteers({String emergencyType = ''}) {
    if (emergencyType.isNotEmpty) {
      return DemoService.filteredVolunteers(emergencyType);
    }
    return DemoService.dummyVolunteers;
  }

  // ── Hospitals / Services ───────────────────────────────────────────────────

  static Future<void> cacheHospitals(List<NearbyPlace> hospitals) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _hospitalsKey, jsonEncode(hospitals.map((h) => h.toMap()).toList()));
  }

  static Future<List<NearbyPlace>> getCachedHospitals() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_hospitalsKey);
    if (raw == null) return [];
    try {
      final List data = jsonDecode(raw);
      return data
          .map((item) => NearbyPlace.fromMap(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ── Volunteer Profile ──────────────────────────────────────────────────────

  static Future<void> cacheProfile(VolunteerModel profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profileKey, jsonEncode(profile.toMap()));
  }

  static Future<VolunteerModel?> getCachedProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_profileKey);
    if (raw == null) return null;
    try {
      return VolunteerModel.fromMap(jsonDecode(raw), '');
    } catch (_) {
      return null;
    }
  }
}
