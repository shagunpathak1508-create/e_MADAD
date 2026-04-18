import 'package:flutter/material.dart';
import 'dart:async';
import '../theme/app_theme.dart';
import '../services/connectivity_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isOnline = true;
  StreamSubscription<bool>? _connectivitySub;

  @override
  void initState() {
    super.initState();
    ConnectivityService.checkOnline().then((v) {
      if (mounted) setState(() => _isOnline = v);
    });
    _connectivitySub = ConnectivityService.onlineStream.listen((online) {
      if (mounted) setState(() => _isOnline = online);
    });
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      body: SafeArea(
        child: Column(
          children: [
            // Offline banner
            if (!_isOnline)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: AppTheme.danger,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.wifi_off_rounded, color: Colors.white, size: 16),
                    SizedBox(width: 8),
                    Text('You are offline',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Header — E-मदद branding
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.orange,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.shield_outlined,
                              color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'E-मदद',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 22,
                            color: AppTheme.textDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Tricolour bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                            width: 48, height: 3,
                            decoration: BoxDecoration(
                                color: AppTheme.orange,
                                borderRadius: BorderRadius.circular(2))),
                        const SizedBox(width: 6),
                        Container(
                            width: 48, height: 3,
                            decoration: BoxDecoration(
                                color: AppTheme.green,
                                borderRadius: BorderRadius.circular(2))),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // I Want Help — BIG orange card (LARGER, primary)
                    Expanded(
                      flex: 5,
                      child: GestureDetector(
                        onTap: () => Navigator.pushNamed(context, '/sos'),
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: AppTheme.orange,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.orange.withValues(alpha: 0.4),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Stack(
                            children: [
                              // SOS Ready badge
                              Positioned(
                                top: 16,
                                right: 16,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                          width: 6,
                                          height: 6,
                                          decoration: const BoxDecoration(
                                              color: Colors.white,
                                              shape: BoxShape.circle)),
                                      const SizedBox(width: 5),
                                      const Text('SOS Ready',
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                              ),
                              Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 72,
                                      height: 72,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.2),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.favorite_border_rounded,
                                          color: Colors.white, size: 36),
                                    ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'I Want Help',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 28,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Get emergency assistance now',
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.85),
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // I Want to Help — smaller green card
                    Expanded(
                      flex: 3,
                      child: GestureDetector(
                        onTap: () => Navigator.pushNamed(context, '/volunteer'),
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: AppTheme.green,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.green.withValues(alpha: 0.35),
                                blurRadius: 20,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(Icons.people_alt_outlined,
                                    color: Colors.white, size: 28),
                              ),
                              const SizedBox(width: 16),
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'I Want to Help',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    'Become a volunteer',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.85),
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Bottom stats
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.people_rounded, size: 16,
                            color: Color(0xFF888888)),
                        const SizedBox(width: 5),
                        Text('1,234 Volunteers',
                            style: TextStyle(
                                color: AppTheme.textGrey,
                                fontSize: 13,
                                fontWeight: FontWeight.w500)),
                        Container(
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                            width: 4,
                            height: 4,
                            decoration: const BoxDecoration(
                                color: Color(0xFF888888), shape: BoxShape.circle)),
                        const Icon(Icons.location_on_rounded, size: 16,
                            color: Color(0xFF888888)),
                        const SizedBox(width: 4),
                        Text('Location Active',
                            style: TextStyle(color: AppTheme.textGrey, fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: AppTheme.green.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                              width: 8, height: 8,
                              decoration: BoxDecoration(
                                  color: _isOnline ? AppTheme.green : AppTheme.danger,
                                  shape: BoxShape.circle)),
                          const SizedBox(width: 8),
                          Text(
                              _isOnline
                                  ? '24/7 Emergency Support Available'
                                  : 'Offline — SMS & Cached Data Available',
                              style: TextStyle(
                                  color: AppTheme.textDark,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
