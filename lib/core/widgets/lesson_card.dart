import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../models/api_models.dart';
import '../localization/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'glass_card.dart';
import 'ios_selection_sheet.dart';

class LessonCard extends StatelessWidget {
  const LessonCard({
    required this.lesson,
    required this.onTap,
    this.onEdit,
    this.onExport,
    this.onShare,
    this.onTogglePublic,
    this.onDelete,
    super.key,
  });

  final LessonModel lesson;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onExport;
  final VoidCallback? onShare;
  final VoidCallback? onTogglePublic;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final showMenu =
        onEdit != null ||
        onExport != null ||
        onShare != null ||
        onTogglePublic != null ||
        onDelete != null;

    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.blue, AppColors.purple],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.menu_book_rounded, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(lesson.title, style: AppTextStyles.sectionFor(context)),
                const SizedBox(height: 3),
                Text(
                  '${lesson.category} - ${lesson.wordCount} words',
                  style: AppTextStyles.captionFor(context),
                ),
              ],
            ),
          ),
          if (showMenu)
            CupertinoButton(
              padding: const EdgeInsets.all(10),
              onPressed: () => _showActions(context),
              child: Icon(
                CupertinoIcons.ellipsis,
                color: AppColors.textMuted(context),
              ),
            )
          else
            Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textMuted(context),
            ),
        ],
      ),
    );
  }

  Future<void> _showActions(BuildContext context) async {
    final action = await showIosSelectionSheet<_LessonAction>(
      context: context,
      title: lesson.title,
      selected: null,
      options: [
        if (onEdit != null)
          IosSelectionOption(
            value: _LessonAction.edit,
            label: context.l10n.t('common.edit'),
            icon: CupertinoIcons.pencil,
          ),
        if (onExport != null)
          IosSelectionOption(
            value: _LessonAction.export,
            label: context.l10n.t('common.export'),
            icon: CupertinoIcons.share,
          ),
        if (onShare != null)
          IosSelectionOption(
            value: _LessonAction.share,
            label: context.l10n.t('lessons.share'),
            icon: CupertinoIcons.person_2,
          ),
        if (onDelete != null)
          IosSelectionOption(
            value: _LessonAction.delete,
            label: context.l10n.t('common.delete'),
            icon: CupertinoIcons.delete,
            destructive: true,
          ),
      ],
    );
    switch (action) {
      case _LessonAction.edit:
        onEdit?.call();
      case _LessonAction.export:
        onExport?.call();
      case _LessonAction.share:
        onShare?.call();
      case _LessonAction.delete:
        onDelete?.call();
      case null:
        return;
    }
  }
}

enum _LessonAction { edit, export, share, delete }
