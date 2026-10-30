import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../models/api_models.dart';
import '../localization/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class LessonPickerResult {
  const LessonPickerResult(this.lesson);

  final LessonModel? lesson;
}

Future<LessonPickerResult?> showLessonPickerSheet({
  required BuildContext context,
  required List<LessonModel> lessons,
  LessonModel? selectedLesson,
  bool allowAllWords = false,
}) {
  final search = TextEditingController();

  return showModalBottomSheet<LessonPickerResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: AppColors.isDark(context)
        ? AppColors.darkSurface
        : const Color(0xFFF7F7FA),
    builder: (context) {
      var query = '';
      return StatefulBuilder(
        builder: (context, setModalState) {
          final filtered = lessons.where((lesson) {
            final text =
                '${lesson.title} ${lesson.category} ${lesson.description}'
                    .toLowerCase();
            return text.contains(query.toLowerCase());
          }).toList();

          return FractionallySizedBox(
            heightFactor: .88,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                18,
                2,
                18,
                MediaQuery.viewInsetsOf(context).bottom + 14,
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          context.l10n.t('quiz.chooseLesson'),
                          style: AppTextStyles.titleFor(context),
                        ),
                      ),
                      CupertinoButton(
                        padding: const EdgeInsets.all(8),
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Icon(CupertinoIcons.xmark_circle_fill),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  CupertinoSearchTextField(
                    controller: search,
                    placeholder: context.l10n.t('quiz.searchLesson'),
                    onChanged: (value) =>
                        setModalState(() => query = value.trim()),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: ListView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      children: [
                        if (allowAllWords)
                          _LessonPickerRow(
                            title: context.l10n.t('battle.allWords'),
                            subtitle: context.l10n.t('quiz.reviewAllSubtitle'),
                            selected: selectedLesson == null,
                            onTap: () => Navigator.of(
                              context,
                            ).pop(const LessonPickerResult(null)),
                          ),
                        for (final lesson in filtered)
                          _LessonPickerRow(
                            title: lesson.title,
                            subtitle: context.l10n.f('quiz.lessonWords', {
                              'category': lesson.category,
                              'count': lesson.wordCount,
                            }),
                            selected: selectedLesson?.id == lesson.id,
                            onTap: () => Navigator.of(
                              context,
                            ).pop(LessonPickerResult(lesson)),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  ).whenComplete(search.dispose);
}

class _LessonPickerRow extends StatelessWidget {
  const _LessonPickerRow({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: CupertinoButton(
        onPressed: onTap,
        pressedOpacity: .68,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        color: AppColors.glassSurface(
          context,
          alpha: AppColors.isDark(context) ? .58 : .92,
        ),
        borderRadius: BorderRadius.circular(16),
        child: Row(
          children: [
            Icon(
              selected
                  ? CupertinoIcons.check_mark_circled_solid
                  : CupertinoIcons.book,
              color: selected ? AppColors.green : AppColors.blue,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyFor(
                      context,
                    ).copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.captionFor(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
