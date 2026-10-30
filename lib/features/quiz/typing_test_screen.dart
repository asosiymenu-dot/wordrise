import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/error_message.dart';
import '../../core/utils/learning_answer.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/pronunciation_button.dart';
import '../../core/widgets/shimmer_loading.dart';
import '../../core/widgets/state_views.dart';
import '../../models/api_models.dart';
import '../../services/quiz_service.dart';
import 'result_screen.dart';
import '../../services/audio_haptic_service.dart';

class TypingTestScreen extends StatefulWidget {
  const TypingTestScreen({
    required this.lesson,
    required this.quizService,
    required this.onProfileChanged,
    this.direction = 'uz_to_eng',
    this.scope = 'lesson',
    this.reviewLimit = 20,
    super.key,
  });

  final LessonModel lesson;
  final QuizService quizService;
  final ValueChanged<UserModel> onProfileChanged;
  final String direction;
  final String scope;
  final int reviewLimit;

  @override
  State<TypingTestScreen> createState() => _TypingTestScreenState();
}

class _TypingTestScreenState extends State<TypingTestScreen> {
  late Future<List<QuizQuestionModel>> _future;
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final Map<int, String> _firstAnswers = {};
  final Map<int, int> _answerTimes = {};
  final Map<int, String?> _shownTranslations = {};

  List<QuizQuestionModel> _questions = [];
  int _index = 0;
  int _attempts = 0;
  int _hintLetters = 0;
  bool _locked = false;
  bool _correct = false;
  bool _corrected = false;
  bool _submitting = false;
  Object? _error;
  DateTime _questionStartedAt = DateTime.now();

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = widget.quizService.generate(
      lessonId: widget.lesson.id,
      mode: 'typing_test',
      limit: widget.reviewLimit,
      direction: widget.direction,
      scope: widget.scope,
    );
    _future
        .then((questions) {
          if (!mounted) return;
          setState(() {
            _questions = questions;
            _error = null;
          });
          _focusInput();
        })
        .catchError((_) {});
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  QuizQuestionModel get _question => _questions[_index];

  void _focusInput() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_locked) _focusNode.requestFocus();
    });
  }

  void _recordFirstAnswer(String answer) {
    final question = _question;
    _firstAnswers.putIfAbsent(question.wordId, () => answer);
    _answerTimes.putIfAbsent(
      question.wordId,
      () => DateTime.now().difference(_questionStartedAt).inMilliseconds,
    );
    _shownTranslations[question.wordId] = question.shownTranslation;
  }

  void _checkAnswer() {
    if (_locked || _submitting) return;
    final answer = _controller.text.trim();
    if (answer.isEmpty) {
      AudioHapticService.instance.selectionClick();
      _focusNode.requestFocus();
      return;
    }

    _recordFirstAnswer(answer);
    final matches = learningAnswersMatch(answer, _question.correctAnswer);
    if (matches) {
      AudioHapticService.instance.playSuccess();
      setState(() {
        _locked = true;
        _correct = true;
        _corrected = _attempts > 0;
      });
      _focusNode.unfocus();
      return;
    }

    AudioHapticService.instance.playFail();
    if (_attempts == 0) {
      setState(() {
        _attempts = 1;
        _hintLetters = 1;
      });
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _controller.text.length,
      );
      _focusNode.requestFocus();
      return;
    }

    setState(() {
      _attempts = 2;
      _locked = true;
      _correct = false;
    });
    _focusNode.unfocus();
  }

  void _showHint() {
    if (_locked) return;
    AudioHapticService.instance.selectionClick();
    setState(() {
      _hintLetters = (_hintLetters + 1).clamp(1, 4);
    });
    _focusNode.requestFocus();
  }

  void _skip() {
    if (_locked || _submitting) return;
    _recordFirstAnswer(_controller.text.trim());
    AudioHapticService.instance.selectionClick();
    setState(() {
      _attempts = 2;
      _locked = true;
      _correct = false;
    });
    _focusNode.unfocus();
  }

  Future<void> _next() async {
    if (!_locked || _submitting) return;
    if (_index >= _questions.length - 1) {
      await _submit();
      return;
    }
    AudioHapticService.instance.selectionClick();
    setState(() {
      _index++;
      _attempts = 0;
      _hintLetters = 0;
      _locked = false;
      _correct = false;
      _corrected = false;
      _error = null;
      _controller.clear();
      _questionStartedAt = DateTime.now();
    });
    _focusInput();
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    final bool isReview = widget.scope == 'all' ||
        widget.scope == 'difficult' ||
        widget.lesson.id <= 0;

    try {
      final answers = _questions.map((question) {
        return QuizAnswerModel(
          wordId: question.wordId,
          answer: _firstAnswers[question.wordId] ?? '',
          direction: question.direction,
          shownTranslation: _shownTranslations[question.wordId],
          answerMs: _answerTimes[question.wordId],
        );
      }).toList();

      final result = isReview
          ? await widget.quizService.submitReview(
              mode: 'typing_test',
              direction: widget.direction,
              answers: answers,
            )
          : await widget.quizService.submit(
              lessonId: widget.lesson.id,
              mode: 'typing_test',
              direction: widget.direction,
              answers: answers,
            );
      if (result.profile != null) widget.onProfileChanged(result.profile!);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        CupertinoPageRoute(builder: (_) => ResultScreen(result: result)),
      );
    } on Object catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: GradientBackground(
        child: FutureBuilder<List<QuizQuestionModel>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done &&
                _questions.isEmpty) {
              return const _TypingLoading();
            }
            if (snapshot.hasError && _questions.isEmpty) {
              return _TypingStatePage(
                child: ErrorStateView(
                  message: snapshot.error!,
                  onRetry: () => setState(_load),
                ),
              );
            }
            if (_questions.isEmpty) {
              return _TypingStatePage(
                child: EmptyStateView(
                  icon: CupertinoIcons.keyboard,
                  message: context.l10n.t('quiz.empty'),
                ),
              );
            }
            return _buildQuestion(context);
          },
        ),
      ),
    );
  }

  Widget _buildQuestion(BuildContext context) {
    final l10n = context.l10n;
    final question = _question;
    final progress = (_index + 1) / _questions.length;
    final showAudio = canRevealQuizAudio(
      direction: question.direction,
      answered: _locked,
    );
    final audioText = question.direction == 'uz_to_eng'
        ? question.correctAnswer
        : question.speechText;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 4, 16, 8),
          child: Row(
            children: [
              CupertinoButton(
                padding: const EdgeInsets.all(10),
                onPressed: () => Navigator.of(context).pop(),
                child: const Icon(CupertinoIcons.back),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.t('quiz.typing'),
                      style: AppTextStyles.titleFor(context),
                    ),
                    Text(
                      l10n.f('quiz.question', {
                        'current': _index + 1,
                        'total': _questions.length,
                      }),
                      style: AppTextStyles.captionFor(context),
                    ),
                  ],
                ),
              ),
              if (showAudio && audioText.isNotEmpty)
                PronunciationButton(text: audioText, compact: true),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: AppColors.blue.withValues(alpha: .10),
              valueColor: const AlwaysStoppedAnimation(AppColors.blue),
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(
              20,
              24,
              20,
              MediaQuery.viewInsetsOf(context).bottom > 0 ? 18 : 28,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GlassCard(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    children: [
                      Text(
                        l10n.t('typing.promptLabel'),
                        style: AppTextStyles.captionFor(context),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        question.prompt,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.displayFor(
                          context,
                        ).copyWith(fontSize: 30),
                      ),
                      if (question.pronunciation.isNotEmpty && _locked) ...[
                        const SizedBox(height: 7),
                        Text(
                          question.pronunciation,
                          style: AppTextStyles.captionFor(context),
                        ),
                      ],
                      const SizedBox(height: 22),
                      CupertinoTextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        enabled: !_locked && !_submitting,
                        autofocus: true,
                        autocorrect: false,
                        enableSuggestions: false,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _checkAnswer(),
                        placeholder: l10n.t('typing.typeEnglish'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 15,
                        ),
                        style: AppTextStyles.bodyFor(
                          context,
                        ).copyWith(fontSize: 18, fontWeight: FontWeight.w700),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceMuted(context),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _attempts > 0 && !_locked
                                ? AppColors.softRed.withValues(alpha: .55)
                                : AppColors.divider(context),
                          ),
                        ),
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 240),
                        curve: Curves.easeOutCubic,
                        child: _attempts > 0 && !_locked
                            ? Padding(
                                padding: const EdgeInsets.only(top: 14),
                                child: _RetryHint(
                                  hint: buildTypingHint(
                                    question.correctAnswer,
                                    revealLetters: _hintLetters,
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 240),
                  switchInCurve: Curves.easeOutCubic,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween(
                        begin: const Offset(0, .05),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: _locked
                      ? Padding(
                          key: ValueKey('${question.wordId}-$_correct'),
                          padding: const EdgeInsets.only(top: 14),
                          child: _TypingFeedback(
                            correct: _correct,
                            corrected: _corrected,
                            answer: question.correctAnswer,
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  ErrorStateView(message: userFacingError(context, _error!)),
                ],
                const SizedBox(height: 16),
                if (_locked)
                  PrimaryButton(
                    label: _index == _questions.length - 1
                        ? l10n.t('typing.finish')
                        : l10n.t('flashcard.next'),
                    icon: _index == _questions.length - 1
                        ? CupertinoIcons.check_mark_circled_solid
                        : CupertinoIcons.arrow_right,
                    loading: _submitting,
                    onPressed: _next,
                  )
                else ...[
                  PrimaryButton(
                    label: l10n.t('typing.check'),
                    icon: CupertinoIcons.check_mark,
                    onPressed: _checkAnswer,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: CupertinoButton(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 10,
                          ),
                          onPressed: _showHint,
                          child: Text(
                            l10n.t('typing.hint'),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 18,
                        color: AppColors.divider(context),
                      ),
                      Expanded(
                        child: CupertinoButton(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 10,
                          ),
                          onPressed: _skip,
                          child: Text(
                            l10n.t('typing.skip'),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RetryHint extends StatelessWidget {
  const _RetryHint({required this.hint});

  final String hint;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          CupertinoIcons.lightbulb_fill,
          color: AppColors.gold,
          size: 19,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            context.l10n.f('typing.retryHint', {'hint': hint}),
            style: AppTextStyles.bodyFor(
              context,
            ).copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _TypingFeedback extends StatelessWidget {
  const _TypingFeedback({
    required this.correct,
    required this.corrected,
    required this.answer,
  });

  final bool correct;
  final bool corrected;
  final String answer;

  @override
  Widget build(BuildContext context) {
    final color = correct ? AppColors.green : AppColors.softRed;
    final text = corrected
        ? context.l10n.t('typing.corrected')
        : correct
        ? context.l10n.t('quiz.answerCorrect')
        : context.l10n.f('typing.correctAnswer', {'answer': answer});
    return GlassCard(
      padding: const EdgeInsets.all(15),
      opacity: .58,
      child: Row(
        children: [
          Icon(
            correct
                ? CupertinoIcons.check_mark_circled_solid
                : CupertinoIcons.info_circle_fill,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.bodyFor(
                context,
              ).copyWith(color: color, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingLoading extends StatelessWidget {
  const _TypingLoading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(20, 70, 20, 20),
      child: Column(
        children: [
          ShimmerBox(width: 210, height: 28, borderRadius: 8),
          SizedBox(height: 28),
          ShimmerBox(width: double.infinity, height: 260, borderRadius: 22),
        ],
      ),
    );
  }
}

class _TypingStatePage extends StatelessWidget {
  const _TypingStatePage({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 70, 20, 30),
      children: [child],
    );
  }
}
