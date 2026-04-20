import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Volunteer Signup — DISABLED in demo mode.
///
/// Shows an informational screen explaining that registration is disabled and
/// redirects the user to the DemoLoginScreen to pick a pre-seeded profile.
class VolunteerSignupScreen extends StatelessWidget {
  const VolunteerSignupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.offWhite,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                size: 18, color: AppTheme.textDark),
          ),
        ),
        title: const Text('Join as Volunteer',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon
            Container(
              width: 90, height: 90,
              decoration: BoxDecoration(
                color: AppTheme.orange.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.info_outline_rounded,
                  color: AppTheme.orange, size: 44),
            ),
            const SizedBox(height: 28),

            // Title
            const Text(
              'Demo Mode Active',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.textDark),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // Description
            Text(
              'Volunteer registration is disabled during the demo.\n'
              'Please select one of the pre-seeded demo volunteer profiles to continue.',
              style: TextStyle(
                  fontSize: 15,
                  color: AppTheme.textGrey,
                  height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // Feature list
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE8E8E8)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Feature('8 pre-seeded volunteer profiles'),
                  SizedBox(height: 8),
                  _Feature('Medical, Fire & Rescue specialists'),
                  SizedBox(height: 8),
                  _Feature('Realistic reliability scores'),
                  SizedBox(height: 8),
                  _Feature('Real-time emergency requests via Firestore'),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // CTA button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () =>
                    Navigator.pushReplacementNamed(context, '/demo-login'),
                icon: const Icon(Icons.people_alt_rounded, color: Colors.white),
                label: const Text('Browse Demo Volunteers',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.green,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  final String text;
  const _Feature(this.text);

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Icon(Icons.check_circle_rounded,
          color: AppTheme.green, size: 16),
      const SizedBox(width: 10),
      Text(text,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
    ],
  );
}
