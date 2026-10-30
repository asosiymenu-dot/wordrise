import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/primary_button.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({required this.onStart, super.key});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = AppColors.isDark(context);

    return Scaffold(
      body: GradientBackground(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            children: [
              const Spacer(),
              GlassCard(
                padding: const EdgeInsets.all(28),
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                      : const [Color(0xEEFFFFFF), Color(0xCCEEF2FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.school_rounded,
                      color: AppColors.blue,
                      size: 62,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      l10n.t('onboarding.title'),
                      textAlign: TextAlign.center,
                      style: AppTextStyles.displayFor(context),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.t('onboarding.body'),
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyFor(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _OnboardingFeature(
                icon: Icons.style_rounded,
                label: l10n.t('onboarding.flashcard'),
              ),
              _OnboardingFeature(
                icon: Icons.bolt_rounded,
                label: l10n.t('onboarding.speedQuiz'),
              ),
              _OnboardingFeature(
                icon: Icons.emoji_events_rounded,
                label: l10n.t('onboarding.leaderboard'),
              ),
              const Spacer(),
              PrimaryButton(
                label: l10n.t('onboarding.start'),
                icon: Icons.arrow_forward_rounded,
                onPressed: onStart,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingFeature extends StatelessWidget {
  const _OnboardingFeature({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: AppColors.purple),
            const SizedBox(width: 12),
            Text(
              label,
              style: AppTextStyles.sectionFor(context).copyWith(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
