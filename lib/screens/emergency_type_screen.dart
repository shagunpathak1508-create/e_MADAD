import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class EmergencyType {
  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Color colorEnd;

  const EmergencyType({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.colorEnd,
  });
}

const _types = [
  EmergencyType(
    label: 'Medical',
    subtitle: 'Health emergency',
    icon: Icons.medical_services_rounded,
    color: Color(0xFFE91E63),
    colorEnd: Color(0xFFD32F2F),
  ),
  EmergencyType(
    label: 'Accident',
    subtitle: 'Road or vehicle',
    icon: Icons.directions_car_rounded,
    color: Color(0xFFFF6B00),
    colorEnd: Color(0xFFFF9800),
  ),
  EmergencyType(
    label: 'Fire',
    subtitle: 'Fire emergency',
    icon: Icons.local_fire_department_rounded,
    color: Color(0xFFFF4500),
    colorEnd: Color(0xFFFF6B00),
  ),
  EmergencyType(
    label: 'Safety',
    subtitle: 'Personal safety',
    icon: Icons.shield_rounded,
    color: Color(0xFF138808),
    colorEnd: Color(0xFF2E7D32),
  ),
  EmergencyType(
    label: 'Disaster',
    subtitle: 'Natural calamity',
    icon: Icons.thunderstorm_rounded,
    color: Color(0xFF37474F),
    colorEnd: Color(0xFF263238),
  ),
  EmergencyType(
    label: 'Help Request',
    subtitle: 'General assistance',
    icon: Icons.help_rounded,
    color: Color(0xFF1565C0),
    colorEnd: Color(0xFF1976D2),
  ),
];

class EmergencyTypeScreen extends StatelessWidget {
  const EmergencyTypeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('What is your emergency?',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: AppTheme.textDark)),
            Text('Select the type of help you need',
                style:
                    TextStyle(fontSize: 12, color: AppTheme.textGrey)),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: 1.05,
          ),
          itemCount: _types.length,
          itemBuilder: (context, i) {
            final type = _types[i];
            return _EmergencyCard(
              type: type,
              onTap: () => Navigator.pushNamed(
                context,
                '/emergency-response',
                arguments: type.label,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _EmergencyCard extends StatefulWidget {
  final EmergencyType type;
  final VoidCallback onTap;

  const _EmergencyCard({required this.type, required this.onTap});

  @override
  State<_EmergencyCard> createState() => _EmergencyCardState();
}

class _EmergencyCardState extends State<_EmergencyCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 120));
    _scale = Tween<double>(begin: 1.0, end: 0.94)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, child) => Transform.scale(scale: _scale.value, child: child),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [widget.type.color, widget.type.colorEnd],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: widget.type.color.withOpacity(0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(widget.type.icon, color: Colors.white, size: 28),
              ),
              const SizedBox(height: 12),
              Text(
                widget.type.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.type.subtitle,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
