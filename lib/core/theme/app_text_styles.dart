import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Compact typography scale inspired by the iOS Human Interface Guidelines.
class AppTextStyles {
  const AppTextStyles._();

  static const display = TextStyle(
    color: AppColors.navy,
    fontSize: 32,
    height: 1.12,
    letterSpacing: 0,
    fontWeight: FontWeight.w700,
  );

  static const title = TextStyle(
    color: AppColors.navy,
    fontSize: 22,
    height: 1.18,
    letterSpacing: 0,
    fontWeight: FontWeight.w700,
  );

  static const section = TextStyle(
    color: AppColors.navy,
    fontSize: 17,
    height: 1.29,
    letterSpacing: 0,
    fontWeight: FontWeight.w600,
  );

  static const body = TextStyle(
    color: AppColors.charcoal,
    fontSize: 15,
    height: 1.40,
    letterSpacing: 0,
    fontWeight: FontWeight.w400,
  );

  static const caption = TextStyle(
    color: AppColors.muted,
    fontSize: 13,
    height: 1.30,
    letterSpacing: 0,
    fontWeight: FontWeight.w500,
  );

  static const footnote = TextStyle(
    color: AppColors.muted,
    fontSize: 11,
    height: 1.20,
    letterSpacing: 0,
    fontWeight: FontWeight.w500,
  );

  // ── Context‑aware builders ──────────────────────────────────────────────

  static TextStyle displayFor(BuildContext context) {
    return display.copyWith(color: AppColors.textPrimary(context));
  }

  static TextStyle titleFor(BuildContext context) {
    return title.copyWith(color: AppColors.textPrimary(context));
  }

  static TextStyle sectionFor(BuildContext context) {
    return section.copyWith(color: AppColors.textPrimary(context));
  }

  static TextStyle bodyFor(BuildContext context) {
    return body.copyWith(color: AppColors.textSecondary(context));
  }

  static TextStyle captionFor(BuildContext context) {
    return caption.copyWith(color: AppColors.textMuted(context));
  }

  static TextStyle footnoteFor(BuildContext context) {
    return footnote.copyWith(color: AppColors.textMuted(context));
  }
}
