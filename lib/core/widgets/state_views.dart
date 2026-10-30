import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/error_message.dart';
import 'glass_card.dart';
import 'shimmer_loading.dart';

class LoadingStateView extends StatelessWidget {
  const LoadingStateView({this.message, super.key});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (message != null) ...[
          GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                const ShimmerBox(width: 34, height: 34, borderRadius: 14),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message!,
                    style: AppTextStyles.captionFor(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        const ShimmerLoadingList(itemCount: 3, compact: true),
      ],
    );
  }
}

class EmptyStateView extends StatelessWidget {
  const EmptyStateView({required this.icon, required this.message, super.key});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      child: GlassCard(
        child: Column(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: AppColors.blue.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(19),
              ),
              child: Icon(icon, color: AppColors.blue, size: 28),
            ),
            const SizedBox(height: 13),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyFor(context),
            ),
          ],
        ),
      ),
    );
  }
}

class ErrorStateView extends StatelessWidget {
  const ErrorStateView({required this.message, this.onRetry, super.key});

  final Object message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final safeMessage = userFacingError(context, message);
    return Semantics(
      container: true,
      liveRegion: true,
      child: GlassCard(
        opacity: .62,
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.softRed.withValues(alpha: .11),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(
                Icons.priority_high_rounded,
                color: AppColors.softRed,
                size: 21,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(safeMessage, style: AppTextStyles.bodyFor(context)),
            ),
            if (onRetry != null)
              IconButton(
                tooltip: context.l10n.t('common.retry'),
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
              ),
          ],
        ),
      ),
    );
  }
}
