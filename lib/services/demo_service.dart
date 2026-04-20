// ── DemoService ─────────────────────────────────────────────────────────────
// Single source of truth for all demo / in-memory fallback data.
// Mirrors the Firestore seed dataset exactly so offline mode looks identical
// to the live Firestore view.
//
// Used by: MapScreen, VolunteerMatchScreen, EmergencyResponseScreen,
//          CacheService, DemoLoginScreen, VolunteerDashboardScreen.

import '../models/volunteer_model.dart';
import 'nearby_service.dart';
import 'dart:math' as math;

class DemoService {
  // ── Base location: Mumbai city centre ─────────────────────────────────────
  static const double baseLat = 19.0760;
  static const double baseLng = 72.8777;

  // ── Skill → Emergency mapping ──────────────────────────────────────────────
  static const Map<String, List<String>> emergencySkillMap = {
    'Medical':      ['First Aid', 'Medical'],
    'Accident':     ['First Aid', 'Medical', 'Transport'],
    'Fire':         ['Firefighting', 'Evacuation'],
    'Safety':       ['First Aid', 'Transport'],
    'Disaster':     ['Search & Rescue', 'Shelter', 'Food & Water', 'Evacuation'],
    'Help Request': ['Transport', 'First Aid'],
  };

  // ── Demo volunteer roster (mirrors Firestore seed) ────────────────────────
  // Distances and coordinates are tuned so the map always shows clustered
  // markers around Mumbai centre without any GPS input.
  static List<VolunteerModel> get dummyVolunteers => [
    // ── CLUSTER 1: Very close (0.5–0.8 km) ──
    VolunteerModel(
      id: 'demo_vol_1',
      name: 'Dr. Aarav Sharma',
      phone: '+91 98765 43210',
      skills: ['Medical', 'First Aid'],
      skill: 'Medical',
      available: true,
      tasksCompleted: 42,
      avgResponseTime: 3.2,
      rating: 4.8,
      responseRate: 0.95,
      distance: 0.5,
      lat: baseLat + 0.004, lng: baseLng + 0.002, // ~450m north
    ),
    VolunteerModel(
      id: 'demo_vol_2',
      name: 'Priya Mehta',
      phone: '+91 98765 43211',
      skills: ['First Aid', 'Transport'],
      skill: 'First Aid',
      available: true,
      tasksCompleted: 28,
      avgResponseTime: 5.0,
      rating: 4.5,
      responseRate: 0.88,
      distance: 0.6,
      lat: baseLat - 0.003, lng: baseLng + 0.005, // ~350m south-east
    ),
    VolunteerModel(
      id: 'demo_vol_3',
      name: 'Vikram Desai',
      phone: '+91 98765 43212',
      skills: ['Firefighting', 'Evacuation'],
      skill: 'Fire',
      available: true,
      tasksCompleted: 35,
      avgResponseTime: 4.1,
      rating: 4.6,
      responseRate: 0.92,
      distance: 0.8,
      lat: baseLat + 0.006, lng: baseLng - 0.003, // ~670m north-west
    ),

    // ── CLUSTER 2: Medium distance (1.0–2.0 km) ──
    VolunteerModel(
      id: 'demo_vol_4',
      name: 'Ananya Singh',
      phone: '+91 98765 43213',
      skills: ['Medical', 'First Aid', 'Shelter'],
      skill: 'Medical',
      available: true,
      tasksCompleted: 18,
      avgResponseTime: 7.5,
      rating: 4.2,
      responseRate: 0.82,
      distance: 1.3,
      lat: baseLat + 0.012, lng: baseLng + 0.008, // ~1.3km
    ),
    VolunteerModel(
      id: 'demo_vol_5',
      name: 'Rohan Kapoor',
      phone: '+91 98765 43214',
      skills: ['Transport', 'Search & Rescue'],
      skill: 'Rescue',
      available: true,
      tasksCompleted: 12,
      avgResponseTime: 8.0,
      rating: 4.0,
      responseRate: 0.78,
      distance: 1.7,
      lat: baseLat - 0.010, lng: baseLng - 0.012, // ~1.7km
    ),
    VolunteerModel(
      id: 'demo_vol_6',
      name: 'Diya Joshi',
      phone: '+91 98765 43215',
      skills: ['Evacuation', 'Food & Water'],
      skill: 'Evacuation',
      available: true,
      tasksCompleted: 8,
      avgResponseTime: 10.0,
      rating: 3.8,
      responseRate: 0.70,
      distance: 1.9,
      lat: baseLat + 0.015, lng: baseLng - 0.008, // ~1.9km
    ),

    // ── CLUSTER 3: Further out (2.5–4 km) ──
    VolunteerModel(
      id: 'demo_vol_7',
      name: 'Arjun Gupta',
      phone: '+91 98765 43216',
      skills: ['Search & Rescue', 'Shelter', 'Firefighting'],
      skill: 'Rescue',
      available: true,
      tasksCompleted: 50,
      avgResponseTime: 2.8,
      rating: 4.9,
      responseRate: 0.98,
      distance: 2.8,
      lat: baseLat + 0.022, lng: baseLng + 0.018, // ~2.8km
    ),
    VolunteerModel(
      id: 'demo_vol_8',
      name: 'Neha Reddy',
      phone: '+91 98765 43217',
      skills: ['First Aid', 'Medical'],
      skill: 'Medical',
      available: true,
      tasksCompleted: 5,
      avgResponseTime: 12.0,
      rating: 3.6,
      responseRate: 0.60,
      distance: 3.2,
      lat: baseLat - 0.025, lng: baseLng + 0.020, // ~3.2km
    ),
  ];

  // ── Hard-coded fallback nearby services ───────────────────────────────────
  static List<NearbyPlace> dummyNearbyPlaces({
    double fromLat = baseLat,
    double fromLng = baseLng,
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

    for (final p in all) {
      p.distanceMeters    = _haversine(fromLat, fromLng, p.lat, p.lng);
      p.estimatedMinutes  = (p.distanceMeters / 250).round().clamp(1, 60);
    }
    all.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));

    final typeFilters = <String, List<String>>{
      'Medical':  ['hospital'],
      'Fire':     ['fire_station', 'hospital'],
      'Accident': ['hospital', 'police'],
      'Safety':   ['police', 'hospital'],
      'Disaster': ['shelter', 'hospital', 'police'],
    };
    final wanted   = typeFilters[emergencyType] ?? ['hospital', 'police'];
    final filtered = all.where((p) => wanted.contains(p.type)).toList();
    return (filtered.isNotEmpty ? filtered : all).take(4).toList();
  }

  /// Returns volunteers filtered by emergency type.
  static List<VolunteerModel> filteredVolunteers(String emergencyType) {
    final skills = emergencySkillMap[emergencyType] ?? [];
    if (skills.isEmpty) return dummyVolunteers;
    final matched = dummyVolunteers
        .where((v) => v.skills.any((s) => skills.contains(s)))
        .toList();
    return matched.isNotEmpty ? matched : dummyVolunteers;
  }

  /// Find a demo volunteer by ID.
  static VolunteerModel? findById(String id) {
    try {
      return dummyVolunteers.firstWhere((v) => v.id == id);
    } catch (_) {
      return null;
    }
  }

  static double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const r    = 6371000.0;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLon = (lon2 - lon1) * math.pi / 180;
    final a    = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) *
            math.cos(lat2 * math.pi / 180) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }
}
