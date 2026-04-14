import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:math';

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
}

class NearbyService {
  static const _overpassUrl = 'https://overpass-api.de/api/interpreter';

  static Future<List<NearbyPlace>> fetchNearby({
    required double lat,
    required double lng,
    required String emergencyType,
    int radiusMeters = 3000,
  }) async {
    final tags = _tagsForEmergency(emergencyType);
    final results = <NearbyPlace>[];

    for (final tag in tags) {
      try {
        final places = await _query(lat, lng, tag, radiusMeters);
        results.addAll(places);
      } catch (_) {}
    }

    // Sort by distance
    results.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    return results.take(10).toList();
  }

  static List<String> _tagsForEmergency(String type) {
    switch (type) {
      case 'Medical':
        return ['amenity=hospital', 'amenity=clinic', 'amenity=pharmacy'];
      case 'Fire':
        return ['amenity=fire_station', 'amenity=hospital'];
      case 'Accident':
        return ['amenity=hospital', 'amenity=police'];
      case 'Safety':
        return ['amenity=police', 'amenity=hospital'];
      case 'Disaster':
        return ['amenity=shelter', 'amenity=hospital', 'amenity=police'];
      default:
        return ['amenity=hospital', 'amenity=police'];
    }
  }

  static Future<List<NearbyPlace>> _query(
    double lat, double lng, String tag, int radius) async {
    final query = '''
[out:json][timeout:10];
(
  node[$tag](around:$radius,$lat,$lng);
  way[$tag](around:$radius,$lat,$lng);
);
out center 5;
''';

    final response = await http.post(
      Uri.parse(_overpassUrl),
      body: {'data': query},
    ).timeout(const Duration(seconds: 12));

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
        lat: elLat,
        lng: elLng,
        type: tags['amenity'] ?? tag,
        phone: tags['phone'],
        distanceMeters: dist,
        estimatedMinutes: (dist / 250).round().clamp(1, 60),
      );
    }).toList();
  }

  static double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0;
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(lat1)) * cos(_toRad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  static double _toRad(double deg) => deg * pi / 180;
}
