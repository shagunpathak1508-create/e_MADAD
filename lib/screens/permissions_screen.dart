import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../theme/app_theme.dart';

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});
  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  bool _locationGranted = false;
  bool _contactsGranted = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final loc = await Permission.location.status;
    final con = await Permission.contacts.status;
    setState(() {
      _locationGranted = loc.isGranted;
      _contactsGranted = con.isGranted;
    });
  }

  Future<void> _requestPermission(Permission perm, bool isLocation) async {
    final status = await perm.request();
    setState(() {
      if (isLocation) {
        _locationGranted = status.isGranted;
      } else {
        _contactsGranted = status.isGranted;
      }
    });
  }

  Future<void> _continue() async {
    if (!_locationGranted || !_contactsGranted) return;
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) Navigator.pushReplacementNamed(context, '/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 24),
              // Logo
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppTheme.orange,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.orange.withOpacity(0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(Icons.shield_outlined, color: Colors.white, size: 40),
              ),
              const SizedBox(height: 24),
              Text(
                'Welcome to eमदद',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textDark,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'To help you in emergencies, we need a few\npermissions',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textGrey, fontSize: 14),
              ),
              const SizedBox(height: 40),

              // Location card
              _PermissionCard(
                icon: Icons.location_on_rounded,
                title: 'Location Access',
                subtitle: 'Required to find nearby help and services',
                granted: _locationGranted,
                onTap: () => _requestPermission(Permission.location, true),
              ),
              const SizedBox(height: 16),

              // Contacts card
              _PermissionCard(
                icon: Icons.contacts_rounded,
                title: 'Contacts Access',
                subtitle: 'Alert your emergency contacts when needed',
                granted: _contactsGranted,
                onTap: () => _requestPermission(Permission.contacts, false),
              ),
              const SizedBox(height: 24),

              // Privacy notice
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.orange.withOpacity(0.15)),
                ),
                child: Text(
                  'Your data is only used during emergencies and is never shared with third parties without your consent.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTheme.textGrey,
                    fontSize: 12,
                  ),
                ),
              ),
              const Spacer(),

              // Continue button
              SizedBox(
                width: double.infinity,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  child: ElevatedButton(
                    onPressed: (_locationGranted && _contactsGranted && !_loading)
                        ? _continue
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: (_locationGranted && _contactsGranted)
                          ? AppTheme.orange
                          : AppTheme.orange.withOpacity(0.4),
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text(
                            'Continue',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermissionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool granted;
  final VoidCallback onTap;

  const _PermissionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.granted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: granted ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: granted ? AppTheme.green.withOpacity(0.06) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: granted ? AppTheme.green : AppTheme.orange.withOpacity(0.2),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: granted ? AppTheme.green : AppTheme.orange,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                granted ? Icons.check_rounded : icon,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(color: AppTheme.textGrey, fontSize: 13),
                  ),
                ],
              ),
            ),
            if (!granted)
              Icon(Icons.chevron_right_rounded,
                  color: AppTheme.orange.withOpacity(0.6)),
          ],
        ),
      ),
    );
  }
}
