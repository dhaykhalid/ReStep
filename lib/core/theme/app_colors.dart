import 'package:flutter/material.dart';

/// Brand colors sampled from the ReStep logo.
/// navy  = "ReS" lettering, sky = running figure and "ep" lettering.
class AppColors {
  AppColors._();

  // Brand
  static const Color navy = Color(0xFF003070);
  static const Color navyDark = Color(0xFF002050);
  static const Color sky = Color(0xFF54C8E4);
  static const Color skyTint = Color(0xFFE6F6FB);
  static const Color skySoft = Color(0xFFCDEEF8);
  static const Color navyTint = Color(0xFFE9EFF8);

  // Neutrals
  static const Color white = Color(0xFFFFFFFF);
  static const Color ink = Color(0xFF0E1B2E);
  static const Color muted = Color(0xFF50617A);
  static const Color border = Color(0xFFE2E9F2);
  static const Color fieldFill = Color(0xFFF6F9FC);

  // Status
  static const Color success = Color(0xFF1B7F4B);
  static const Color successTint = Color(0xFFE5F5EC);
  static const Color warning = Color(0xFF8A5200);
  static const Color warningTint = Color(0xFFFFF3DC);
  static const Color danger = Color(0xFFC62828);
  static const Color dangerTint = Color(0xFFFDECEC);

  // Effects
  static const Color shadow = Color(0x14003070);
  static const Color onNavyOverlay = Color(0x26FFFFFF);
}
