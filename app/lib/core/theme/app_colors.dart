import 'package:flutter/material.dart';

/// Shared TradeIQ palette for the premium public app flows.
class AppColors {
  AppColors._();

  static const canvas = Color(0xFF050505);
  static const background = Color(0xFF0F1117);
  static const surface = Color(0xFF1A1D24);
  static const input = Color(0xFF262A33);
  static const outline = Color(0xFF343A46);

  static const blue = Color(0xFF0052CC);
  static const blueLight = Color(0xFF007AFF);
  static const blueDark = Color(0xFF003399);

  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFFA9B0BE);
  static const textMuted = Color(0xFF737B8C);
  static const success = Color(0xFF3FC7A6);
  static const warning = Color(0xFFE8C15A);
  static const danger = Color(0xFFFF6B7A);

  // Compatibility aliases for existing feature code.
  static const navyBackground = background;
  static const navySurface = surface;
  static const primaryBlue = blueLight;
  static const accentOrange = Color(0xFFE8895A);
  static const accentTeal = success;
  static const accentGold = warning;
  static const accentPink = Color(0xFFE85A8A);
}
