import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/state_views.dart';
import '../../models/api_models.dart';
import '../../services/ai_service.dart';
import '../../services/api_service.dart';
import '../../services/grammar_service.dart';

class GrammarAdminReviewScreen extends StatefulWidget {
  const GrammarAdminReviewScreen({
    required this.aiService,
    required this.grammarService,
    super.key,
  });

  final AiService aiService;
  final GrammarService grammarService;

  @override
  State<GrammarAdminReviewScreen> createState() =>
      _GrammarAdminReviewScreenState();
}

class _GrammarAdminReviewScreenState extends State<GrammarAdminReviewScreen> {
  final _topic = TextEditingController(text: 'Present Perfect');
  String _level = 'B1';
  bool _loading = false;
  bool _saving = false;
  String? _error;
  AiGeneratedGrammarLesson? _generated;

  @override
  void dispose() {
    _topic.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final topic = _topic.text.trim();
    if (topic.isEmpty || _loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final generated = await widget.aiService.generateGrammarLesson(
        levelCode: _level,
        topic: topic,
      );
      if (mounted) setState(() => _generated = generated);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final generated = _generated;
    if (generated == null || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.grammarService.saveGenerated(generated);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Grammatika darsi saqlandi.')),
      );
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                    'AI Grammar Review',
                    style: AppTextStyles.titleFor(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            GlassCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _level,
                    decoration: const InputDecoration(labelText: 'Daraja'),
                    items: const ['A1', 'A2', 'B1', 'B2', 'C1', 'C2']
                        .map(
                          (level) => DropdownMenuItem(
                            value: level,
                            child: Text(level),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _level = value ?? _level),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _topic,
                    decoration: const InputDecoration(
                      labelText: 'Mavzu',
                      hintText: 'Masalan: Passive voice',
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _loading ? null : _generate,
                      icon: _loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.auto_awesome_rounded),
                      label: const Text('AI bilan generatsiya qilish'),
                    ),
                  ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              ErrorStateView(message: _error!),
            ],
            if (generated != null) ...[
              const SizedBox(height: 16),
              _GeneratedPreview(generated: generated),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.verified_rounded),
                  label: const Text('Ko‘rib chiqdim, bazaga saqlash'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GeneratedPreview extends StatelessWidget {
  const _GeneratedPreview({required this.generated});

  final AiGeneratedGrammarLesson generated;

  @override
  Widget build(BuildContext context) {
    final lesson = generated.lesson;
    final examples = lesson['examples'] is List
        ? lesson['examples'] as List
        : [];
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${generated.level} • ${generated.topic}',
            style: AppTextStyles.captionFor(
              context,
            ).copyWith(color: AppColors.purple, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            lesson['title']?.toString() ?? generated.topic,
            style: AppTextStyles.titleFor(context),
          ),
          const SizedBox(height: 10),
          Text(
            lesson['explanation_uz']?.toString() ?? '',
            style: AppTextStyles.bodyFor(context),
          ),
          if (examples.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text('Misollar', style: AppTextStyles.sectionFor(context)),
            const SizedBox(height: 8),
            for (final example in examples.take(5))
              Text(
                '• ${example.toString()}',
                style: AppTextStyles.captionFor(context),
              ),
          ],
          const SizedBox(height: 14),
          Text(
            '${generated.exercises.length} ta mashq',
            style: AppTextStyles.sectionFor(context),
          ),
          const SizedBox(height: 8),
          for (final exercise in generated.exercises.take(10)) ...[
            Text(
              '• ${exercise['question'] ?? ''}',
              style: AppTextStyles.captionFor(context),
            ),
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }
}
