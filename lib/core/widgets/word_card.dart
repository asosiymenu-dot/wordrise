import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../models/api_models.dart';
import '../localization/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'glass_card.dart';
import 'ios_selection_sheet.dart';
import 'pronunciation_button.dart';

class WordCard extends StatelessWidget {
  const WordCard({
    required this.word,
    this.onEdit,
    this.onDelete,
    this.onToggleStar,
    super.key,
  });

  final WordModel word;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final ValueChanged<bool>? onToggleStar;

  @override
  Widget build(BuildContext context) {
    final showMenu = onEdit != null || onDelete != null;

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.green.withValues(alpha: .14),
            child: const Icon(Icons.translate_rounded, color: AppColors.green),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  word.englishWord,
                  style: AppTextStyles.sectionFor(
                    context,
                  ).copyWith(fontSize: 17),
                ),
                const SizedBox(height: 2),
                Text(
                  word.uzbekTranslation,
                  style: AppTextStyles.captionFor(context),
                ),
                if (word.pronunciation.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    word.pronunciation,
                    style: AppTextStyles.captionFor(
                      context,
                    ).copyWith(color: AppColors.purple),
                  ),
                ],
              ],
            ),
          ),
          PronunciationButton(text: word.englishWord, compact: true),
          if (onToggleStar != null)
            IconButton(
              tooltip: word.isStarred
                  ? context.l10n.t('words.unstar')
                  : context.l10n.t('words.star'),
              onPressed: () => onToggleStar!(!word.isStarred),
              icon: Icon(
                word.isStarred ? Icons.star_rounded : Icons.star_border_rounded,
                color: word.isStarred
                    ? AppColors.gold
                    : AppColors.textMuted(context),
              ),
            ),
          if (showMenu) ...[
            const SizedBox(width: 8),
            CupertinoButton(
              padding: const EdgeInsets.all(10),
              onPressed: () => _showActions(context),
              child: Icon(
                CupertinoIcons.ellipsis,
                color: AppColors.textMuted(context),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showActions(BuildContext context) async {
    final action = await showIosSelectionSheet<_WordAction>(
      context: context,
      title: word.englishWord,
      selected: null,
      options: [
        if (onEdit != null)
          IosSelectionOption(
            value: _WordAction.edit,
            label: context.l10n.t('common.edit'),
            icon: CupertinoIcons.pencil,
          ),
        if (onDelete != null)
          IosSelectionOption(
            value: _WordAction.delete,
            label: context.l10n.t('common.delete'),
            icon: CupertinoIcons.delete,
            destructive: true,
          ),
      ],
    );
    switch (action) {
      case _WordAction.edit:
        onEdit?.call();
      case _WordAction.delete:
        onDelete?.call();
      case null:
        return;
    }
  }
}

enum _WordAction { edit, delete }
