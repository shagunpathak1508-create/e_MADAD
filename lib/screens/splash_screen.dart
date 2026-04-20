import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'permissions_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // ── Animation controllers ────────────────────────────────────────────────
  late final AnimationController _fadeController;
  late final AnimationController _scaleController;
  late final AnimationController _textFadeController;
  late final AnimationController _taglineFadeController;

  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _textFadeAnimation;
  late final Animation<double> _taglineAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _startAnimationSequence();
  }

  void _initAnimations() {
    // Logo fade-in
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    // Logo subtle scale-up (1.0 → 1.0, starts from 0.82)
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _scaleAnimation = Tween<double>(begin: 0.82, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOutBack),
    );

    // App name fade-in
    _textFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _textFadeAnimation = CurvedAnimation(
      parent: _textFadeController,
      curve: Curves.easeOut,
    );

    // Tagline fade-in
    _taglineFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _taglineAnimation = CurvedAnimation(
      parent: _taglineFadeController,
      curve: Curves.easeOut,
    );
  }

  Future<void> _startAnimationSequence() async {
    // Step 1: Scale + fade the logo in
    await Future.wait([
      _fadeController.forward(),
      _scaleController.forward(),
    ]);

    // Step 2: Fade in app name (100ms gap)
    await Future.delayed(const Duration(milliseconds: 100));
    await _textFadeController.forward();

    // Step 3: Fade in tagline (80ms gap)
    await Future.delayed(const Duration(milliseconds: 80));
    await _taglineFadeController.forward();

    // Step 4: Wait a moment, then navigate
    await Future.delayed(const Duration(milliseconds: 1200));
    _navigate();
  }

  Future<void> _navigate() async {
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final seenPermissions = prefs.getBool('seen_permissions') ?? false;
    final user = FirebaseAuth.instance.currentUser;

    Widget destination;

    if (!seenPermissions) {
      // First-ever launch → permissions flow
      destination = const PermissionsScreen();
    } else if (user != null) {
      // Already authenticated → go straight to home
      destination = const HomeScreen();
    } else {
      // Fallback: show home (app signs in anonymously anyway)
      destination = const HomeScreen();
    }

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => destination,
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    _textFadeController.dispose();
    _taglineFadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ── Logo ──────────────────────────────────────────────────────
            FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: const _SplashLogo(),
              ),
            ),

            const SizedBox(height: 24),

            // ── Tagline (logo already has the app name) ───────────────────
            FadeTransition(
              opacity: _textFadeAnimation,
              child: const Text(
                'Emergency Help Network',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textGrey,
                  letterSpacing: 0.3,
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── Tricolour accent bar ──────────────────────────────────────
            FadeTransition(
              opacity: _taglineAnimation,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 40,
                    height: 3,
                    decoration: BoxDecoration(
                      color: AppTheme.orange,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Container(
                    width: 40,
                    height: 3,
                    decoration: BoxDecoration(
                      color: AppTheme.green,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      // ── Footer ─────────────────────────────────────────────────────────
      bottomNavigationBar: FadeTransition(
        opacity: _taglineAnimation,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Made in India 🇮🇳',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textGrey.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Renders the real eMADAD logo as a rounded square app-icon.
/// The logo already has its own orange background and app name,
/// so no extra colour wrapping is applied here.
class _SplashLogo extends StatelessWidget {
  const _SplashLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      // Subtle shadow so the logo lifts off the white background
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppTheme.orange.withValues(alpha: 0.30),
            blurRadius: 36,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Image.asset(
          'assets/logo.png',
          width: 160,
          height: 160,
          fit: BoxFit.cover,
          // Fallback if asset not found (orange shield icon)
          errorBuilder: (_, __, ___) => Container(
            width: 160,
            height: 160,
            color: AppTheme.orange,
            child: const Icon(
              Icons.shield_outlined,
              color: Colors.white,
              size: 72,
            ),
          ),
        ),
      ),
    );
  }
}
