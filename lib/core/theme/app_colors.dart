import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color primary = Color(0xFFFF5C8A);
  static const Color primaryDark = Color(0xFFE8447A);
  static const Color secondary = Color(0xFF7C5CFF);
  static const Color accent = Color(0xFFFFC15C);

  static const LinearGradient loveGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF5C8A), Color(0xFF7C5CFF)],
  );

  static const Color lightBg = Color(0xFFFFF7F9);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFEFF3);

  static const Color darkBg = Color(0xFF120B1E);
  static const Color darkSurface = Color(0xFF1E1430);
  static const Color darkCard = Color(0xFF2A1D42);

  static const Color textPrimaryLight = Color(0xFF241B2E);
  static const Color textSecondaryLight = Color(0xFF6E6379);
  static const Color textPrimaryDark = Color(0xFFF5F1FA);
  static const Color textSecondaryDark = Color(0xFFB7ADC4);

  static const Color success = Color(0xFF4CD787);
  static const Color warning = Color(0xFFFFB020);
  static const Color error = Color(0xFFFF5C6C);

  static const Color moodHappy = Color(0xFFFFC15C);
  static const Color moodRomantic = Color(0xFFFF5C8A);
  static const Color moodSad = Color(0xFF6C8BFF);
  static const Color moodStressed = Color(0xFFFF7A5C);
  static const Color moodCalm = Color(0xFF5CD6C0);
}
