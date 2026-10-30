import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/shimmer_loading.dart';
import '../../core/widgets/state_views.dart';
import '../../models/api_models.dart';
import '../../services/api_service.dart';
import '../../services/lesson_service.dart';

String? extractLessonShareCode(String value) {
  final text = value.trim();
  if (text.isEmpty) return null;

  final uri = Uri.tryParse(text);
  if (uri != null) {
    if (uri.scheme == 'wordrise' &&
        uri.host == 'lesson' &&
        uri.pathSegments.isNotEmpty) {
      return uri.pathSegments.first;
    }
    final shareIndex = uri.pathSegments.indexOf('share');
    if (shareIndex >= 0 && uri.pathSegments.length > shareIndex + 1) {
      return uri.pathSegments[shareIndex + 1];
    }
  }

  final onlyCode = RegExp(r'^[a-zA-Z0-9]{6,12}$');
  if (onlyCode.hasMatch(text)) return text;
  final match = RegExp(
    r'(?:share/|lesson/)([a-zA-Z0-9]{6,12})',
  ).firstMatch(text);
  return match?.group(1);
}

Future<bool> showLessonImportPreviewSheet({
  required BuildContext context,
  required LessonService lessonService,
  required String code,
}) async {
  final cleanCode = extractLessonShareCode(code);
  if (cleanCode == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.t('share.invalidCode'))),
    );
    return false;
  }

  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return _ImportPreviewContent(
        lessonService: lessonService,
        code: cleanCode,
      );
    },
  );
  return result == true;
}

class _ImportPreviewContent extends StatefulWidget {
  const _ImportPreviewContent({
    required this.lessonService,
    required this.code,
  });

  final LessonService lessonService;
  final String code;

  @override
  State<_ImportPreviewContent> createState() => _ImportPreviewContentState();
}

class _ImportPreviewContentState extends State<_ImportPreviewContent> {
  late Future<PublicLessonModel> _future;
  bool _importing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _future = widget.lessonService.fetchLessonByCode(
      widget.code,
      includeWords: true,
    );
  }

  Future<void> _import() async {
    if (_importing) return;
    setState(() {
      _importing = true;
      _error = null;
    });
    try {
      await widget.lessonService.importLessonByCode(widget.code);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DraggableScrollableSheet(
      initialChildSize: .72,
      minChildSize: .45,
      maxChildSize: .92,
      builder: (context, controller) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          decoration: BoxDecoration(
            color: AppColors.isDark(context)
                ? AppColors.darkSurface
                : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: FutureBuilder<PublicLessonModel>(
            future: _future,
            builder: (context, snapshot) {
              final lesson = snapshot.data;
              return ListView(
                controller: controller,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.t('share.previewTitle'),
                          style: AppTextStyles.titleFor(context),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (snapshot.connectionState != ConnectionState.done)
                    const ShimmerLoadingList(itemCount: 3)
                  else if (snapshot.hasError)
                    ErrorStateView(message: snapshot.error!)
                  else if (lesson == null)
                    EmptyStateView(
                      icon: Icons.link_off_rounded,
                      message: l10n.t('share.notFound'),
                    )
                  else ...[
                    Text(lesson.title, style: AppTextStyles.titleFor(context)),
                    const SizedBox(height: 6),
                    Text(
                      '${lesson.authorName} • ${lesson.wordCount} ${l10n.t('words.short')}',
                      style: AppTextStyles.captionFor(context),
                    ),
                    if (lesson.description.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        lesson.description,
                        style: AppTextStyles.bodyFor(context),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Text(
                      l10n.t('discover.wordsPreview'),
                      style: AppTextStyles.sectionFor(context),
                    ),
                    const SizedBox(height: 10),
                    for (final word in lesson.words.take(12)) ...[
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              word.englishWord,
                              style: AppTextStyles.bodyFor(context),
                            ),
                          ),
                          Text(
                            word.uzbekTranslation,
                            style: AppTextStyles.bodyFor(
                              context,
                            ).copyWith(fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                      const Divider(height: 18),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      ErrorStateView(message: _error!),
                    ],
                    const SizedBox(height: 14),
                    PrimaryButton(
                      label: l10n.t('share.import'),
                      icon: Icons.download_rounded,
                      loading: _importing,
                      onPressed: _import,
                    ),
                  ],
                ],
              );
            },
          ),
        );
      },
    );
  }
}
