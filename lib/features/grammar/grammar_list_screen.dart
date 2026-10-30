import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/shimmer_loading.dart';
import '../../core/widgets/state_views.dart';
import '../../models/api_models.dart';
import '../../services/grammar_service.dart';
import 'grammar_lesson_screen.dart';

class GrammarListScreen extends StatefulWidget {
  const GrammarListScreen({required this.service, super.key});

  final GrammarService service;

  @override
  State<GrammarListScreen> createState() => _GrammarListScreenState();
}

class _GrammarListScreenState extends State<GrammarListScreen> {
  late Future<List<GrammarLessonModel>> _future;
  String _level = '';

  @override
  void initState() {
    super.initState();
    _future = widget.service.all();
  }

  void _load(String level) {
    setState(() {
      _level = level;
      _future = widget.service.all(level: level);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      body: GradientBackground(
        child: FutureBuilder<List<GrammarLessonModel>>(
          future: _future,
          builder: (context, snapshot) {
            final lessons = snapshot.data ?? [];
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
                        l10n.t('grammar.title'),
                        style: AppTextStyles.titleFor(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.t('grammar.subtitle'),
                  style: AppTextStyles.captionFor(context),
                ),
                const SizedBox(height: 14),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<String>(
                    selected: {_level},
                    onSelectionChanged: (value) => _load(value.first),
                    segments: const [
                      ButtonSegment(value: '', label: Text('All')),
                      ButtonSegment(value: 'A1', label: Text('A1')),
                      ButtonSegment(value: 'A2', label: Text('A2')),
                      ButtonSegment(value: 'B1', label: Text('B1')),
                      ButtonSegment(value: 'B2', label: Text('B2')),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (snapshot.connectionState != ConnectionState.done)
                  const ShimmerLoadingList(itemCount: 4)
                else if (snapshot.hasError)
                  ErrorStateView(message: snapshot.error!)
                else if (lessons.isEmpty)
                  EmptyStateView(
                    icon: Icons.school_outlined,
                    message: l10n.t('grammar.empty'),
                  )
                else
                  for (final lesson in lessons) ...[
                    _GrammarLessonCard(
                      lesson: lesson,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => GrammarLessonScreen(
                            service: widget.service,
                            lessonId: lesson.id,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _GrammarLessonCard extends StatelessWidget {
  const _GrammarLessonCard({required this.lesson, required this.onTap});

  final GrammarLessonModel lesson;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.blue.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.school_rounded, color: AppColors.blue),
        ),
        title: Text(lesson.title, style: AppTextStyles.sectionFor(context)),
        subtitle: Text(
          '${lesson.level} • ${lesson.exerciseCount} mashq',
          style: AppTextStyles.captionFor(context),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}
