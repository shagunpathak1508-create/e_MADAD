import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show debugPrint;

import 'demo_service.dart';

class NearbyPlace {
  final String name;
  final double lat;
  final double lng;
  final String type;
  final String? phone;
  double distanceMeters;
  int estimatedMinutes;

  NearbyPlace({
    required this.name,
    required this.lat,
    required this.lng,
    required this.type,
    this.phone,
    this.distanceMeters = 0,
    this.estimatedMinutes = 0,
  });

  Map<String, dynamic> toMap() => {
    'name': name, 'lat': lat, 'lng': lng, 'type': type,
    'phone': phone, 'distanceMeters': distanceMeters,
    'estimatedMinutes': estimatedMinutes,
  };

  factory NearbyPlace.fromMap(Map<String, dynamic> map) => NearbyPlace(
    name: map['name'] ?? '',
    lat:  (map['lat']  ?? 0.0).toDouble(),
    lng:  (map['lng']  ?? 0.0).toDouble(),
    type: map['type']  ?? '',
    phone: map['phone'],
    distanceMeters:  (map['distanceMeters']  ?? 0.0).toDouble(),
    estimatedMinutes: map['estimatedMinutes'] ?? 0,
  );
}

class NearbyService {
  static const _overpassUrl = 'https://overpass-api.de/api/interpreter';
  static const _requestTimeout = Duration(seconds: 5);

  static Future<List<NearbyPlace>> fetchNearby({
    required double lat,
    required double lng,
    required String emergencyType,
    int radiusMeters = 3000,
  }) async {
    final tags = _tagsForEmergency(emergencyType);
    final results = <NearbyPlace>[];

    // Fetch all tag queries in parallel
    final futures = tags.map((tag) =>
        _query(lat, lng, tag, radiusMeters).catchError((_) => <NearbyPlace>[]));
    final allResults = await Future.wait(futures);
    for (final r in allResults) {
      results.addAll(r);
    }

    if (results.isEmpty) {
      debugPrint('[NearbyService] No live results — returning demo places');
      return DemoService.dummyNearbyPlaces(
          fromLat: lat, fromLng: lng, emergencyType: emergencyType);
    }

    results.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    return results.take(10).toList();
  }

  static List<String> _tagsForEmergency(String type) {
    switch (type) {
      case 'Medical':      return ['amenity=hospital', 'amenity=clinic', 'amenity=pharmacy'];
      case 'Fire':         return ['amenity=fire_station', 'amenity=hospital'];
      case 'Accident':     return ['amenity=hospital', 'amenity=police'];
      case 'Safety':       return ['amenity=police', 'amenity=hospital'];
      case 'Disaster':     return ['amenity=shelter', 'amenity=hospital', 'amenity=police'];
      default:             return ['amenity=hospital', 'amenity=police'];
    }
  }

  static Future<List<NearbyPlace>> _query(
      double lat, double lng, String tag, int radius) async {
    final query = '''
[out:json][timeout:5];
(
  node[$tag](around:$radius,$lat,$lng);
  way[$tag](around:$radius,$lat,$lng);
);
out center 5;
''';
    try {
      final response = await http
          .post(Uri.parse(_overpassUrl), body: {'data': query})
          .timeout(_requestTimeout);

      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final elements = data['elements'] as List? ?? [];

      return elements.map((el) {
        final elLat = (el['lat'] ?? el['center']?['lat'] ?? lat) as double;
        final elLng = (el['lon'] ?? el['center']?['lon'] ?? lng) as double;
        final tags = el['tags'] as Map? ?? {};
        final dist = _haversine(lat, lng, elLat, elLng);
        return NearbyPlace(
          name: tags['name'] ?? tags['amenity'] ?? 'Unknown',
          lat: elLat, lng: elLng,
          type: tags['amenity'] ?? tag.split('=').last,
          phone: tags['phone'],
          distanceMeters: dist,
          estimatedMinutes: (dist / 250).round().clamp(1, 60),
        );
      }).toList();
    } on TimeoutException {
      debugPrint('[NearbyService] Timeout for $tag');
      return [];
    } catch (e) {
      debugPrint('[NearbyService] Error for $tag: $e');
      return [];
    }
  }

  static double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLon = (lon2 - lon1) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) *
            math.cos(lat2 * math.pi / 180) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }
}
