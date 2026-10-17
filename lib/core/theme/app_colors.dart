import 'package:flutter/material.dart';

/// ReStep color palette.
/// navy = "ReS" lettering, sky = running figure and "ep" lettering.
class AppColors {
  AppColors._();

  // Brand
  static const Color navy = Color(0xFF063B82);
  static const Color navyDark = Color(0xFF042A5E);
  static const Color sky = Color(0xFF4BC3DC);
  static const Color skyTint = Color(0xFFE8F7FB);
  static const Color skySoft = Color(0xFFD2F0F7);
  static const Color navyTint = Color(0xFFEAF0F9);

  // Neutrals
  static const Color white = Color(0xFFFFFFFF);

  /// Grouped page background (iOS-style off-white); cards sit on top in white.
  static const Color background = Color(0xFFF4F6FA);
  static const Color ink = Color(0xFF0E1B2E);
  static const Color muted = Color(0xFF50617A);
  static const Color border = Color(0xFFE3E8EF);
  static const Color fieldFill = Color(0xFFFFFFFF);

  // Status: success = green, danger = red, warning = amber, info = blue.
  static const Color success = Color(0xFF1B7F4B);
  static const Color successTint = Color(0xFFE6F5EC);
  static const Color warning = Color(0xFF8A5200);
  static const Color warningTint = Color(0xFFFFF3DC);
  static const Color danger = Color(0xFFC62828);
  static const Color dangerTint = Color(0xFFFDECEC);
  static const Color info = navy;
  static const Color infoTint = Color(0xFFE7F0FB);

  // Effects
  static const Color shadow = Color(0x0F0A2552);
  static const Color scrim = Color(0x660E1B2E);
  static const Color onNavyOverlay = Color(0x26FFFFFF);
}
