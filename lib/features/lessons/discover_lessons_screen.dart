import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/error_message.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/shimmer_loading.dart';
import '../../core/widgets/state_views.dart';
import '../../core/widgets/user_avatar.dart';
import '../../models/api_models.dart';
import '../../services/lesson_service.dart';

class DiscoverLessonsScreen extends StatefulWidget {
  const DiscoverLessonsScreen({required this.lessonService, super.key});

  final LessonService lessonService;

  @override
  State<DiscoverLessonsScreen> createState() => _DiscoverLessonsScreenState();
}

class _DiscoverLessonsScreenState extends State<DiscoverLessonsScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  String _sort = 'popular';
  late Future<DiscoverLessonsPage> _future;
  final Set<String> _importing = {};
  final Set<String> _imported = {};

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<DiscoverLessonsPage> _load() {
    return widget.lessonService.discover(
      query: _search.text.trim(),
      sort: _sort,
    );
  }

  void _reload() {
    final future = _load();
    setState(() {
      _future = future;
    });
  }

  void _onSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 380), _reload);
  }

  Future<void> _importLesson(PublicLessonModel lesson) async {
    if (_importing.contains(lesson.shareCode) ||
        _imported.contains(lesson.shareCode)) {
      return;
    }
    setState(() => _importing.add(lesson.shareCode));
    try {
      await widget.lessonService.importLessonByCode(lesson.shareCode);
      if (!mounted) return;
      setState(() => _imported.add(lesson.shareCode));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.t('discover.imported'))),
      );
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userFacingError(context, error))));
    } finally {
      if (mounted) setState(() => _importing.remove(lesson.shareCode));
    }
  }

  Future<void> _openDetail(PublicLessonModel lesson) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DiscoverLessonDetailScreen(
          lessonService: widget.lessonService,
          shareCode: lesson.shareCode,
          imported: _imported.contains(lesson.shareCode),
          onImport: _importLesson,
        ),
      ),
    );
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return GradientBackground(
      child: FutureBuilder<DiscoverLessonsPage>(
        future: _future,
        builder: (context, snapshot) {
          final lessons = snapshot.data?.lessons ?? [];
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
            children: [
              Text(
                l10n.t('discover.title'),
                style: AppTextStyles.displayFor(context),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.t('discover.subtitle'),
                style: AppTextStyles.captionFor(context),
              ),
              const SizedBox(height: 14),
              AppTextField(
                controller: _search,
                label: l10n.t('discover.search'),
                icon: Icons.search_rounded,
                onChanged: _onSearch,
              ),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                selected: {_sort},
                onSelectionChanged: (value) {
                  setState(() => _sort = value.first);
                  _reload();
                },
                segments: [
                  ButtonSegment(
                    value: 'popular',
                    label: Text(l10n.t('discover.popular')),
                    icon: const Icon(Icons.trending_up_rounded),
                  ),
                  ButtonSegment(
                    value: 'newest',
                    label: Text(l10n.t('discover.newest')),
                    icon: const Icon(Icons.fiber_new_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (snapshot.connectionState != ConnectionState.done)
                const ShimmerLoadingList(itemCount: 5)
              else if (snapshot.hasError)
                ErrorStateView(message: snapshot.error!, onRetry: _reload)
              else if (lessons.isEmpty)
                EmptyStateView(
                  icon: Icons.travel_explore_rounded,
                  message: l10n.t('discover.empty'),
                )
              else
                for (final lesson in lessons) ...[
                  _DiscoverLessonCard(
                    lesson: lesson,
                    importing: _importing.contains(lesson.shareCode),
                    imported: _imported.contains(lesson.shareCode),
                    onTap: () => _openDetail(lesson),
                    onImport: () => _importLesson(lesson),
                  ),
                  const SizedBox(height: 12),
                ],
            ],
          );
        },
      ),
    );
  }
}

class DiscoverLessonDetailScreen extends StatefulWidget {
  const DiscoverLessonDetailScreen({
    required this.lessonService,
    required this.shareCode,
    required this.onImport,
    required this.imported,
    super.key,
  });

  final LessonService lessonService;
  final String shareCode;
  final Future<void> Function(PublicLessonModel lesson) onImport;
  final bool imported;

  @override
  State<DiscoverLessonDetailScreen> createState() =>
      _DiscoverLessonDetailScreenState();
}

class _DiscoverLessonDetailScreenState
    extends State<DiscoverLessonDetailScreen> {
  late Future<PublicLessonModel> _future;
  bool _importing = false;
  bool _imported = false;

  @override
  void initState() {
    super.initState();
    _imported = widget.imported;
    _future = widget.lessonService.fetchLessonByCode(
      widget.shareCode,
      includeWords: true,
    );
  }

  Future<void> _import(PublicLessonModel lesson) async {
    if (_importing || _imported) return;
    setState(() => _importing = true);
    await widget.onImport(lesson);
    if (!mounted) return;
    setState(() {
      _imported = true;
      _importing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      body: GradientBackground(
        child: FutureBuilder<PublicLessonModel>(
          future: _future,
          builder: (context, snapshot) {
            final lesson = snapshot.data;
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 34),
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        l10n.t('discover.preview'),
                        style: AppTextStyles.titleFor(context),
                      ),
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
                  _DiscoverLessonHero(lesson: lesson),
                  const SizedBox(height: 16),
                  PrimaryButton(
                    label: _imported
                        ? l10n.t('discover.added')
                        : l10n.t('discover.import'),
                    icon: _imported
                        ? Icons.check_rounded
                        : Icons.download_rounded,
                    loading: _importing,
                    onPressed: _imported ? null : () => _import(lesson),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    l10n.t('discover.wordsPreview'),
                    style: AppTextStyles.sectionFor(context),
                  ),
                  const SizedBox(height: 10),
                  for (final word in lesson.words.take(30)) ...[
                    _PreviewWordRow(word: word),
                    const SizedBox(height: 8),
                  ],
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DiscoverLessonCard extends StatelessWidget {
  const _DiscoverLessonCard({
    required this.lesson,
    required this.importing,
    required this.imported,
    required this.onTap,
    required this.onImport,
  });

  final PublicLessonModel lesson;
  final bool importing;
  final bool imported;
  final VoidCallback onTap;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              _CategoryIcon(category: lesson.category),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lesson.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.sectionFor(
                        context,
                      ).copyWith(fontSize: 16),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${lesson.authorName} • ${lesson.wordCount} ${l10n.t('words.short')}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.captionFor(context),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      l10n.f('discover.importCount', {
                        'count': lesson.importCount,
                      }),
                      style: AppTextStyles.captionFor(
                        context,
                      ).copyWith(color: AppColors.green),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.tonalIcon(
                onPressed: imported || importing ? null : onImport,
                icon: importing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(imported ? Icons.check_rounded : Icons.download),
                label: Text(
                  imported
                      ? l10n.t('discover.added')
                      : l10n.t('discover.import'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiscoverLessonHero extends StatelessWidget {
  const _DiscoverLessonHero({required this.lesson});

  final PublicLessonModel lesson;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _CategoryIcon(category: lesson.category, size: 64),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lesson.title,
                        style: AppTextStyles.titleFor(context),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${lesson.category} • ${lesson.wordCount} ${l10n.t('words.short')}',
                        style: AppTextStyles.captionFor(context),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (lesson.description.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(lesson.description, style: AppTextStyles.bodyFor(context)),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                UserAvatar(
                  name: lesson.authorName,
                  avatarUrl: lesson.authorAvatar,
                  size: 38,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    lesson.authorName,
                    style: AppTextStyles.sectionFor(
                      context,
                    ).copyWith(fontSize: 15),
                  ),
                ),
                Text(
                  l10n.f('discover.importCount', {'count': lesson.importCount}),
                  style: AppTextStyles.captionFor(
                    context,
                  ).copyWith(color: AppColors.green),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewWordRow extends StatelessWidget {
  const _PreviewWordRow({required this.word});

  final WordModel word;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                word.englishWord,
                style: AppTextStyles.bodyFor(context),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              word.uzbekTranslation,
              style: AppTextStyles.bodyFor(
                context,
              ).copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryIcon extends StatelessWidget {
  const _CategoryIcon({required this.category, this.size = 54});

  final String category;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = _categoryColor(category);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: .13),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Icon(Icons.menu_book_rounded, color: color),
    );
  }
}

Color _categoryColor(String value) {
  final hash = value.codeUnits.fold<int>(0, (sum, item) => sum + item);
  return [
    AppColors.blue,
    AppColors.green,
    AppColors.gold,
    AppColors.purple,
  ][hash % 4];
}
