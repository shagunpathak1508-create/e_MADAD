import 'package:flutter/material.dart';

class AppTheme {
  // India Tricolour palette
  static const Color orange = Color(0xFFFF6B00);
  static const Color orangeLight = Color(0xFFFF9A3C);
  static const Color green = Color(0xFF138808);
  static const Color greenLight = Color(0xFF1EB80A);
  static const Color white = Color(0xFFFFFFFF);
  static const Color offWhite = Color(0xFFFFF8F0);
  static const Color danger = Color(0xFFDC2626);
  static const Color dangerLight = Color(0xFFFF4444);
  static const Color textDark = Color(0xFF1A1A1A);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color cardBg = Color(0xFFFFF3E8);

  static ThemeData get theme => ThemeData(
        useMaterial3: true,
        fontFamily: 'Poppins',
        scaffoldBackgroundColor: offWhite,
        colorScheme: ColorScheme.fromSeed(
          seedColor: orange,
          primary: orange,
          secondary: green,
          surface: white,
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: white,
          foregroundColor: textDark,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: orange,
            foregroundColor: white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            padding:
                const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ),
        cardTheme: CardThemeData(
          color: white,
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
}
