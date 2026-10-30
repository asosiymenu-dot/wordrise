import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/shimmer_loading.dart';
import '../../core/widgets/state_views.dart';
import '../../models/api_models.dart';
import '../../services/ai_service.dart';
import '../../services/api_service.dart';
import '../../services/lesson_service.dart';
import '../../services/word_service.dart';

class AiLessonScreen extends StatefulWidget {
  const AiLessonScreen({
    required this.aiService,
    required this.lessonService,
    required this.wordService,
    super.key,
  });

  final AiService aiService;
  final LessonService lessonService;
  final WordService wordService;

  @override
  State<AiLessonScreen> createState() => _AiLessonScreenState();
}

class _AiLessonScreenState extends State<AiLessonScreen> {
  final _topic = TextEditingController();
  AiGeneratedLesson? _generated;
  final Set<int> _selected = {};
  bool _generating = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _topic.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final topic = _topic.text.trim();
    if (topic.isEmpty || _generating) return;
    setState(() {
      _generating = true;
      _error = null;
      _generated = null;
      _selected.clear();
    });
    try {
      final generated = await widget.aiService.generateLesson(topic);
      if (!mounted) return;
      setState(() {
        _generated = generated;
        _selected.addAll(
          List<int>.generate(generated.words.length, (index) => index),
        );
      });
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _save() async {
    final generated = _generated;
    if (generated == null || _selected.isEmpty || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final lessonData = generated.lesson;
      final lesson = await widget.lessonService.create(
        title: lessonData['title']?.toString() ?? _topic.text.trim(),
        description: lessonData['description']?.toString() ?? '',
        category: lessonData['category']?.toString() ?? 'AI',
      );
      final words = _selected
          .map((index) => generated.words[index].toWordJson())
          .toList();
      await widget.wordService.bulkCreate(lessonId: lesson.id, words: words);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final generated = _generated;
    return Scaffold(
      body: GradientBackground(
        child: ListView(
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
                    l10n.t('ai.lessonTitle'),
                    style: AppTextStyles.titleFor(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _topic,
              label: l10n.t('ai.topic'),
              icon: Icons.auto_awesome_rounded,
            ),
            const SizedBox(height: 12),
            PrimaryButton(
              label: l10n.t('ai.generate'),
              icon: Icons.auto_awesome_rounded,
              loading: _generating,
              onPressed: _generate,
            ),
            if (_generating) ...[
              const SizedBox(height: 18),
              const ShimmerLoadingList(itemCount: 5),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              ErrorStateView(message: _error!),
            ],
            if (generated != null) ...[
              const SizedBox(height: 18),
              Text(
                generated.lesson['title']?.toString() ?? _topic.text,
                style: AppTextStyles.sectionFor(context),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.t('ai.chooseWords'),
                style: AppTextStyles.captionFor(context),
              ),
              const SizedBox(height: 10),
              for (var i = 0; i < generated.words.length; i++) ...[
                _AiWordTile(
                  word: generated.words[i],
                  selected: _selected.contains(i),
                  onChanged: (selected) => setState(() {
                    if (selected) {
                      _selected.add(i);
                    } else {
                      _selected.remove(i);
                    }
                  }),
                ),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 16),
              PrimaryButton(
                label: l10n.f('ai.saveLesson', {'count': _selected.length}),
                icon: Icons.save_rounded,
                loading: _saving,
                onPressed: _save,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AiWordTile extends StatelessWidget {
  const _AiWordTile({
    required this.word,
    required this.selected,
    required this.onChanged,
  });

  final AiWordSuggestion word;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      child: CheckboxListTile(
        value: selected,
        onChanged: (value) => onChanged(value ?? false),
        controlAffinity: ListTileControlAffinity.leading,
        title: Text(word.englishWord, style: AppTextStyles.sectionFor(context)),
        subtitle: Text(
          '${word.uzbekTranslation}\n${word.exampleSentence}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.captionFor(context),
        ),
        secondary: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.blue.withValues(alpha: .10),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            word.difficultyLevel,
            style: const TextStyle(
              color: AppColors.blue,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}
