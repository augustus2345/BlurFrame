import 'package:flutter/material.dart';

/// App color tokens — kept neutral so photos remain the focal point.
/// Use a single warm accent for interactivity.
class AppColors {
  AppColors._();

  // Brand
  static const Color seed = Color(0xFFE85D4A); // warm coral accent
  static const Color accent = Color(0xFFE85D4A);
  static const Color accentMuted = Color(0xFFFAD8D2);

  // Light theme
  static const Color lightBackground = Color(0xFFFAFAF7);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceVariant = Color(0xFFF1F0EC);
  static const Color lightOnSurface = Color(0xFF1A1A1A);
  static const Color lightOnSurfaceVariant = Color(0xFF6E6E6E);
  static const Color lightOutline = Color(0xFFE3E2DD);

  // Dark theme
  static const Color darkBackground = Color(0xFF0F0F0F);
  static const Color darkSurface = Color(0xFF1A1A1A);
  static const Color darkSurfaceVariant = Color(0xFF242424);
  static const Color darkOnSurface = Color(0xFFF2F2F2);
  static const Color darkOnSurfaceVariant = Color(0xFF9C9C9C);
  static const Color darkOutline = Color(0xFF2E2E2E);

  // Semantic
  static const Color success = Color(0xFF34A853);
  static const Color warning = Color(0xFFF6AE2D);
  static const Color danger = Color(0xFFE5484D);
}