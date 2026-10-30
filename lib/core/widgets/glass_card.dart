import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Frosted material surface inspired by iOS UIVisualEffectView.
class GlassCard extends StatelessWidget {
  const GlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.borderRadius = 20,
    this.opacity = .78,
    this.blurSigma = 18,
    this.gradient,
    this.onTap,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final double opacity;
  final double blurSigma;
  final Gradient? gradient;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    final isDark = AppColors.isDark(context);

    final surfaceAlpha = opacity.clamp(.35, .92).toDouble();
    return Semantics(
      container: true,
      button: onTap != null,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: .28)
                  : const Color(0xFF334155).withValues(alpha: .14),
              blurRadius: isDark ? 22 : 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: BackdropFilter.grouped(
            filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: radius,
                splashColor: AppColors.blue.withValues(alpha: .07),
                highlightColor: AppColors.blue.withValues(alpha: .035),
                child: Ink(
                  width: double.infinity,
                  padding: padding,
                  decoration: BoxDecoration(
                    color: gradient == null
                        ? AppColors.glassSurface(context, alpha: surfaceAlpha)
                        : null,
                    gradient: gradient,
                    borderRadius: radius,
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: .10)
                          : AppColors.border,
                      width: .8,
                    ),
                  ),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
