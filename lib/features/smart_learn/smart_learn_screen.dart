import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../services/audio_haptic_service.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/quiz_option_card.dart';
import '../../core/widgets/shimmer_loading.dart';
import '../../core/widgets/state_views.dart';
import '../../models/api_models.dart';
import '../../services/api_service.dart';
import '../../services/smart_learn_service.dart';
import '../focus/focus_provider.dart';
import 'package:provider/provider.dart';

class SmartLearnScreen extends StatefulWidget {
  const SmartLearnScreen({
    required this.service,
    required this.onProfileChanged,
    super.key,
  });

  final SmartLearnService service;
  final ValueChanged<UserModel> onProfileChanged;

  @override
  State<SmartLearnScreen> createState() => _SmartLearnScreenState();
}

class _SmartLearnScreenState extends State<SmartLearnScreen> {
  final _typingController = TextEditingController();
  final _tts = FlutterTts();
  SmartLearnStateModel? _state;
  SmartLearnStateModel? _pendingState;
  SmartLearnQuestionModel? _displayedQuestion;
  SmartLearnFeedbackModel? _feedback;
  DateTime _questionStartedAt = DateTime.now();
  String? _selectedAnswer;
  String? _error;
  bool _loading = true;
  bool _submitting = false;
  bool _showHint = false;

  @override
  void initState() {
    super.initState();
    _configureTts();
    _start();
  }

  @override
  void dispose() {
    _typingController.dispose();
    _tts.stop();
    super.dispose();
  }

  Future<void> _configureTts() async {
    try {
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(.44);
      await _tts.setPitch(1.0);
    } on Object {
      // TTS is optional on browsers without a compatible speech engine.
    }
  }

  Future<void> _start() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final state = await widget.service.start();
      if (!mounted) return;
      _applyState(state);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyState(SmartLearnStateModel state) {
    setState(() {
      _state = state;
      _displayedQuestion = state.question;
      _pendingState = null;
      _feedback = null;
      _selectedAnswer = null;
      _typingController.clear();
      _showHint = false;
      _error = null;
      _questionStartedAt = DateTime.now();
    });
    if (state.profile != null) widget.onProfileChanged(state.profile!);
  }

  Future<void> _submit(String answer) async {
    final state = _state;
    final question = _displayedQuestion;
    final clean = answer.trim();
    if (state == null || question == null || clean.isEmpty || _submitting) {
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _submitting = true;
      _selectedAnswer = clean;
      _error = null;
    });
    try {
      final elapsed = DateTime.now()
          .difference(_questionStartedAt)
          .inMilliseconds;
      final result = await widget.service.answer(
        sessionId: state.session.id,
        itemId: question.itemId,
        answer: clean,
        answerMs: elapsed,
      );
      if (!mounted) return;
      if (result.profile != null) widget.onProfileChanged(result.profile!);
      if (result.feedback?.isCorrect == true) {
        AudioHapticService.instance.playSuccess();
        context.read<FocusProvider>().incrementWordsLearned(1);
      } else if (result.feedback != null) {
        AudioHapticService.instance.playFail();
      }
      setState(() {
        _pendingState = result;
        _feedback = result.feedback;
        _state = SmartLearnStateModel(
          session: result.session,
          question: question,
          feedback: result.feedback,
          profile: result.profile,
          offline: result.offline,
        );
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _continue() {
    final pending = _pendingState;
    if (pending == null) return;
    _applyState(pending);
  }

  Future<void> _speak() async {
    final feedback = _feedback;
    final question = _displayedQuestion;
    final text =
        feedback?.correctAnswer ??
        (question?.direction == 'eng_to_uz' ? question?.prompt : null);
    if (text == null || text.trim().isEmpty) return;
    try {
      await _tts.stop();
      await _tts.speak(text);
    } on Object {
      // Keep the learning flow usable when browser speech is unavailable.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: GradientBackground(
        child: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: _loading
                ? const _SmartLearnSkeleton(key: ValueKey('loading'))
                : _error != null && _state == null
                ? _LoadError(
                    key: const ValueKey('error'),
                    message: _error!,
                    onRetry: _start,
                  )
                : _buildContent(context),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final state = _state;
    if (state == null) return const SizedBox.shrink();
    if (state.session.completed && _feedback == null) {
      return _CompletedView(
        key: const ValueKey('completed'),
        session: state.session,
        onClose: () => Navigator.of(context).pop(true),
      );
    }
    final question = _displayedQuestion;
    if (question == null) {
      return _CompletedView(
        key: const ValueKey('completed'),
        session: state.session,
        onClose: () => Navigator.of(context).pop(true),
      );
    }

    return Column(
      key: ValueKey('question-${question.itemId}'),
      children: [
        _Header(
          session: state.session,
          offline: state.offline,
          onClose: () => Navigator.of(context).pop(),
        ),
        Expanded(
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              20 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            children: [
              _QuestionCard(
                question: question,
                feedback: _feedback,
                showHint: _showHint,
                onHint: () => setState(() => _showHint = true),
                onSpeak: _speak,
              ),
              const SizedBox(height: 14),
              if (question.typing)
                _TypingAnswer(
                  controller: _typingController,
                  enabled: _feedback == null && !_submitting,
                  loading: _submitting,
                  onSubmit: () => _submit(_typingController.text),
                )
              else
                for (var i = 0; i < question.options.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: QuizOptionCard(
                      index: i,
                      label: question.options[i],
                      selected: _selectedAnswer == question.options[i],
                      correct: _optionState(question.options[i]),
                      onTap: _feedback == null && !_submitting
                          ? () => _submit(question.options[i])
                          : null,
                    ),
                  ),
              if (_submitting) ...[
                const SizedBox(height: 4),
                const LinearProgressIndicator(minHeight: 3),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                ErrorStateView(
                  message: _error!,
                  onRetry: _selectedAnswer == null
                      ? null
                      : () => _submit(_selectedAnswer!),
                ),
              ],
              if (_feedback != null) ...[
                const SizedBox(height: 14),
                _FeedbackCard(feedback: _feedback!, onSpeak: _speak),
                const SizedBox(height: 14),
                PrimaryButton(
                  label: _pendingState?.session.completed == true
                      ? context.l10n.t('smart.finish')
                      : context.l10n.t('smart.next'),
                  icon: _pendingState?.session.completed == true
                      ? Icons.celebration_rounded
                      : Icons.arrow_forward_rounded,
                  onPressed: _continue,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  bool? _optionState(String option) {
    final feedback = _feedback;
    if (feedback == null) return null;
    if (option == feedback.correctAnswer) return true;
    if (option == _selectedAnswer) return false;
    return null;
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.session,
    required this.offline,
    required this.onClose,
  });

  final SmartLearnSessionModel session;
  final bool offline;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 16, 4),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                onPressed: onClose,
                icon: const Icon(Icons.close_rounded),
              ),
              Expanded(
                child: Text(
                  context.l10n.t('smart.title'),
                  textAlign: TextAlign.center,
                  style: AppTextStyles.sectionFor(context),
                ),
              ),
              if (offline)
                Tooltip(
                  message: context.l10n.t('offline.smartActive'),
                  child: const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Icon(Icons.cloud_off_rounded, size: 19),
                  ),
                ),
              // XP removed per user request
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: session.progress,
              minHeight: 8,
              backgroundColor: AppColors.blue.withValues(alpha: .10),
              valueColor: const AlwaysStoppedAnimation(AppColors.green),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.l10n.f('smart.progress', {
                  'current': session.answeredCount,
                  'total': session.plannedCount,
                }),
                style: AppTextStyles.captionFor(context),
              ),
              Text(
                '${session.correctCount} ✓  ${session.wrongCount} ×',
                style: AppTextStyles.captionFor(context),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.question,
    required this.feedback,
    required this.showHint,
    required this.onHint,
    required this.onSpeak,
  });

  final SmartLearnQuestionModel question;
  final SmartLearnFeedbackModel? feedback;
  final bool showHint;
  final VoidCallback onHint;
  final VoidCallback onSpeak;

  @override
  Widget build(BuildContext context) {
    final retryColor = question.retry ? AppColors.gold : AppColors.purple;
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: retryColor.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  question.retry
                      ? context.l10n.t('smart.retryWord')
                      : context.l10n.t('smart.${question.sourceBucket}'),
                  style: TextStyle(
                    color: retryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const Spacer(),
              if (question.direction == 'eng_to_uz' || feedback != null)
                IconButton.filledTonal(
                  tooltip: context.l10n.t('smart.listen'),
                  onPressed: onSpeak,
                  icon: const Icon(Icons.volume_up_rounded),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            question.direction == 'eng_to_uz'
                ? context.l10n.t('smart.translateUz')
                : context.l10n.t('smart.translateEn'),
            textAlign: TextAlign.center,
            style: AppTextStyles.captionFor(context),
          ),
          const SizedBox(height: 8),
          Text(
            question.prompt,
            textAlign: TextAlign.center,
            style: AppTextStyles.displayFor(context).copyWith(fontSize: 32),
          ),
          if (question.pronunciation.isNotEmpty &&
              question.direction == 'eng_to_uz') ...[
            const SizedBox(height: 6),
            Text(
              question.pronunciation,
              textAlign: TextAlign.center,
              style: AppTextStyles.captionFor(
                context,
              ).copyWith(color: AppColors.purple),
            ),
          ],
          const SizedBox(height: 18),
          if (showHint)
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.lightbulb_rounded,
                    color: AppColors.gold,
                    size: 19,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      question.hint,
                      style: AppTextStyles.bodyFor(context),
                    ),
                  ),
                ],
              ),
            )
          else if (feedback == null)
            Align(
              child: TextButton.icon(
                onPressed: onHint,
                icon: const Icon(Icons.lightbulb_outline_rounded),
                label: Text(context.l10n.t('smart.showHint')),
              ),
            ),
        ],
      ),
    );
  }
}

class _TypingAnswer extends StatelessWidget {
  const _TypingAnswer({
    required this.controller,
    required this.enabled,
    required this.loading,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool loading;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          TextField(
            controller: controller,
            enabled: enabled,
            autofocus: true,
            textInputAction: TextInputAction.done,
            autocorrect: false,
            enableSuggestions: false,
            onSubmitted: (_) => onSubmit(),
            decoration: InputDecoration(
              hintText: context.l10n.t('smart.typeAnswer'),
              prefixIcon: const Icon(Icons.keyboard_alt_rounded),
            ),
          ),
          const SizedBox(height: 10),
          PrimaryButton(
            label: context.l10n.t('smart.check'),
            icon: Icons.check_rounded,
            loading: loading,
            onPressed: enabled ? onSubmit : null,
          ),
        ],
      ),
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({required this.feedback, required this.onSpeak});

  final SmartLearnFeedbackModel feedback;
  final VoidCallback onSpeak;

  @override
  Widget build(BuildContext context) {
    final color = feedback.isCorrect ? AppColors.green : AppColors.softRed;
    return GlassCard(
      opacity: .52,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                feedback.isCorrect
                    ? Icons.check_circle_rounded
                    : Icons.cancel_rounded,
                color: color,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  feedback.isCorrect
                      ? context.l10n.t('smart.correct')
                      : context.l10n.t('smart.wrong'),
                  style: AppTextStyles.sectionFor(
                    context,
                  ).copyWith(color: color, fontSize: 17),
                ),
              ),
              IconButton(
                tooltip: context.l10n.t('smart.listen'),
                onPressed: onSpeak,
                icon: const Icon(Icons.volume_up_rounded),
              ),
            ],
          ),
          if (!feedback.isCorrect) ...[
            const SizedBox(height: 8),
            Text(
              context.l10n.f('smart.correctAnswer', {
                'answer': feedback.correctAnswer,
              }),
              style: AppTextStyles.bodyFor(
                context,
              ).copyWith(fontWeight: FontWeight.w900),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            feedback.isCorrect
                ? feedback.code == 'correct_slow'
                      ? context.l10n.t('smart.correctSlowDescription')
                      : context.l10n.t('smart.correctDescription')
                : context.l10n.t('smart.wrongDescription'),
            style: AppTextStyles.bodyFor(context),
          ),
          if (feedback.exampleSentence.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.blue.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                feedback.exampleSentence,
                style: AppTextStyles.bodyFor(
                  context,
                ).copyWith(fontStyle: FontStyle.italic),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CompletedView extends StatelessWidget {
  const _CompletedView({
    required this.session,
    required this.onClose,
    super.key,
  });

  final SmartLearnSessionModel session;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final total = session.correctCount + session.wrongCount;
    final accuracy = total == 0
        ? 0
        : (session.correctCount / total * 100).round();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 44, 20, 24),
      children: [
        Icon(Icons.auto_awesome_rounded, color: AppColors.gold, size: 72),
        const SizedBox(height: 18),
        Text(
          context.l10n.t('smart.completed'),
          textAlign: TextAlign.center,
          style: AppTextStyles.displayFor(context),
        ),
        const SizedBox(height: 8),
        Text(
          context.l10n.t('smart.completedSubtitle'),
          textAlign: TextAlign.center,
          style: AppTextStyles.captionFor(context),
        ),
        const SizedBox(height: 24),
        GlassCard(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // XP result metric removed
              _ResultMetric(label: '%', value: '$accuracy'),
              _ResultMetric(
                label: context.l10n.t('smart.answers'),
                value: '${session.answeredCount}',
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        PrimaryButton(
          label: context.l10n.t('smart.backHome'),
          icon: Icons.home_rounded,
          onPressed: onClose,
        ),
      ],
    );
  }
}

class _ResultMetric extends StatelessWidget {
  const _ResultMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: AppTextStyles.titleFor(context)),
        Text(label, style: AppTextStyles.captionFor(context)),
      ],
    );
  }
}

class _SmartLearnSkeleton extends StatelessWidget {
  const _SmartLearnSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: const [
        Row(
          children: [
            ShimmerBox(width: 42, height: 42, borderRadius: 18),
            SizedBox(width: 12),
            Expanded(child: ShimmerBox(width: double.infinity, height: 16)),
          ],
        ),
        SizedBox(height: 24),
        ShimmerBox(width: double.infinity, height: 260, borderRadius: 24),
        SizedBox(height: 14),
        ShimmerBox(width: double.infinity, height: 60, borderRadius: 22),
        SizedBox(height: 10),
        ShimmerBox(width: double.infinity, height: 60, borderRadius: 22),
        SizedBox(height: 10),
        ShimmerBox(width: double.infinity, height: 60, borderRadius: 22),
      ],
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry, super.key});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 80, 20, 20),
      children: [ErrorStateView(message: message, onRetry: onRetry)],
    );
  }
}
