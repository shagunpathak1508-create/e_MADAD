import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'services/location_service.dart';
import 'services/connectivity_service.dart';
import 'services/firestore_seed_service.dart';
import 'screens/permissions_screen.dart';
import 'screens/home_screen.dart';
import 'screens/sos_screen.dart';
import 'screens/emergency_type_screen.dart';
import 'screens/emergency_response_screen.dart';
import 'screens/volunteer_match_screen.dart';
import 'screens/map_screen.dart';
import 'screens/volunteer_signup_screen.dart';
import 'screens/volunteer_dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  bool firebaseInitialized = false;
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    
    // Offline persistence
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
    firebaseInitialized = true;
  } catch (e) {
    debugPrint('Firebase core initialization failed: $e\nPlease check configuration.');
  }

  if (firebaseInitialized) {
    try {
      // Anonymous auth
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
      }
    } catch (e) {
      debugPrint('Firebase Anonymous Auth failed: $e\nApp will run in degraded/offline mode.');
    }
  }

  if (!firebaseInitialized) {
    runApp(const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'Firebase Initialization Failed.\nPlease check configuration.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    ));
    return;
  }

  // Start GPS tracking for offline trail
  LocationService.startTracking();

  // Start connectivity monitoring
  ConnectivityService.startListening();

  // Seed demo data in background (non-blocking, runs only once)
  FirestoreSeedService.seedIfNeeded();

  runApp(const EMadadApp());
}

class EMadadApp extends StatelessWidget {
  const EMadadApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'eमदद',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const _StartRouter(),
      routes: {
        '/home': (_) => const HomeScreen(),
        '/sos': (_) => const SosScreen(),
        '/emergency-type': (_) => const EmergencyTypeScreen(),
        '/emergency-response': (_) => const EmergencyResponseScreen(),
        '/volunteer-match': (_) => const VolunteerMatchScreen(),
        '/map': (_) => const MapScreen(),
        '/volunteer': (_) => const _VolunteerRouter(),
        '/volunteer-signup': (_) => const VolunteerSignupScreen(),
        '/dashboard': (_) => const VolunteerDashboardScreen(),
      },
    );
  }
}

/// Decides first launch (show permissions) vs returning user (go to home)
class _StartRouter extends StatefulWidget {
  const _StartRouter();
  @override
  State<_StartRouter> createState() => _StartRouterState();
}

class _StartRouterState extends State<_StartRouter> {
  @override
  void initState() {
    super.initState();
    _route();
  }

  Future<void> _route() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool('seen_permissions') ?? false;
    if (!seen) {
      await prefs.setBool('seen_permissions', true);
    }
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => seen ? const HomeScreen() : const PermissionsScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppTheme.offWhite,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _LogoWidget(),
            SizedBox(height: 24),
            CircularProgressIndicator(color: AppTheme.orange, strokeWidth: 2),
          ],
        ),
      ),
    );
  }
}

/// Routes to volunteer signup or dashboard depending on registration
class _VolunteerRouter extends StatefulWidget {
  const _VolunteerRouter();
  @override
  State<_VolunteerRouter> createState() => _VolunteerRouterState();
}

class _VolunteerRouterState extends State<_VolunteerRouter> {
  @override
  void initState() {
    super.initState();
    _route();
  }

  Future<void> _route() async {
    final prefs = await SharedPreferences.getInstance();
    final vid = prefs.getString('volunteer_id');
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => vid != null
              ? const VolunteerDashboardScreen()
              : const VolunteerSignupScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator(color: AppTheme.green)),
    );
  }
}

class _LogoWidget extends StatelessWidget {
  const _LogoWidget();
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            color: AppTheme.orange,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                  color: AppTheme.orange.withValues(alpha: 0.4),
                  blurRadius: 24, offset: const Offset(0, 8))
            ],
          ),
          child: const Icon(Icons.shield_outlined,
              color: Colors.white, size: 42),
        ),
        const SizedBox(height: 16),
        const Text(
          'eमदद',
          style: TextStyle(
              fontSize: 28, fontWeight: FontWeight.w900,
              color: AppTheme.textDark),
        ),
        const SizedBox(height: 4),
        Text(
          'Emergency Help Network',
          style: TextStyle(fontSize: 13, color: AppTheme.textGrey),
        ),
      ],
    );
  }
}
