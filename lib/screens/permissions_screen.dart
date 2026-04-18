import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final loc = await Permission.location.status;
    bool conGranted = false;
    
    if (!kIsWeb) {
      final con = await Permission.contacts.status;
      conGranted = con.isGranted;
    }
    
    setState(() {
      _locationGranted = loc.isGranted;
      _contactsGranted = conGranted;
    });
  }

  Future<void> _requestPermission(Permission perm, bool isLocation) async {
    if (!isLocation && kIsWeb) {
      // Contacts not supported on web
      return;
    }
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
    // Location is mandatory; contacts is optional (for SMS)
    if (!_locationGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location access is required for emergency services'),
          backgroundColor: AppTheme.danger,
        ),
      );
      return;
    }
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
                      color: AppTheme.orange.withValues(alpha: 0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(Icons.shield_outlined, color: Colors.white, size: 40),
              ),
              const SizedBox(height: 24),
              Text(
                'Welcome to E-मदद',
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

              // Location card (mandatory)
              _PermissionCard(
                icon: Icons.location_on_rounded,
                title: 'Location Access',
                subtitle: 'Required to find nearby help and services',
                granted: _locationGranted,
                mandatory: true,
                onTap: () => _requestPermission(Permission.location, true),
              ),
              const SizedBox(height: 16),

              // Contacts card (optional)
              _PermissionCard(
                icon: Icons.contacts_rounded,
                title: 'Contacts Access',
                subtitle: 'Alert your emergency contacts via SMS',
                granted: _contactsGranted,
                mandatory: false,
                onTap: () => _requestPermission(Permission.contacts, false),
              ),
              const SizedBox(height: 24),

              // Warning if contacts not granted
              if (!_contactsGranted && _locationGranted)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Contacts access is optional but helps send emergency SMS to your contacts.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),

              if (_contactsGranted || !_locationGranted)
                // Privacy notice
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.orange.withValues(alpha: 0.15)),
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

              // Continue button — enabled when location granted
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _locationGranted ? _continue : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _locationGranted
                        ? AppTheme.orange
                        : AppTheme.orange.withValues(alpha: 0.4),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Continue',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
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
  final bool mandatory;
  final VoidCallback onTap;

  const _PermissionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.granted,
    required this.onTap,
    this.mandatory = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: granted ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: granted ? AppTheme.green.withValues(alpha: 0.06) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: granted ? AppTheme.green : AppTheme.orange.withValues(alpha: 0.2),
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
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                      if (mandatory) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.danger.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('Required',
                              style: TextStyle(
                                  color: AppTheme.danger,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ],
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
                  color: AppTheme.orange.withValues(alpha: 0.6)),
          ],
        ),
      ),
    );
  }
}
