import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'demo_service.dart';

class LocationService {
  // ── Demo Mode ─────────────────────────────────────────────────────────────
  // Set to true to bypass all GPS acquisition and immediately return the
  // Mumbai demo location. This ensures zero startup delay for presentations.
  static const bool demoMode = true;

  static const _trailKey = 'location_trail';
  static const _maxTrailPoints = 20;
  static Timer? _timer;

  // ── GPS cache: avoid re-acquisition on every screen ───────────────────────
  static Position? _cachedPosition;
  static DateTime? _cachedAt;
  static const _cacheTtl = Duration(seconds: 60);

  // ── Hardcoded demo position: Mumbai city centre (19.0760, 72.8777) ────────
  static Position get _demoPosition => Position(
    latitude:         DemoService.baseLat,
    longitude:        DemoService.baseLng,
    timestamp:        DateTime.now(),
    accuracy:         10,
    altitude:         0,
    altitudeAccuracy: 0,
    heading:          0,
    headingAccuracy:  0,
    speed:            0,
    speedAccuracy:    0,
  );

  /// Returns current position.
  /// In demo mode: instantly returns Mumbai centre — no GPS wait.
  /// Otherwise priority: cache → GPS → last known → demo fallback (NEVER null).
  static Future<Position> getCurrentLocation() async {
    // Demo mode: skip all GPS, return fixed coords immediately
    if (demoMode) {
      if (_cachedPosition == null) {
        _cachedPosition = _demoPosition;
        _cachedAt       = DateTime.now();
        debugPrint('[LocationService] DEMO MODE — returning Mumbai centre (${DemoService.baseLat}, ${DemoService.baseLng})');
      }
      return _cachedPosition!;
    }

    // 1. Return cache if still fresh
    if (_cachedPosition != null &&
        _cachedAt != null &&
        DateTime.now().difference(_cachedAt!) < _cacheTtl) {
      return _cachedPosition!;
    }

    // 2. Web has limited location support — skip service checks
    if (!kIsWeb) {
      try {
        final serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          debugPrint('[LocationService] Location service disabled — using demo position');
          return _getFallback();
        }

        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          debugPrint('[LocationService] Permission denied — using demo position');
          return _getFallback();
        }
      } catch (e) {
        debugPrint('[LocationService] Permission check error: $e');
        return _getFallback();
      }
    }

    // 3. Attempt real GPS acquisition
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy:  LocationAccuracy.medium,
          timeLimit: Duration(seconds: 3),
        ),
      ).timeout(const Duration(seconds: 4));
      _cachedPosition = pos;
      _cachedAt       = DateTime.now();
      debugPrint('[LocationService] GPS acquired: ${pos.latitude}, ${pos.longitude}');
      return pos;
    } catch (e) {
      debugPrint('[LocationService] GPS failed ($e) — trying last known');
    }

    // 4. Fall back to last known position
    try {
      if (!kIsWeb) {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null) {
          _cachedPosition = last;
          _cachedAt       = DateTime.now();
          debugPrint('[LocationService] Using last known: ${last.latitude}, ${last.longitude}');
          return last;
        }
      }
    } catch (e) {
      debugPrint('[LocationService] Last known failed: $e');
    }

    return _getFallback();
  }

  static Position _getFallback() {
    if (_cachedPosition != null) return _cachedPosition!;
    debugPrint('[LocationService] Using demo position (Mumbai centre)');
    final demo = _demoPosition;
    _cachedPosition = demo;
    _cachedAt       = DateTime.now();
    return demo;
  }

  /// Clears cache — call when you need a guaranteed fresh fix.
  static void clearCache() {
    _cachedPosition = null;
    _cachedAt       = null;
  }

  /// In demo mode this is a no-op — no timer spam, no GPS polling.
  static void startTracking() {
    if (demoMode) {
      debugPrint('[LocationService] DEMO MODE — tracking disabled');
      return;
    }
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) async {
      final pos = await getCurrentLocation();
      await _saveToTrail(pos);
    });
    getCurrentLocation().then(_saveToTrail);
  }

  static void stopTracking() {
    _timer?.cancel();
    _timer = null;
  }

  static Future<void> _saveToTrail(Position pos) async {
    final prefs = await SharedPreferences.getInstance();
    final raw   = prefs.getStringList(_trailKey) ?? [];
    final point = jsonEncode({
      'lat': pos.latitude,
      'lng': pos.longitude,
      'ts':  DateTime.now().millisecondsSinceEpoch,
    });
    raw.add(point);
    if (raw.length > _maxTrailPoints) raw.removeAt(0);
    await prefs.setStringList(_trailKey, raw);
  }

  static Future<List<Map<String, dynamic>>> getTrail() async {
    if (demoMode) return []; // No trail needed in demo mode
    final prefs = await SharedPreferences.getInstance();
    final raw   = prefs.getStringList(_trailKey) ?? [];
    return raw.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();
  }

  static Future<Map<String, dynamic>?> getLastKnownLocation() async {
    final trail = await getTrail();
    return trail.isNotEmpty ? trail.last : null;
  }

  /// Returns a bearing label from the last two trail points.
  static Future<String?> predictDirection() async {
    if (demoMode) return null;
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

  /// Haversine distance in metres.
  static double distanceBetween(
      double lat1, double lon1, double lat2, double lon2) {
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
