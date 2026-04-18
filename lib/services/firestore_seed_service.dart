import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Seeds realistic demo data into Firestore for hackathon presentations.
/// Base location: Mumbai (19.076, 72.877).
/// Call once — checks a flag to avoid duplicate seeding.
class FirestoreSeedService {
  static final _db = FirebaseFirestore.instance;

  // Mumbai center
  static const _baseLat = 19.076;
  static const _baseLng = 72.877;

  /// Seeds all collections if not already seeded.
  static Future<void> seedIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('demo_seeded') == true) {
      debugPrint('Demo data already seeded — skipping.');
      return;
    }

    try {
      // Check if volunteers collection already has data
      final existing = await _db.collection('volunteers').limit(1).get();
      if (existing.docs.isNotEmpty) {
        debugPrint('Firestore already has volunteer data — skipping seed.');
        await prefs.setBool('demo_seeded', true);
        return;
      }

      debugPrint('Seeding demo data around Mumbai ($_baseLat, $_baseLng)...');
      await _seedVolunteers();
      await _seedEmergencies();
      await _seedHospitals();
      await prefs.setBool('demo_seeded', true);
      debugPrint('✅ Demo data seeded successfully.');
    } catch (e) {
      debugPrint('⚠️ Seed failed (non-fatal): $e');
    }
  }

  // ── Volunteers (10) ─────────────────────────────────────────
  static Future<void> _seedVolunteers() async {
    final volunteers = [
      // ── CLUSTER 1: Very close (500m–800m) ──
      {
        'name': 'Dr. Aarav Sharma',
        'phone': '+91 98765 43210',
        'skills': ['Medical', 'First Aid'],
        'lat': _baseLat + 0.004,  // ~450m north
        'lng': _baseLng + 0.002,
        'available': true,
        'tasksCompleted': 42,
        'avgResponseTime': 3.2,
        'rating': 4.9,
        'responseRate': 0.95,
      },
      {
        'name': 'Priya Mehta',
        'phone': '+91 98765 43211',
        'skills': ['First Aid', 'Transport'],
        'lat': _baseLat - 0.003,  // ~350m south
        'lng': _baseLng + 0.005,
        'available': true,
        'tasksCompleted': 28,
        'avgResponseTime': 5.0,
        'rating': 4.6,
        'responseRate': 0.88,
      },
      {
        'name': 'Vikram Desai',
        'phone': '+91 98765 43212',
        'skills': ['Firefighting', 'Evacuation'],
        'lat': _baseLat + 0.006,  // ~670m north-east
        'lng': _baseLng - 0.003,
        'available': true,
        'tasksCompleted': 35,
        'avgResponseTime': 4.1,
        'rating': 4.7,
        'responseRate': 0.92,
      },

      // ── CLUSTER 2: Medium distance (1–2km) ──
      {
        'name': 'Ananya Singh',
        'phone': '+91 98765 43213',
        'skills': ['Medical', 'First Aid', 'Shelter'],
        'lat': _baseLat + 0.012,  // ~1.3km
        'lng': _baseLng + 0.008,
        'available': true,
        'tasksCompleted': 18,
        'avgResponseTime': 7.5,
        'rating': 4.3,
        'responseRate': 0.82,
      },
      {
        'name': 'Rohan Kapoor',
        'phone': '+91 98765 43214',
        'skills': ['Transport', 'Search & Rescue'],
        'lat': _baseLat - 0.010,  // ~1.1km
        'lng': _baseLng - 0.012,
        'available': true,
        'tasksCompleted': 12,
        'avgResponseTime': 8.0,
        'rating': 4.1,
        'responseRate': 0.78,
      },
      {
        'name': 'Diya Joshi',
        'phone': '+91 98765 43215',
        'skills': ['Evacuation', 'Food & Water'],
        'lat': _baseLat + 0.015,  // ~1.7km
        'lng': _baseLng - 0.008,
        'available': true,
        'tasksCompleted': 8,
        'avgResponseTime': 10.0,
        'rating': 3.9,
        'responseRate': 0.70,
      },

      // ── CLUSTER 3: Further out (2.5–4km) ──
      {
        'name': 'Arjun Gupta',
        'phone': '+91 98765 43216',
        'skills': ['Search & Rescue', 'Shelter', 'Firefighting'],
        'lat': _baseLat + 0.022,  // ~2.5km
        'lng': _baseLng + 0.018,
        'available': true,
        'tasksCompleted': 50,
        'avgResponseTime': 2.8,
        'rating': 5.0,
        'responseRate': 0.98,
      },
      {
        'name': 'Neha Reddy',
        'phone': '+91 98765 43217',
        'skills': ['First Aid', 'Medical'],
        'lat': _baseLat - 0.025,  // ~2.8km
        'lng': _baseLng + 0.020,
        'available': true,
        'tasksCompleted': 5,
        'avgResponseTime': 12.0,
        'rating': 3.5,
        'responseRate': 0.60,
      },

      // ── Unavailable volunteers (for realism) ──
      {
        'name': 'Sai Patel',
        'phone': '+91 98765 43218',
        'skills': ['Transport', 'Evacuation'],
        'lat': _baseLat + 0.008,
        'lng': _baseLng - 0.006,
        'available': false,  // OFF
        'tasksCompleted': 22,
        'avgResponseTime': 6.0,
        'rating': 4.4,
        'responseRate': 0.85,
      },
      {
        'name': 'Isha Chatterjee',
        'phone': '+91 98765 43219',
        'skills': ['Medical', 'Food & Water'],
        'lat': _baseLat - 0.005,
        'lng': _baseLng + 0.010,
        'available': false,  // OFF
        'tasksCompleted': 3,
        'avgResponseTime': 15.0,
        'rating': 3.2,
        'responseRate': 0.50,
      },
    ];

    final batch = _db.batch();
    for (final v in volunteers) {
      batch.set(_db.collection('volunteers').doc(), {
        ...v,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
    debugPrint('  → Seeded ${volunteers.length} volunteers');
  }

  // ── Emergencies (4) ─────────────────────────────────────────
  static Future<void> _seedEmergencies() async {
    final emergencies = [
      {
        'type': 'Medical',
        'userLat': _baseLat + 0.002,
        'userLng': _baseLng - 0.001,
        'status': 'pending',
        'assignedVolunteerId': null,
        'timestamp': Timestamp.now(),
        'specificAction': 'Request medical volunteer',
        'victimId': 'victim_001',
      },
      {
        'type': 'Fire',
        'userLat': _baseLat - 0.008,
        'userLng': _baseLng + 0.004,
        'status': 'pending',
        'assignedVolunteerId': null,
        'timestamp': Timestamp.fromDate(
            DateTime.now().subtract(const Duration(minutes: 8))),
        'specificAction': 'Request evacuation help',
        'victimId': 'victim_002',
      },
      {
        'type': 'Accident',
        'userLat': _baseLat + 0.010,
        'userLng': _baseLng + 0.006,
        'status': 'accepted',
        'assignedVolunteerId': 'demo_vol_1',
        'timestamp': Timestamp.fromDate(
            DateTime.now().subtract(const Duration(minutes: 25))),
        'specificAction': 'Request immediate transport',
        'victimId': 'victim_003',
      },
      {
        'type': 'Safety',
        'userLat': _baseLat - 0.003,
        'userLng': _baseLng - 0.005,
        'status': 'completed',
        'assignedVolunteerId': 'demo_vol_2',
        'timestamp': Timestamp.fromDate(
            DateTime.now().subtract(const Duration(hours: 2))),
        'specificAction': 'Request someone to accompany',
        'victimId': 'victim_004',
      },
    ];

    final batch = _db.batch();
    for (final e in emergencies) {
      batch.set(_db.collection('emergencies').doc(), e);
    }
    await batch.commit();
    debugPrint('  → Seeded ${emergencies.length} emergencies');
  }

  // ── Hospitals (5) ───────────────────────────────────────────
  static Future<void> _seedHospitals() async {
    final hospitals = [
      {
        'name': 'Lilavati Hospital',
        'phone': '+91 22 2675 1000',
        'lat': _baseLat + 0.008,
        'lng': _baseLng + 0.005,
        'type': 'hospital',
      },
      {
        'name': 'Hinduja Hospital',
        'phone': '+91 22 2445 1515',
        'lat': _baseLat - 0.012,
        'lng': _baseLng + 0.010,
        'type': 'hospital',
      },
      {
        'name': 'Bombay Hospital',
        'phone': '+91 22 2206 7676',
        'lat': _baseLat + 0.003,
        'lng': _baseLng - 0.015,
        'type': 'hospital',
      },
      {
        'name': 'KEM Hospital',
        'phone': '+91 22 2410 7000',
        'lat': _baseLat - 0.020,
        'lng': _baseLng - 0.008,
        'type': 'hospital',
      },
      {
        'name': 'Nanavati Max Hospital',
        'phone': '+91 22 2626 7500',
        'lat': _baseLat + 0.018,
        'lng': _baseLng - 0.010,
        'type': 'hospital',
      },
    ];

    final batch = _db.batch();
    for (final h in hospitals) {
      batch.set(_db.collection('hospitals').doc(), h);
    }
    await batch.commit();
    debugPrint('  → Seeded ${hospitals.length} hospitals');
  }
}
