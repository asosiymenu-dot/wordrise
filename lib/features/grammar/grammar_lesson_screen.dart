import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/shimmer_loading.dart';
import '../../core/widgets/state_views.dart';
import '../../models/api_models.dart';
import '../../services/grammar_service.dart';
import 'grammar_exercise_screen.dart';

class GrammarLessonScreen extends StatefulWidget {
  const GrammarLessonScreen({
    required this.service,
    required this.lessonId,
    this.topicId,
    this.onProfileChanged,
    super.key,
  });

  final GrammarService service;
  final int lessonId;
  final int? topicId;
  final ValueChanged<UserModel>? onProfileChanged;

  @override
  State<GrammarLessonScreen> createState() => _GrammarLessonScreenState();
}

class _GrammarLessonScreenState extends State<GrammarLessonScreen> {
  late Future<GrammarDetailModel> _future;
  final Map<int, String> _answers = {};

  @override
  void initState() {
    super.initState();
    _future = widget.topicId != null && widget.topicId! > 0
        ? widget.service.detailByTopic(widget.topicId!)
        : widget.service.detail(widget.lessonId);
  }

  Future<void> _startExercises(GrammarDetailModel detail) async {
    final result = await Navigator.of(context).push<UserModel>(
      MaterialPageRoute(
        builder: (_) =>
            GrammarExerciseScreen(service: widget.service, detail: detail),
      ),
    );
    if (result != null) widget.onProfileChanged?.call(result);
    setState(() {
      _answers.clear();
      _future = detail.lesson.topicId > 0
          ? widget.service.detailByTopic(detail.lesson.topicId)
          : widget.service.detail(detail.lesson.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      body: GradientBackground(
        child: FutureBuilder<GrammarDetailModel>(
          future: _future,
          builder: (context, snapshot) {
            final detail = snapshot.data;
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
                        detail?.lesson.title ?? l10n.t('grammar.title'),
                        style: AppTextStyles.titleFor(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (snapshot.connectionState != ConnectionState.done)
                  const ShimmerLoadingList(itemCount: 4)
                else if (snapshot.hasError)
                  ErrorStateView(message: snapshot.error!)
                else if (detail == null)
                  EmptyStateView(
                    icon: Icons.school_outlined,
                    message: l10n.t('grammar.empty'),
                  )
                else ...[
                  Card(
                    elevation: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            detail.lesson.level,
                            style: AppTextStyles.captionFor(
                              context,
                            ).copyWith(color: AppColors.blue),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            detail.lesson.content,
                            style: AppTextStyles.bodyFor(context),
                          ),
                          if (detail.lesson.examples.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Text(
                              'Misollar',
                              style: AppTextStyles.sectionFor(
                                context,
                              ).copyWith(fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            for (final example in detail.lesson.examples) ...[
                              _ExampleCard(example: example),
                              const SizedBox(height: 8),
                            ],
                          ],
                          if (detail.lesson.commonMistakes.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.gold.withValues(alpha: .14),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: AppColors.gold.withValues(alpha: .30),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.warning_amber_rounded,
                                        color: AppColors.gold,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Keng tarqalgan xato',
                                        style: AppTextStyles.sectionFor(
                                          context,
                                        ).copyWith(fontSize: 16),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    detail.lesson.commonMistakes,
                                    style: AppTextStyles.captionFor(context),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed:
                          detail.exercises.isEmpty || detail.lesson.topicId <= 0
                          ? null
                          : () => _startExercises(detail),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: Text('Mashqlarni boshlash'),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    l10n.t('grammar.exercises'),
                    style: AppTextStyles.sectionFor(context),
                  ),
                  const SizedBox(height: 10),
                  for (final exercise in detail.exercises) ...[
                    _ExerciseCard(
                      exercise: exercise,
                      selected: _answers[exercise.id],
                      onSelected: (answer) =>
                          setState(() => _answers[exercise.id] = answer),
                    ),
                    const SizedBox(height: 12),
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

class _ExampleCard extends StatelessWidget {
  const _ExampleCard({required this.example});

  final GrammarExampleModel example;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.blue.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(example.en, style: AppTextStyles.bodyFor(context)),
          if (example.uz.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(example.uz, style: AppTextStyles.captionFor(context)),
          ],
        ],
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({
    required this.exercise,
    required this.selected,
    required this.onSelected,
  });

  final GrammarExerciseModel exercise;
  final String? selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final answered = selected != null;
    final correct = selected == exercise.correctAnswer;
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(exercise.question, style: AppTextStyles.sectionFor(context)),
            const SizedBox(height: 12),
            for (final option in exercise.options) ...[
              _GrammarOptionTile(
                option: option,
                selected: selected == option,
                disabled: answered,
                onTap: () => onSelected(option),
              ),
              const SizedBox(height: 8),
            ],
            if (answered) ...[
              const Divider(),
              Row(
                children: [
                  Icon(
                    correct ? Icons.check_circle_rounded : Icons.info_rounded,
                    color: correct ? AppColors.green : AppColors.softRed,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      correct
                          ? context.l10n.t('common.correct')
                          : '${context.l10n.t('common.wrong')}: ${exercise.correctAnswer}',
                      style: AppTextStyles.bodyFor(context).copyWith(
                        color: correct ? AppColors.green : AppColors.softRed,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              if (exercise.explanation.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  exercise.explanation,
                  style: AppTextStyles.captionFor(context),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _GrammarOptionTile extends StatelessWidget {
  const _GrammarOptionTile({
    required this.option,
    required this.selected,
    required this.disabled,
    required this.onTap,
  });

  final String option;
  final bool selected;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: disabled ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.blue.withValues(alpha: 0.10)
              : Colors.white.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? AppColors.blue.withValues(alpha: 0.45)
                : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: selected ? AppColors.blue : AppColors.muted,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(option, style: AppTextStyles.bodyFor(context)),
            ),
          ],
        ),
      ),
    );
  }
}
