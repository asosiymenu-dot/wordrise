import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/primary_button.dart';
import '../../models/api_models.dart';

class ResultScreen extends StatelessWidget {
  const ResultScreen({required this.result, super.key});

  final QuizResultModel result;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final total = result.correctCount + result.wrongCount;
    final accuracy = total == 0
        ? 0
        : (result.correctCount / total * 100).round();

    return Scaffold(
      body: GradientBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 40, 20, 30),
          children: [
            GlassCard(
              gradient: const LinearGradient(
                colors: [AppColors.green, AppColors.blue],
              ),
              padding: const EdgeInsets.all(28),
              child: Column(
                children: [
                  const Icon(
                    Icons.workspace_premium_rounded,
                    color: Colors.white,
                    size: 58,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Jami: $total',
                    style: AppTextStyles.display.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.f('result.accuracy', {'accuracy': accuracy}),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _ResultStat(
                    label: l10n.t('result.correct'),
                    value: '${result.correctCount}',
                    color: AppColors.green,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ResultStat(
                    label: l10n.t('result.wrong'),
                    value: '${result.wrongCount}',
                    color: AppColors.softRed,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ResultStat(
                    label: l10n.t('result.streak'),
                    value: '${result.maxCorrectStreak}',
                    color: AppColors.gold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              label: l10n.t('result.backQuiz'),
              icon: Icons.arrow_back_rounded,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultStat extends StatelessWidget {
  const _ResultStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Text(
            value,
            style: AppTextStyles.titleFor(context).copyWith(color: color),
          ),
          Text(label, style: AppTextStyles.captionFor(context)),
        ],
      ),
    );
  }
}
