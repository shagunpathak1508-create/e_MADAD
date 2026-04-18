import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/volunteer_model.dart';
import '../services/firestore_service.dart';
import '../services/location_service.dart';

const _allSkills = [
  'First Aid', 'Transport', 'Evacuation', 'Search & Rescue',
  'Shelter', 'Food & Water', 'Medical', 'Firefighting',
];

class VolunteerSignupScreen extends StatefulWidget {
  const VolunteerSignupScreen({super.key});
  @override
  State<VolunteerSignupScreen> createState() => _VolunteerSignupScreenState();
}

class _VolunteerSignupScreenState extends State<VolunteerSignupScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final Set<String> _selectedSkills = {};
  bool _isAvailable = true;
  bool _loading = false;

  Future<void> _register() async {
    if (_nameCtrl.text.trim().isEmpty || _phoneCtrl.text.trim().isEmpty) {
      _showSnack('Please fill in name and phone number');
      return;
    }
    if (_selectedSkills.isEmpty) {
      _showSnack('Select at least one skill');
      return;
    }
    setState(() => _loading = true);

    try {
      final pos = await LocationService.getCurrentLocation();
      // getCurrentLocation() always returns a valid position (GPS or demo fallback)
      
      final vol = VolunteerModel(
        id: '',
        name: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        skills: _selectedSkills.toList(),
        available: _isAvailable,
        tasksCompleted: 0,
        lat: pos.latitude,
        lng: pos.longitude,
      );
      await FirestoreService.registerVolunteer(vol);
      if (mounted) Navigator.pushReplacementNamed(context, '/dashboard');
    } catch (e) {
      debugPrint('Registration error: $e');
      _showSnack('Registration failed. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppTheme.orange));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [AppTheme.green, AppTheme.greenLight]),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle),
                    child: const Icon(Icons.volunteer_activism_rounded,
                        color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 14),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Become a Volunteer',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 16)),
                      Text('Help your community in need',
                          style: TextStyle(
                              color: Colors.white70, fontSize: 13)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            const _SectionLabel('Full Name'),
            const SizedBox(height: 8),
            _Input(
              controller: _nameCtrl,
              hint: 'Enter your full name',
              icon: Icons.person_rounded,
            ),
            const SizedBox(height: 16),

            const _SectionLabel('Phone Number'),
            const SizedBox(height: 8),
            _Input(
              controller: _phoneCtrl,
              hint: '+91 XXXXX XXXXX',
              icon: Icons.phone_rounded,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 20),

            const _SectionLabel('Select Skills (up to 3)'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: _allSkills.map((skill) {
                final selected = _selectedSkills.contains(skill);
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (selected) {
                        _selectedSkills.remove(skill);
                      } else if (_selectedSkills.length < 3) {
                        _selectedSkills.add(skill);
                      }
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: selected ? AppTheme.green : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: selected ? AppTheme.green : const Color(0xFFE0E0E0)),
                      boxShadow: selected
                          ? [BoxShadow(
                              color: AppTheme.green.withValues(alpha: 0.2),
                              blurRadius: 8)]
                          : [],
                    ),
                    child: Text(skill,
                        style: TextStyle(
                          color: selected ? Colors.white : AppTheme.textDark,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        )),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Availability toggle
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE8E8E8)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Availability',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 15)),
                        const SizedBox(height: 2),
                        Text(
                            _isAvailable
                                ? 'You are currently available'
                                : 'You are currently unavailable',
                            style: TextStyle(
                                color: AppTheme.textGrey, fontSize: 13)),
                      ],
                    ),
                  ),
                  Switch(
                    value: _isAvailable,
                    onChanged: (v) => setState(() => _isAvailable = v),
                    activeTrackColor: AppTheme.green.withValues(alpha: 0.5),
                    activeThumbColor: AppTheme.green,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _register,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.green,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _loading
                    ? const SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5))
                    : const Text('Register as Volunteer',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);
  @override
  Widget build(BuildContext context) => Text(label,
      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14));
}

class _Input extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;

  const _Input({
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: AppTheme.textGrey, fontSize: 14),
          prefixIcon: Icon(icon, color: AppTheme.orange, size: 20),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      ),
    );
  }
}
