import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Seeds realistic demo data into Firestore for presentations.
/// Base location: Mumbai (19.0760, 72.8777).
///
/// Seeding strategy:
///   1. Check SharedPrefs flag to avoid double-seeding.
///   2. Double-check Firestore document count so fresh emulators also seed.
///   3. Write all collections in batch for atomicity.
class FirestoreSeedService {
  static final _db = FirebaseFirestore.instance;

  // Mumbai city centre — matches LocationService.demoMode coords
  static const _baseLat = 19.0760;
  static const _baseLng = 72.8777;

  // ── Public entry point ───────────────────────────────────────────────────
  static Future<void> seedIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();

    // Check Firestore first — SharedPrefs flag can be stale after reinstalls
    try {
      final existing = await _db.collection('volunteers').limit(1).get()
          .timeout(const Duration(seconds: 6));

      if (existing.docs.isNotEmpty) {
        debugPrint('Demo data already seeded — skipping.');
        await prefs.setBool('demo_seeded', true);
        return;
      }
    } catch (e) {
      debugPrint('⚠️ Seed check failed (no network?): $e');
      // If we can't reach Firestore at all, the app still works via DemoService.
      return;
    }

    debugPrint('🌱 Seeding demo data around Mumbai ($_baseLat, $_baseLng)...');
    try {
      await _seedVolunteers();
      await _seedEmergencies();
      await _seedHospitals();
      await _seedUsers();
      await prefs.setBool('demo_seeded', true);
      debugPrint('✅ Demo data seeded successfully.');
    } catch (e) {
      debugPrint('⚠️ Seed failed (non-fatal): $e');
    }
  }

  // ── Volunteers (10) ─────────────────────────────────────────────────────
  static Future<void> _seedVolunteers() async {
    final volunteers = [
      // ── CLUSTER 1: Very close (0.5–0.8 km) ──
      {
        'name':            'Dr. Aarav Sharma',
        'phone':           '+91 98765 43210',
        'skills':          ['Medical', 'First Aid'],
        'skill':           'Medical',
        'lat':             _baseLat + 0.004, // ~450m north
        'lng':             _baseLng + 0.002,
        'distance':        0.5,
        'available':       true,
        'tasksCompleted':  42,
        'avgResponseTime': 3.2,
        'rating':          4.8,
        'responseRate':    0.95,
        'reliability':     4.7,
      },
      {
        'name':            'Priya Mehta',
        'phone':           '+91 98765 43211',
        'skills':          ['First Aid', 'Transport'],
        'skill':           'First Aid',
        'lat':             _baseLat - 0.003, // ~350m south-east
        'lng':             _baseLng + 0.005,
        'distance':        0.6,
        'available':       true,
        'tasksCompleted':  28,
        'avgResponseTime': 5.0,
        'rating':          4.5,
        'responseRate':    0.88,
        'reliability':     4.3,
      },
      {
        'name':            'Vikram Desai',
        'phone':           '+91 98765 43212',
        'skills':          ['Firefighting', 'Evacuation'],
        'skill':           'Fire',
        'lat':             _baseLat + 0.006, // ~670m north-west
        'lng':             _baseLng - 0.003,
        'distance':        0.8,
        'available':       true,
        'tasksCompleted':  35,
        'avgResponseTime': 4.1,
        'rating':          4.6,
        'responseRate':    0.92,
        'reliability':     4.5,
      },

      // ── CLUSTER 2: Medium (1.0–2.0 km) ──
      {
        'name':            'Ananya Singh',
        'phone':           '+91 98765 43213',
        'skills':          ['Medical', 'First Aid', 'Shelter'],
        'skill':           'Medical',
        'lat':             _baseLat + 0.012, // ~1.3km
        'lng':             _baseLng + 0.008,
        'distance':        1.3,
        'available':       true,
        'tasksCompleted':  18,
        'avgResponseTime': 7.5,
        'rating':          4.2,
        'responseRate':    0.82,
        'reliability':     4.0,
      },
      {
        'name':            'Rohan Kapoor',
        'phone':           '+91 98765 43214',
        'skills':          ['Transport', 'Search & Rescue'],
        'skill':           'Rescue',
        'lat':             _baseLat - 0.010, // ~1.7km
        'lng':             _baseLng - 0.012,
        'distance':        1.7,
        'available':       true,
        'tasksCompleted':  12,
        'avgResponseTime': 8.0,
        'rating':          4.0,
        'responseRate':    0.78,
        'reliability':     3.8,
      },
      {
        'name':            'Diya Joshi',
        'phone':           '+91 98765 43215',
        'skills':          ['Evacuation', 'Food & Water'],
        'skill':           'Evacuation',
        'lat':             _baseLat + 0.015, // ~1.9km
        'lng':             _baseLng - 0.008,
        'distance':        1.9,
        'available':       true,
        'tasksCompleted':  8,
        'avgResponseTime': 10.0,
        'rating':          3.8,
        'responseRate':    0.70,
        'reliability':     3.5,
      },

      // ── CLUSTER 3: Further out (2.5–4 km) ──
      {
        'name':            'Arjun Gupta',
        'phone':           '+91 98765 43216',
        'skills':          ['Search & Rescue', 'Shelter', 'Firefighting'],
        'skill':           'Rescue',
        'lat':             _baseLat + 0.022, // ~2.8km
        'lng':             _baseLng + 0.018,
        'distance':        2.8,
        'available':       true,
        'tasksCompleted':  50,
        'avgResponseTime': 2.8,
        'rating':          4.9,
        'responseRate':    0.98,
        'reliability':     4.8,
      },
      {
        'name':            'Neha Reddy',
        'phone':           '+91 98765 43217',
        'skills':          ['First Aid', 'Medical'],
        'skill':           'Medical',
        'lat':             _baseLat - 0.025, // ~3.2km
        'lng':             _baseLng + 0.020,
        'distance':        3.2,
        'available':       true,
        'tasksCompleted':  5,
        'avgResponseTime': 12.0,
        'rating':          3.6,
        'responseRate':    0.60,
        'reliability':     3.4,
      },

      // ── Unavailable (for realism) ──
      {
        'name':            'Sai Patel',
        'phone':           '+91 98765 43218',
        'skills':          ['Transport', 'Evacuation'],
        'skill':           'Transport',
        'lat':             _baseLat + 0.008,
        'lng':             _baseLng - 0.006,
        'distance':        1.0,
        'available':       false,
        'tasksCompleted':  22,
        'avgResponseTime': 6.0,
        'rating':          4.3,
        'responseRate':    0.85,
        'reliability':     4.1,
      },
      {
        'name':            'Isha Chatterjee',
        'phone':           '+91 98765 43219',
        'skills':          ['Medical', 'Food & Water'],
        'skill':           'Medical',
        'lat':             _baseLat - 0.005,
        'lng':             _baseLng + 0.010,
        'distance':        0.7,
        'available':       false,
        'tasksCompleted':  3,
        'avgResponseTime': 15.0,
        'rating':          3.4,
        'responseRate':    0.50,
        'reliability':     3.2,
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

  // ── Emergencies (5) ─────────────────────────────────────────────────────
  static Future<void> _seedEmergencies() async {
    final emergencies = [
      {
        'type':                'Medical',
        'userLat':             _baseLat + 0.002,
        'userLng':             _baseLng - 0.001,
        'status':              'pending',
        'assignedVolunteerId': null,
        'timestamp':           Timestamp.now(),
        'specificAction':      'Request medical volunteer — 0.4 km away',
        'victimId':            'victim_001',
      },
      {
        'type':                'Fire',
        'userLat':             _baseLat - 0.008,
        'userLng':             _baseLng + 0.004,
        'status':              'pending',
        'assignedVolunteerId': null,
        'timestamp':           Timestamp.fromDate(
            DateTime.now().subtract(const Duration(minutes: 8))),
        'specificAction':      'Request evacuation help — 0.9 km away',
        'victimId':            'victim_002',
      },
      {
        'type':                'Accident',
        'userLat':             _baseLat + 0.010,
        'userLng':             _baseLng + 0.006,
        'status':              'accepted',
        'assignedVolunteerId': 'demo_vol_1',
        'timestamp':           Timestamp.fromDate(
            DateTime.now().subtract(const Duration(minutes: 25))),
        'specificAction':      'Request immediate transport',
        'victimId':            'victim_003',
      },
      {
        'type':                'Safety',
        'userLat':             _baseLat - 0.003,
        'userLng':             _baseLng - 0.005,
        'status':              'completed',
        'assignedVolunteerId': 'demo_vol_2',
        'timestamp':           Timestamp.fromDate(
            DateTime.now().subtract(const Duration(hours: 2))),
        'specificAction':      'Request someone to accompany',
        'victimId':            'victim_004',
      },
      {
        'type':                'Disaster',
        'userLat':             _baseLat + 0.005,
        'userLng':             _baseLng + 0.012,
        'status':              'pending',
        'assignedVolunteerId': null,
        'timestamp':           Timestamp.fromDate(
            DateTime.now().subtract(const Duration(minutes: 3))),
        'specificAction':      'Find shelter — 1.2 km away',
        'victimId':            'victim_005',
      },
    ];

    final batch = _db.batch();
    for (final e in emergencies) {
      batch.set(_db.collection('emergencies').doc(), e);
    }
    await batch.commit();
    debugPrint('  → Seeded ${emergencies.length} emergencies');
  }

  // ── Hospitals / Services (5) ─────────────────────────────────────────────
  static Future<void> _seedHospitals() async {
    final hospitals = [
      {
        'name':  'Lilavati Hospital',
        'phone': '+91 22 2675 1000',
        'lat':   _baseLat + 0.008,
        'lng':   _baseLng + 0.005,
        'type':  'hospital',
      },
      {
        'name':  'Hinduja Hospital',
        'phone': '+91 22 2445 1515',
        'lat':   _baseLat - 0.012,
        'lng':   _baseLng + 0.010,
        'type':  'hospital',
      },
      {
        'name':  'Bombay Hospital',
        'phone': '+91 22 2206 7676',
        'lat':   _baseLat + 0.003,
        'lng':   _baseLng - 0.015,
        'type':  'hospital',
      },
      {
        'name':  'KEM Hospital',
        'phone': '+91 22 2410 7000',
        'lat':   _baseLat - 0.020,
        'lng':   _baseLng - 0.008,
        'type':  'hospital',
      },
      {
        'name':  'Nanavati Max Hospital',
        'phone': '+91 22 2626 7500',
        'lat':   _baseLat + 0.018,
        'lng':   _baseLng - 0.010,
        'type':  'hospital',
      },
    ];

    final batch = _db.batch();
    for (final h in hospitals) {
      batch.set(_db.collection('hospitals').doc(), h);
    }
    await batch.commit();
    debugPrint('  → Seeded ${hospitals.length} hospitals');
  }

  // ── Users (demo victim + volunteer account) ──────────────────────────────
  static Future<void> _seedUsers() async {
    final users = [
      {
        'role':  'victim',
        'name':  'Demo Victim',
        'phone': '+91 90000 00001',
        'lat':   _baseLat,
        'lng':   _baseLng,
      },
      {
        'role':  'volunteer',
        'name':  'Demo Volunteer',
        'phone': '+91 90000 00002',
        'lat':   _baseLat + 0.004,
        'lng':   _baseLng + 0.002,
      },
    ];

    final batch = _db.batch();
    for (final u in users) {
      batch.set(_db.collection('users').doc(), u);
    }
    await batch.commit();
    debugPrint('  → Seeded ${users.length} demo users');
  }
}
