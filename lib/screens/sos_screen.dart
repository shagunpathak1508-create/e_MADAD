import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../services/firestore_service.dart';
import '../services/location_service.dart';
import '../models/emergency_model.dart';

class SosScreen extends StatefulWidget {
  const SosScreen({super.key});
  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _progressController;
  late Animation<double> _pulseAnim;
  bool _holding = false;
  bool _activated = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );
    _progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_activated) {
        _activated = true;
        HapticFeedback.heavyImpact();
        setState(() {}); // trigger green state rebuild

        // Instant background emergency trigger
        _triggerEmergency();

        // Show green state for 500ms, then navigate
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            Navigator.pushNamed(context, '/emergency-type');
          }
        });
      }
    });
  }

  Future<void> _triggerEmergency() async {
    final pos = await LocationService.getCurrentLocation();
    final emergency = EmergencyModel(
      id: '',
      type: 'general_emergency',
      userLat: pos.latitude,
      userLng: pos.longitude,
      timestamp: DateTime.now(),
      status: 'pending',
    );

    // Fire and forget (async background)
    FirestoreService.createEmergency(emergency).catchError((e) {
      debugPrint('Background SOS trigger failed: $e');
      return '';
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  void _onHoldStart() {
    setState(() => _holding = true);
    _pulseController.stop();
    _progressController.forward(from: 0);
  }

  void _onHoldEnd() {
    if (!_activated) {
      setState(() => _holding = false);
      _pulseController.repeat(reverse: true);
      _progressController.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Button color: green after activation, red otherwise
    final buttonColor = _activated ? AppTheme.green : AppTheme.danger;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF0F0),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8)
              ],
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                size: 18, color: AppTheme.textDark),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Emergency SOS',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: AppTheme.textDark)),
            Text('Hold to activate',
                style: TextStyle(fontSize: 13, color: AppTheme.textGrey)),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onLongPressStart: (_) => _onHoldStart(),
                    onLongPressEnd: (_) => _onHoldEnd(),
                    onLongPressCancel: _onHoldEnd,
                    child: AnimatedBuilder(
                      animation: Listenable.merge(
                          [_pulseAnim, _progressController]),
                      builder: (context, _) {
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            // Outer glow ring 1
                            Transform.scale(
                              scale: _holding ? 1.0 : _pulseAnim.value * 1.3,
                              child: Container(
                                width: 200,
                                height: 200,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: buttonColor.withValues(alpha: 0.08),
                                ),
                              ),
                            ),
                            // Outer glow ring 2
                            Transform.scale(
                              scale: _holding ? 1.0 : _pulseAnim.value * 1.15,
                              child: Container(
                                width: 170,
                                height: 170,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: buttonColor.withValues(alpha: 0.12),
                                ),
                              ),
                            ),
                            // Progress ring (green, shows when holding)
                            if (_holding && !_activated)
                              SizedBox(
                                width: 160,
                                height: 160,
                                child: CircularProgressIndicator(
                                  value: _progressController.value,
                                  strokeWidth: 5,
                                  backgroundColor: Colors.transparent,
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                          AppTheme.green),
                                  strokeCap: StrokeCap.round,
                                ),
                              ),
                            // Main SOS button
                            Transform.scale(
                              scale: _holding ? 0.95 : 1.0,
                              child: Container(
                                width: 140,
                                height: 140,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: buttonColor,
                                  boxShadow: [
                                    BoxShadow(
                                      color: buttonColor.withValues(alpha: 0.5),
                                      blurRadius: 30,
                                      spreadRadius: 4,
                                    ),
                                  ],
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      _activated
                                          ? Icons.check_rounded
                                          : Icons.warning_rounded,
                                      color: Colors.white,
                                      size: 36,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _activated ? 'SENT' : 'SOS',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 36),
                  Text(
                    _activated ? 'Emergency Activated!' : 'Hold for SOS',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: _activated ? AppTheme.green : AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (!_activated)
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: TextStyle(color: AppTheme.textGrey, fontSize: 14),
                        children: [
                          const TextSpan(text: 'Press and '),
                          TextSpan(
                              text: 'hold',
                              style: TextStyle(
                                  color: AppTheme.orange,
                                  fontWeight: FontWeight.w700)),
                          const TextSpan(
                              text:
                                  ' the button for 2-3 seconds to\nactivate emergency mode'),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Bottom status
          Padding(
            padding: const EdgeInsets.only(bottom: 48),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: _activated
                    ? AppTheme.green.withValues(alpha: 0.1)
                    : AppTheme.danger.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                    color: _activated
                        ? AppTheme.green.withValues(alpha: 0.2)
                        : AppTheme.danger.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(
                          color: _activated ? AppTheme.green : AppTheme.danger,
                          shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Text(
                    _activated ? 'Emergency Triggered' : 'Emergency Mode Ready',
                    style: TextStyle(
                        color: _activated ? AppTheme.green : AppTheme.danger,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
