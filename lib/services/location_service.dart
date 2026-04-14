import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class LocationService {
  static const _trailKey = 'location_trail';
  static const _maxTrailPoints = 20;
  static Timer? _timer;

  static Future<Position?> getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }
      if (permission == LocationPermission.deniedForever) return null;

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      return null;
    }
  }

  static void startTracking() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) async {
      final pos = await getCurrentLocation();
      if (pos != null) await _saveToTrail(pos);
    });
    getCurrentLocation().then((pos) {
      if (pos != null) _saveToTrail(pos);
    });
  }

  static void stopTracking() {
    _timer?.cancel();
    _timer = null;
  }

  static Future<void> _saveToTrail(Position pos) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_trailKey) ?? [];
    final point = jsonEncode({
      'lat': pos.latitude,
      'lng': pos.longitude,
      'ts': DateTime.now().millisecondsSinceEpoch,
    });
    raw.add(point);
    if (raw.length > _maxTrailPoints) raw.removeAt(0);
    await prefs.setStringList(_trailKey, raw);
  }

  static Future<List<Map<String, dynamic>>> getTrail() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_trailKey) ?? [];
    return raw.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();
  }

  static Future<Map<String, dynamic>?> getLastKnownLocation() async {
    final trail = await getTrail();
    return trail.isNotEmpty ? trail.last : null;
  }

  /// Returns a simple bearing direction from last two points
  static Future<String?> predictDirection() async {
    final trail = await getTrail();
    if (trail.length < 2) return null;
    final prev = trail[trail.length - 2];
    final curr = trail[trail.length - 1];
    final dLat = (curr['lat'] as double) - (prev['lat'] as double);
    final dLng = (curr['lng'] as double) - (prev['lng'] as double);
    if (dLat.abs() < 0.0001 && dLng.abs() < 0.0001) return 'Stationary';
    if (dLat > 0 && dLng > 0) return 'North-East';
    if (dLat > 0 && dLng < 0) return 'North-West';
    if (dLat < 0 && dLng > 0) return 'South-East';
    if (dLat < 0 && dLng < 0) return 'South-West';
    if (dLat > 0) return 'North';
    if (dLat < 0) return 'South';
    if (dLng > 0) return 'East';
    return 'West';
  }
}
