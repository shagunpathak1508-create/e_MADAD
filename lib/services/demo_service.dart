// ── DemoService ─────────────────────────────────────────────────────────────
// Single source of truth for all demo / offline fallback data.
// Used by MapScreen, VolunteerMatchScreen, EmergencyResponseScreen, and CacheService.

import '../models/volunteer_model.dart';
import 'nearby_service.dart';
import 'dart:math' as math;

class DemoService {
  // ── Base location: Mumbai city centre ─────────────────────────────────────
  static const double baseLat = 19.076;
  static const double baseLng = 72.877;

  // ── Skill → Emergency mapping (single definition, no duplication) ──────────
  static const Map<String, List<String>> emergencySkillMap = {
    'Medical':      ['First Aid', 'Medical'],
    'Accident':     ['First Aid', 'Medical', 'Transport'],
    'Fire':         ['Firefighting', 'Evacuation'],
    'Safety':       ['First Aid', 'Transport'],
    'Disaster':     ['Search & Rescue', 'Shelter', 'Food & Water', 'Evacuation'],
    'Help Request': ['Transport', 'First Aid'],
  };

  // ── Hard-coded fallback volunteers ────────────────────────────────────────
  static List<VolunteerModel> get dummyVolunteers => [
    VolunteerModel(
      id: 'dummy1', name: 'Dr. Aarav Sharma',
      phone: '+91 98765 43210', skills: ['Medical', 'First Aid'],
      available: true, tasksCompleted: 42,
      avgResponseTime: 3.2, rating: 4.9, responseRate: 0.95,
      lat: baseLat + 0.004, lng: baseLng + 0.002, // ~450m north
    ),
    VolunteerModel(
      id: 'dummy2', name: 'Priya Mehta',
      phone: '+91 98765 43211', skills: ['First Aid', 'Transport'],
      available: true, tasksCompleted: 28,
      avgResponseTime: 5.0, rating: 4.6, responseRate: 0.88,
      lat: baseLat - 0.003, lng: baseLng + 0.005, // ~350m south
    ),
    VolunteerModel(
      id: 'dummy3', name: 'Vikram Desai',
      phone: '+91 98765 43212', skills: ['Firefighting', 'Evacuation'],
      available: true, tasksCompleted: 35,
      avgResponseTime: 4.1, rating: 4.7, responseRate: 0.92,
      lat: baseLat + 0.006, lng: baseLng - 0.003, // ~670m north-east
    ),
    VolunteerModel(
      id: 'dummy4', name: 'Ananya Singh',
      phone: '+91 98765 43213', skills: ['Medical', 'First Aid', 'Shelter'],
      available: true, tasksCompleted: 18,
      avgResponseTime: 7.5, rating: 4.3, responseRate: 0.82,
      lat: baseLat + 0.012, lng: baseLng + 0.008, // ~1.3km
    ),
    VolunteerModel(
      id: 'dummy5', name: 'Rohan Kapoor',
      phone: '+91 98765 43214', skills: ['Transport', 'Search & Rescue'],
      available: true, tasksCompleted: 12,
      avgResponseTime: 8.0, rating: 4.1, responseRate: 0.78,
      lat: baseLat - 0.010, lng: baseLng - 0.012, // ~1.7km
    ),
  ];

  // ── Hard-coded fallback nearby services ───────────────────────────────────
  static List<NearbyPlace> dummyNearbyPlaces({
    double fromLat = baseLat, double fromLng = baseLng,
    String emergencyType = 'Medical',
  }) {
    final all = [
      NearbyPlace(name: 'Lilavati Hospital',  lat: baseLat + 0.008, lng: baseLng + 0.005, type: 'hospital',     phone: '+91 22 2675 1000'),
      NearbyPlace(name: 'Hinduja Hospital',   lat: baseLat - 0.012, lng: baseLng + 0.010, type: 'hospital',     phone: '+91 22 2445 1515'),
      NearbyPlace(name: 'Bombay Hospital',    lat: baseLat + 0.003, lng: baseLng - 0.015, type: 'hospital',     phone: '+91 22 2206 7676'),
      NearbyPlace(name: 'Kurla Police Stn',   lat: baseLat - 0.007, lng: baseLng - 0.004, type: 'police',       phone: '100'),
      NearbyPlace(name: 'Bandra Fire Stn',    lat: baseLat + 0.010, lng: baseLng + 0.014, type: 'fire_station', phone: '101'),
      NearbyPlace(name: 'Community Shelter',  lat: baseLat - 0.005, lng: baseLng + 0.008, type: 'shelter'),
    ];

    // Compute real distances & estimated minutes for each place
    for (final p in all) {
      p.distanceMeters = _haversine(fromLat, fromLng, p.lat, p.lng);
      p.estimatedMinutes = (p.distanceMeters / 250).round().clamp(1, 60);
    }
    all.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));

    // Filter by emergency type
    final typeFilters = <String, List<String>>{
      'Medical':      ['hospital'],
      'Fire':         ['fire_station', 'hospital'],
      'Accident':     ['hospital', 'police'],
      'Safety':       ['police', 'hospital'],
      'Disaster':     ['shelter', 'hospital', 'police'],
    };
    final wanted = typeFilters[emergencyType] ?? ['hospital', 'police'];
    final filtered = all.where((p) => wanted.contains(p.type)).toList();
    return (filtered.isNotEmpty ? filtered : all).take(4).toList();
  }

  /// Filter volunteers by emergency type using emergencySkillMap.
  static List<VolunteerModel> filteredVolunteers(String emergencyType) {
    final skills = emergencySkillMap[emergencyType] ?? [];
    if (skills.isEmpty) return dummyVolunteers;
    final matched = dummyVolunteers.where((v) =>
        v.skills.any((s) => skills.contains(s))).toList();
    return matched.isNotEmpty ? matched : dummyVolunteers;
  }

  static double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLon = (lon2 - lon1) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) * math.cos(lat2 * math.pi / 180) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }
}
