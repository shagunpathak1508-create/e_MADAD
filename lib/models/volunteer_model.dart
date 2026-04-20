import 'package:cloud_firestore/cloud_firestore.dart';

class VolunteerModel {
  final String id;
  final String name;
  final String phone;
  final List<String> skills;

  /// Primary skill label (e.g. "Medical", "Fire", "Rescue").
  /// Stored as a string in Firestore; falls back to first element of `skills`.
  final String skill;

  final double lat;
  final double lng;

  /// Pre-computed distance from base location (km). Stored in Firestore.
  /// Used as display fallback when live distance calculation is unavailable.
  final double distance;

  bool available;
  final int tasksCompleted;
  final double avgResponseTime; // minutes
  final double rating;          // 0–5 raw rating stored in Firestore
  final double responseRate;    // 0.0–1.0

  VolunteerModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.skills,
    String? skill,
    this.lat = 0.0,
    this.lng = 0.0,
    this.distance = 0.0,
    this.available = false,
    this.tasksCompleted = 0,
    this.avgResponseTime = 0.0,
    this.rating = 3.5,        // safe non-perfect default
    this.responseRate = 0.0,
  }) : skill = skill ?? (skills.isNotEmpty ? skills.first : 'General');

  // ── Reliability score (0–100) ─────────────────────────────────────────────
  // Weighted formula:
  //   40% from normalised rating (0–5 → 0–1)
  //   30% from task experience (caps at 50 tasks)
  //   30% from response time   (lower is better; unknown → 0.5)
  //
  // A brand-new volunteer (0 tasks, rating=3.5, no responseTime) → ~55 (2.75⭐)
  // An experienced volunteer (42 tasks, rating=4.8, 3.2 min)     → ~88 (4.4⭐)
  // Maximum possible with 50 tasks, 5.0 rating, <1 min           → ~97 (4.85⭐)
  double get reliabilityScore {
    final ratingComponent   = ((rating - 0.0) / 5.0).clamp(0.0, 1.0);
    final taskComponent     = (tasksCompleted / 50.0).clamp(0.0, 1.0);
    final responseComponent = avgResponseTime <= 0
        ? 0.5
        : (1.0 - avgResponseTime / 30.0).clamp(0.0, 1.0);

    // Cap at 97 to prevent a "perfect 5.0" display for real data
    return ((taskComponent * 0.3 + ratingComponent * 0.4 + responseComponent * 0.3) * 100)
        .clamp(0.0, 97.0);
  }

  /// Display rating on a 0–5 star scale derived from reliabilityScore.
  double get displayRating => (reliabilityScore / 20.0).clamp(0.0, 4.85);

  // ── Firestore deserialization ─────────────────────────────────────────────
  factory VolunteerModel.fromMap(Map<String, dynamic> map, String docId) {
    final skillsList = List<String>.from(map['skills'] ?? []);
    return VolunteerModel(
      id:              docId,
      name:            map['name'] ?? '',
      phone:           map['phone'] ?? '',
      skills:          skillsList,
      skill:           map['skill'] ?? (skillsList.isNotEmpty ? skillsList.first : 'General'),
      lat:             (map['lat'] ?? (map['location'] as GeoPoint?)?.latitude  ?? 0.0).toDouble(),
      lng:             (map['lng'] ?? (map['location'] as GeoPoint?)?.longitude ?? 0.0).toDouble(),
      distance:        (map['distance'] ?? 0.0).toDouble(),
      available:       map['available'] ?? map['isAvailable'] ?? false,
      tasksCompleted:  (map['tasksCompleted'] ?? 0) as int,
      avgResponseTime: (map['avgResponseTime'] ?? 0.0).toDouble(),
      rating:          (map['rating'] ?? 3.5).toDouble(),
      responseRate:    (map['responseRate'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {
    'name':            name,
    'phone':           phone,
    'skills':          skills,
    'skill':           skill,
    'lat':             lat,
    'lng':             lng,
    'distance':        distance,
    'available':       available,
    'tasksCompleted':  tasksCompleted,
    'avgResponseTime': avgResponseTime,
    'rating':          rating,
    'responseRate':    responseRate,
  };

  VolunteerModel copyWith({bool? available}) => VolunteerModel(
    id:              id,
    name:            name,
    phone:           phone,
    skills:          skills,
    skill:           skill,
    lat:             lat,
    lng:             lng,
    distance:        distance,
    available:       available ?? this.available,
    tasksCompleted:  tasksCompleted,
    avgResponseTime: avgResponseTime,
    rating:          rating,
    responseRate:    responseRate,
  );
}
