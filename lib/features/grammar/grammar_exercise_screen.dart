import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/state_views.dart';
import '../../models/api_models.dart';
import '../../services/api_service.dart';
import '../../services/grammar_service.dart';

class GrammarExerciseScreen extends StatefulWidget {
  const GrammarExerciseScreen({
    required this.service,
    required this.detail,
    super.key,
  });

  final GrammarService service;
  final GrammarDetailModel detail;

  @override
  State<GrammarExerciseScreen> createState() => _GrammarExerciseScreenState();
}

class _GrammarExerciseScreenState extends State<GrammarExerciseScreen> {
  final _answer = TextEditingController();
  final Map<int, String> _answers = {};
  int _index = 0;
  bool _checked = false;
  bool _submitting = false;
  GrammarSubmitResultModel? _result;
  String? _error;

  GrammarExerciseModel get _current => widget.detail.exercises[_index];

  @override
  void dispose() {
    _answer.dispose();
    super.dispose();
  }

  void _select(String value) {
    if (_checked) return;
    setState(() {
      _answers[_current.id] = value;
      _answer.text = value;
      _checked = true;
    });
  }

  void _checkText() {
    final text = _answer.text.trim();
    if (text.isEmpty || _checked) return;
    setState(() {
      _answers[_current.id] = text;
      _checked = true;
    });
  }

  bool _isCorrect(GrammarExerciseModel exercise, String value) {
    final accepted = exercise.correctAnswers.isNotEmpty
        ? exercise.correctAnswers
        : [exercise.correctAnswer];
    final normalized = _normalize(value);
    return accepted.any((answer) => _normalize(answer) == normalized);
  }

  String _normalize(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  Future<void> _next() async {
    if (_index < widget.detail.exercises.length - 1) {
      setState(() {
        _index++;
        _checked = false;
        _answer.clear();
      });
      return;
    }
    await _submit();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final result = await widget.service.submit(
        topicId: widget.detail.lesson.topicId,
        answers: _answers,
      );
      if (!mounted) return;
      setState(() => _result = result);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final exercises = widget.detail.exercises;
    if (_result != null) {
      return Scaffold(
        body: GradientBackground(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: GlassCard(
                padding: const EdgeInsets.all(22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.workspace_premium_rounded,
                      color: AppColors.gold,
                      size: 56,
                    ),
                    const SizedBox(height: 12),
                    Text('Natija', style: AppTextStyles.titleFor(context)),
                    const SizedBox(height: 8),
                    Text(
                      '${_result!.correctCount} to‘g‘ri • ${_result!.wrongCount} xato',
                      style: AppTextStyles.bodyFor(context),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    LinearProgressIndicator(
                      value: _result!.progressPercent / 100,
                      color: AppColors.green,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    const SizedBox(height: 18),
                    FilledButton(
                      onPressed: () =>
                          Navigator.of(context).pop(_result!.profile),
                      child: const Text('Tugatish'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    final current = _current;
    final selected = _answers[current.id] ?? '';
    final correct = selected.isNotEmpty && _isCorrect(current, selected);
    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: (_index + 1) / exercises.length,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('${_index + 1}/${exercises.length}'),
                ],
              ),
              const SizedBox(height: 16),
              GlassCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _typeLabel(current.exerciseType),
                      style: AppTextStyles.captionFor(
                        context,
                      ).copyWith(color: AppColors.purple),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      current.question,
                      style: AppTextStyles.titleFor(context),
                    ),
                    const SizedBox(height: 16),
                    if (current.options.isNotEmpty)
                      for (final option in current.options) ...[
                        _AnswerOption(
                          option: option,
                          selected: selected == option,
                          checked: _checked,
                          correct:
                              _normalize(option) ==
                              _normalize(current.correctAnswer),
                          onTap: () => _select(option),
                        ),
                        const SizedBox(height: 10),
                      ]
                    else ...[
                      TextField(
                        controller: _answer,
                        enabled: !_checked,
                        minLines: 1,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: current.exerciseType == 'reorder_words'
                              ? 'So‘zlarni to‘g‘ri tartibda yozing'
                              : 'Javobni yozing',
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _checked ? null : _checkText,
                        child: const Text('Tekshirish'),
                      ),
                    ],
                    if (_checked) ...[
                      const Divider(height: 26),
                      Row(
                        children: [
                          Icon(
                            correct
                                ? Icons.check_circle_rounded
                                : Icons.cancel_rounded,
                            color: correct
                                ? AppColors.green
                                : AppColors.softRed,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              correct
                                  ? 'To‘g‘ri'
                                  : 'To‘g‘ri javob: ${current.correctAnswer}',
                              style: AppTextStyles.sectionFor(context).copyWith(
                                color: correct
                                    ? AppColors.green
                                    : AppColors.softRed,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (current.explanation.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          current.explanation,
                          style: AppTextStyles.captionFor(context),
                        ),
                      ],
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _submitting ? null : _next,
                          icon: _submitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.arrow_forward_rounded),
                          label: Text(
                            _index == exercises.length - 1
                                ? 'Natijani ko‘rish'
                                : 'Keyingi',
                          ),
                        ),
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      ErrorStateView(message: _error!),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnswerOption extends StatelessWidget {
  const _AnswerOption({
    required this.option,
    required this.selected,
    required this.checked,
    required this.correct,
    required this.onTap,
  });

  final String option;
  final bool selected;
  final bool checked;
  final bool correct;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Color border = AppColors.border;
    Color fill = Colors.white.withValues(alpha: .55);
    if (checked && correct) {
      border = AppColors.green;
      fill = AppColors.green.withValues(alpha: .12);
    } else if (checked && selected && !correct) {
      border = AppColors.softRed;
      fill = AppColors.softRed.withValues(alpha: .12);
    } else if (selected) {
      border = AppColors.blue;
      fill = AppColors.blue.withValues(alpha: .10);
    }

    return InkWell(
      onTap: checked ? null : onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(option, style: AppTextStyles.bodyFor(context)),
            ),
            if (checked && correct)
              const Icon(Icons.check_rounded, color: AppColors.green)
            else if (checked && selected && !correct)
              const Icon(Icons.close_rounded, color: AppColors.softRed),
          ],
        ),
      ),
    );
  }
}

String _typeLabel(String type) {
  return switch (type) {
    'fill_blank' => 'Bo‘sh joyni to‘ldiring',
    'reorder_words' => 'So‘zlarni tartiblang',
    'error_correction' => 'Xatoni tuzating',
    'translate' => 'Tarjima qiling',
    _ => 'Variantni tanlang',
  };
}
