import 'package:cloud_firestore/cloud_firestore.dart';

class VolunteerModel {
  final String id;
  final String name;
  final String phone;
  final List<String> skills;
  final double lat;
  final double lng;
  bool available;
  final int tasksCompleted;
  final double avgResponseTime; // in minutes
  final double rating;
  final double responseRate; // Legacy field for computeScore if needed

  VolunteerModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.skills,
    this.lat = 0.0,
    this.lng = 0.0,
    this.available = false,
    this.tasksCompleted = 0,
    this.avgResponseTime = 0.0,
    this.rating = 5.0,
    this.responseRate = 0.0,
  });

  /// Reliability score (0–100) based on tasks, rating, and response time.
  /// - 0 tasks, 0 avgResponse, 5.0 rating → ~55 (2.75⭐)
  /// - 25 tasks, 5 min avg, 4.8 rating  → ~78 (3.9⭐)
  /// - 50 tasks, 3 min avg, 5.0 rating  → ~97 (4.85⭐)
  double get reliabilityScore {
    // Rating component (0–1)
    final ratingComponent = (rating / 5.0).clamp(0.0, 1.0);
    // Task experience component (0–1), max at 50 tasks
    final taskComponent = (tasksCompleted / 50).clamp(0.0, 1.0);
    // Response time component (0–1), lower avg is better; unknown → 0.5
    final responseComponent = avgResponseTime <= 0
        ? 0.5
        : (1.0 - (avgResponseTime / 30)).clamp(0.0, 1.0);
    return (taskComponent * 0.3 + ratingComponent * 0.4 + responseComponent * 0.3) * 100;
  }

  /// Display rating on a 0–5 star scale (derived from reliabilityScore).
  double get displayRating => (reliabilityScore / 20).clamp(0.0, 5.0);

  factory VolunteerModel.fromMap(Map<String, dynamic> map, String docId) {
    return VolunteerModel(
      id: docId,
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      skills: List<String>.from(map['skills'] ?? []),
      lat: (map['lat'] ?? (map['location'] as GeoPoint?)?.latitude ?? 0.0).toDouble(),
      lng: (map['lng'] ?? (map['location'] as GeoPoint?)?.longitude ?? 0.0).toDouble(),
      available: map['available'] ?? map['isAvailable'] ?? false,
      tasksCompleted: map['tasksCompleted'] ?? 0,
      avgResponseTime: (map['avgResponseTime'] ?? 0.0).toDouble(),
      rating: (map['rating'] ?? 5.0).toDouble(),
      responseRate: (map['responseRate'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'phone': phone,
        'skills': skills,
        'lat': lat,
        'lng': lng,
        'available': available,
        'tasksCompleted': tasksCompleted,
        'avgResponseTime': avgResponseTime,
        'rating': rating,
        'responseRate': responseRate,
      };

  VolunteerModel copyWith({bool? available}) => VolunteerModel(
        id: id,
        name: name,
        phone: phone,
        skills: skills,
        lat: lat,
        lng: lng,
        available: available ?? this.available,
        tasksCompleted: tasksCompleted,
        avgResponseTime: avgResponseTime,
        rating: rating,
        responseRate: responseRate,
      );
}
