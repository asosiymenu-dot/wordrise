import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class XPProgressBar extends StatelessWidget {
  const XPProgressBar({required this.xp, required this.level, super.key});

  final int xp;
  final int level;

  @override
  Widget build(BuildContext context) {
    final progress = (xp % 500) / 500;
    final next = 500 - (xp % 500);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Level $level progress',
                style: AppTextStyles.captionFor(context),
              ),
            ),
            Text(
              '$next XP left',
              style: AppTextStyles.captionFor(
                context,
              ).copyWith(color: AppColors.purple),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 10,
            backgroundColor: Colors.white.withValues(
              alpha: AppColors.isDark(context) ? .16 : .46,
            ),
            valueColor: const AlwaysStoppedAnimation(AppColors.purple),
          ),
        ),
      ],
    );
  }
}
