import 'package:flutter/material.dart';

/// Calm iOS-inspired color system used across WordRise.
class AppColors {
  const AppColors._();

  // Core neutrals.
  static const navy = Color(0xFF111827);
  static const charcoal = Color(0xFF475569);
  static const muted = Color(0xFF64748B);
  static const softMuted = Color(0xFF94A3B8);

  // Functional accents.
  static const blue = Color(0xFF0A7AFF);
  static const purple = Color(0xFF7657D9);
  static const green = Color(0xFF22A861);
  static const gold = Color(0xFFFF9F0A);
  static const softRed = Color(0xFFE94B4B);
  static const teal = Color(0xFF1BA8B8);
  static const indigo = Color(0xFF4F67D8);
  static const pink = Color(0xFFE84C88);

  // Light canvas. Clean, modern, high-end slate.
  static const bgStart = Color(0xFFF8FAFC);
  static const bgMiddle = Color(0xFFF1F5F9);
  static const bgEnd = Color(0xFFE2E8F0);
  static const lightSurfaceMuted = Color(0xFFF1F5F9);

  // Dark canvas uses neutral ink instead of a blue-tinted slate theme.
  static const darkBgStart = Color(0xFF131924);
  static const darkBgMiddle = Color(0xFF131924);
  static const darkBgEnd = Color(0xFF131924);
  static const darkSurface = Color(0xFF1E2633);
  static const darkElevated = Color(0xFF222B38);
  static const darkText = Color(0xFFF7F8FA);
  static const darkMuted = Color(0xFF94A3B8);

  // Glass and separators.
  static const glass = Color(0xD9FFFFFF);
  static const glassStrong = Color(0xFFFFFFFF);
  static const border = Color(0xFFCBD5E1); // Slightly darker for visible border in light mode

  // ── Context helpers ─────────────────────────────────────────────────────

  static bool isDark(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  static Color textPrimary(BuildContext context) {
    return isDark(context) ? darkText : Colors.black;
  }

  static Color textSecondary(BuildContext context) {
    return isDark(context) ? darkMuted : Colors.black87;
  }

  static Color textMuted(BuildContext context) {
    return isDark(context) ? darkMuted.withValues(alpha: .78) : muted;
  }

  static Color surface(BuildContext context) {
    return isDark(context) ? darkSurface : Colors.white;
  }

  static Color surfaceMuted(BuildContext context) {
    return isDark(context) ? darkElevated : lightSurfaceMuted;
  }

  static Color glassSurface(BuildContext context, {double alpha = .78}) {
    return isDark(context)
        ? darkSurface.withValues(alpha: alpha.clamp(.35, .88).toDouble())
        : Colors.white.withValues(alpha: alpha.clamp(.45, .94).toDouble());
  }

  static Color elevated(BuildContext context) {
    return isDark(context) ? darkElevated : Colors.white;
  }

  static Color divider(BuildContext context) {
    return isDark(context)
        ? Colors.white.withValues(alpha: .08)
        : const Color(0xFFE5E5EA);
  }

  static Color separator(BuildContext context) {
    return isDark(context)
        ? Colors.white.withValues(alpha: .12)
        : const Color(0xFFC6C6C8);
  }
}
