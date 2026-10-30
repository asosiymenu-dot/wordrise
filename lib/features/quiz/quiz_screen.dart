import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/learning_answer.dart';
import '../../core/widgets/quiz_option_card.dart';
import '../../core/widgets/pronunciation_button.dart';
import '../../core/widgets/state_views.dart';
import '../../models/api_models.dart';
import '../../services/api_service.dart';
import '../../services/audio_haptic_service.dart';
import '../../services/quiz_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../focus/focus_provider.dart';
import 'result_screen.dart';

class MultipleChoiceQuizScreen extends StatefulWidget {
  const MultipleChoiceQuizScreen({
    required this.lesson,
    required this.mode,
    required this.quizService,
    required this.onProfileChanged,
    this.direction = 'eng_to_uz',
    this.reviewAll = false,
    this.dueReviews = false,
    this.practiceMistakes = false,
    this.reviewLimit = 20,
    this.scope = 'lesson',
    super.key,
  });

  const MultipleChoiceQuizScreen.reviewAll({
    required this.mode,
    required this.quizService,
    required this.onProfileChanged,
    this.direction = 'eng_to_uz',
    this.reviewLimit = 20,
    super.key,
  }) : lesson = null,
       reviewAll = true,
       practiceMistakes = false,
       scope = 'all',
       dueReviews = false;

  const MultipleChoiceQuizScreen.dueReviews({
    required this.mode,
    required this.quizService,
    required this.onProfileChanged,
    this.direction = 'eng_to_uz',
    this.reviewLimit = 20,
    super.key,
  }) : lesson = null,
       reviewAll = false,
       dueReviews = true,
       scope = 'lesson',
       practiceMistakes = false;

  const MultipleChoiceQuizScreen.mistakes({
    required this.mode,
    required this.quizService,
    required this.onProfileChanged,
    this.direction = 'eng_to_uz',
    this.reviewLimit = 20,
    super.key,
  }) : lesson = null,
       reviewAll = false,
       dueReviews = false,
       scope = 'difficult',
       practiceMistakes = true;

  final LessonModel? lesson;
  final String mode;
  final String direction;
  final QuizService quizService;
  final ValueChanged<UserModel> onProfileChanged;
  final bool reviewAll;
  final bool dueReviews;
  final bool practiceMistakes;
  final int reviewLimit;
  final String scope;

  @override
  State<MultipleChoiceQuizScreen> createState() =>
      _MultipleChoiceQuizScreenState();
}

class _MultipleChoiceQuizScreenState extends State<MultipleChoiceQuizScreen> {
  static const _questionSeconds = 30;

  late Future<List<QuizQuestionModel>> _future;
  final Map<int, String> _answers = {};
  final Map<int, String?> _shownTranslations = {};
  final Map<int, int> _answerTimes = {};

  List<QuizQuestionModel> _questions = [];
  Timer? _timer;
  Timer? _advanceTimer;
  int _index = 0;
  int _remaining = _questionSeconds;
  bool _locked = false;
  bool _timedOut = false;
  bool _submitting = false;
  String? _selectedAnswer;
  String? _error;
  DateTime _questionStartedAt = DateTime.now();
  bool _fastMode = false;

  @override
  void initState() {
    super.initState();
    _loadFastMode();
    _load();
  }

  Future<void> _loadFastMode() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _fastMode = prefs.getBool('quiz_fast_mode') ?? false;
    });
  }

  Future<void> _toggleFastMode(bool value) async {
    setState(() => _fastMode = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('quiz_fast_mode', value);
  }

  void _load() {
    setState(() {
      _future = widget.practiceMistakes
          ? widget.quizService.practiceMistakes(
              mode: widget.mode,
              direction: widget.direction,
            )
          : widget.dueReviews
              ? widget.quizService
                    .dueReviews(
                      mode: widget.mode,
                      limit: widget.reviewLimit,
                      direction: widget.direction,
                    )
                    .then((bundle) => bundle.questions)
              : widget.reviewAll
                  ? widget.quizService.generateReview(
                      mode: widget.mode,
                      limit: widget.reviewLimit,
                      direction: widget.direction,
                    )
                  : widget.quizService.generate(
                      lessonId: widget.lesson?.id ?? 0,
                      mode: widget.mode,
                      limit: widget.reviewLimit,
                      direction: widget.direction,
                      scope: widget.scope,
                    );
    });
    _future
        .then((questions) {
          if (!mounted) return;
          setState(() => _questions = questions);
          if (questions.isNotEmpty) _startTimer();
        })
        .catchError((_) {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    _advanceTimer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _advanceTimer?.cancel();
    setState(() {
      _remaining = _questionSeconds;
      _locked = false;
      _timedOut = false;
      _selectedAnswer = null;
      _error = null;
      _questionStartedAt = DateTime.now();
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _locked || _submitting) return;
      if (_remaining <= 1) {
        _lockAnswer(null, timedOut: true);
      } else {
        setState(() => _remaining--);
      }
    });
  }

  void _selectAnswer(String answer) {
    if (_locked || _submitting) return;
    final correct = learningAnswersMatch(
      answer,
      _questions[_index].correctAnswer,
    );
    if (correct) {
      AudioHapticService.instance.playSuccess();
    } else {
      AudioHapticService.instance.playFail();
    }
    _lockAnswer(answer);
  }

  void _lockAnswer(String? answer, {bool timedOut = false}) {
    if (_questions.isEmpty || _locked) return;
    final question = _questions[_index];
    _timer?.cancel();

    if (timedOut) AudioHapticService.instance.playFail();

    if (answer != null) {
      _answers[question.wordId] = answer;
    }
    _shownTranslations[question.wordId] = question.shownTranslation;
    _answerTimes[question.wordId] = DateTime.now()
        .difference(_questionStartedAt)
        .inMilliseconds;

    setState(() {
      _selectedAnswer = answer;
      _timedOut = timedOut;
      _locked = true;
    });

    final correct = answer != null && learningAnswersMatch(answer, question.correctAnswer);
    final delay = (_fastMode && correct) ? 400 : 1750;

    _advanceTimer = Timer(Duration(milliseconds: delay), () {
      if (!mounted || !_locked) return;
      _advanceOrSubmit();
    });
  }

  Future<void> _advanceOrSubmit() async {
    if (_index < _questions.length - 1) {
      setState(() => _index++);
      _startTimer();
      return;
    }

    await _submit();
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });

    final answers = _questions.map((question) {
      return QuizAnswerModel(
        wordId: question.wordId,
        answer: _answers[question.wordId] ?? '',
        direction: question.direction,
        shownTranslation: _shownTranslations[question.wordId],
        answerMs: _answerTimes[question.wordId],
      );
    }).toList();

    final bool isReview = widget.reviewAll ||
        widget.dueReviews ||
        widget.practiceMistakes ||
        widget.scope == 'all' ||
        widget.scope == 'difficult' ||
        widget.lesson == null ||
        (widget.lesson != null && widget.lesson!.id <= 0);

    try {
      final result = isReview
          ? await widget.quizService.submitReview(
              mode: widget.mode,
              answers: answers,
              direction: widget.direction,
            )
          : await widget.quizService.submit(
              lessonId: widget.lesson!.id,
              mode: widget.mode,
              answers: answers,
              direction: widget.direction,
            );
      if (result.profile != null) widget.onProfileChanged(result.profile!);
      if (!mounted) return;
      
      // Update Focus Mode words learned
      if (result.correctCount > 0) {
        context.read<FocusProvider>().incrementWordsLearned(result.correctCount);
      }
      
      Navigator.of(context).pushReplacement(
        CupertinoPageRoute(builder: (_) => ResultScreen(result: result)),
      );
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _goToQuestion(int newIndex) {
    if (newIndex < 0 || newIndex >= _questions.length || newIndex == _index) return;
    AudioHapticService.instance.selectionClick();
    _timer?.cancel();
    _advanceTimer?.cancel();
    final q = _questions[newIndex];
    final alreadyAnswered = _answers.containsKey(q.wordId);
    setState(() {
      _index = newIndex;
      if (alreadyAnswered) {
        _selectedAnswer = _answers[q.wordId];
        _locked = true;
        _timedOut = false;
        _remaining = 0;
      } else {
        _selectedAnswer = null;
        _locked = false;
        _timedOut = false;
        _remaining = _questionSeconds;
        _questionStartedAt = DateTime.now();
      }
    });
    if (!alreadyAnswered) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted || _locked || _submitting) return;
        if (_remaining <= 1) {
          _lockAnswer(null, timedOut: true);
        } else {
          setState(() => _remaining--);
        }
      });
    }
  }

  Future<void> _showJumpToQuestionDialog() async {
    final controller = TextEditingController(text: '${_index + 1}');
    final isDark = AppColors.isDark(context);
    final result = await showCupertinoDialog<int>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text("Savol raqamiga o'tish"),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "1 dan ${_questions.length} gacha bo'lgan savol raqamini kiriting:",
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              CupertinoTextField(
                controller: controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
                placeholder: '1 - ${_questions.length}',
              ),
            ],
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Bekor qilish'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              final val = int.tryParse(controller.text.trim());
              if (val != null && val >= 1 && val <= _questions.length) {
                Navigator.pop(ctx, val - 1);
              }
            },
            child: const Text("O'tish"),
          ),
        ],
      ),
    );
    if (result != null && mounted) {
      _goToQuestion(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<List<QuizQuestionModel>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done &&
                _questions.isEmpty) {
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
                children: [
                  _Header(
                    title: _modeTitle(context, widget.mode, widget.reviewAll),
                    subtitle: widget.reviewAll || widget.dueReviews
                        ? l10n.t('quiz.allWords')
                        : widget.lesson?.title ?? '',
                    remaining: _remaining,
                    total: 0,
                    currentIndex: 0,
                    answers: const {},
                    fastMode: _fastMode,
                    onFastModeChanged: _toggleFastMode,
                  ),
                  const SizedBox(height: 18),
                  LoadingStateView(message: l10n.t('quiz.generating')),
                ],
              );
            }

            if (snapshot.hasError && _questions.isEmpty) {
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
                children: [
                  _Header(
                    title: _modeTitle(context, widget.mode, widget.reviewAll),
                    subtitle: widget.reviewAll || widget.dueReviews
                        ? l10n.t('quiz.allWords')
                        : widget.lesson?.title ?? '',
                    remaining: _remaining,
                    total: 0,
                    currentIndex: 0,
                    answers: const {},
                    fastMode: _fastMode,
                    onFastModeChanged: _toggleFastMode,
                  ),
                  const SizedBox(height: 18),
                  ErrorStateView(
                    message: snapshot.error?.toString() ?? 'Error',
                    onRetry: _load,
                  ),
                ],
              );
            }

            final questions = _questions;
            if (questions.isEmpty) {
              return Column(
                children: [
                  _Header(
                    title: _modeTitle(context, widget.mode, widget.reviewAll),
                    subtitle: widget.reviewAll || widget.dueReviews
                        ? l10n.t('quiz.allWords')
                        : widget.lesson?.title ?? '',
                    remaining: _remaining,
                    total: 0,
                    currentIndex: 0,
                    answers: const {},
                    fastMode: _fastMode,
                    onFastModeChanged: _toggleFastMode,
                  ),
                  EmptyStateView(
                    icon: Icons.quiz_outlined,
                    message: l10n.t('quiz.empty'),
                  ),
                ],
              );
            }

            final currentIndex = _index >= questions.length
                ? questions.length - 1
                : _index;
            final question = questions[currentIndex];

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
              children: [
                _Header(
                  title: _modeTitle(context, widget.mode, widget.reviewAll),
                  subtitle: widget.reviewAll || widget.dueReviews
                      ? l10n.t('quiz.allWords')
                      : widget.lesson?.title ?? '',
                  remaining: _remaining,
                  total: questions.length,
                  currentIndex: _index,
                  answers: _answers,
                  questions: questions,
                  fastMode: _fastMode,
                  onFastModeChanged: _toggleFastMode,
                  onQuestionTap: _index < questions.length - 1
                      ? (index) {
                          if (_locked) return;
                          _goToQuestion(index);
                        }
                      : null,
                  onJumpTap: _showJumpToQuestionDialog,
                ),
                const SizedBox(height: 14),
                _QuestionCard(
                  question: question,
                  index: currentIndex,
                  total: questions.length,
                  remaining: _remaining,
                  locked: _locked,
                  selectedAnswer: _selectedAnswer,
                  timedOut: _timedOut,
                  onSelect: _selectAnswer,
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: _locked
                      ? Padding(
                          key: ValueKey(
                            '${question.wordId}-${_selectedAnswer ?? 'timeout'}',
                          ),
                          padding: const EdgeInsets.only(top: 14),
                          child: _FeedbackCard(
                            question: question,
                            selectedAnswer: _selectedAnswer,
                            timedOut: _timedOut,
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                if (_submitting) ...[
                  const SizedBox(height: 14),
                  LoadingStateView(message: l10n.t('quiz.submitting')),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  ErrorStateView(message: _error!, onRetry: _submit),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatefulWidget {
  const _Header({
    required this.title,
    required this.subtitle,
    required this.remaining,
    required this.total,
    required this.currentIndex,
    required this.answers,
    this.questions,
    this.onQuestionTap,
    this.onJumpTap,
    this.fastMode = false,
    this.onFastModeChanged,
  });

  final String title;
  final String subtitle;
  final int remaining;
  final int total;
  final int currentIndex;
  final Map<int, String> answers;
  final List<QuizQuestionModel>? questions;
  final ValueChanged<int>? onQuestionTap;
  final VoidCallback? onJumpTap;
  final bool fastMode;
  final ValueChanged<bool>? onFastModeChanged;

  @override
  State<_Header> createState() => _HeaderState();
}

class _HeaderState extends State<_Header> {
  final ScrollController _scrollController = ScrollController();

  @override
  void didUpdateWidget(covariant _Header oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex && _scrollController.hasClients) {
      _scrollToCurrent();
    }
  }

  void _scrollToCurrent() {
    final targetOffset = (widget.currentIndex * 46.0) - 100.0;
    _scrollController.animateTo(
      targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final fgColor = isDark ? Colors.white : Colors.black;

    return Column(
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: Icon(CupertinoIcons.back, color: fgColor),
              style: IconButton.styleFrom(
                backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.all(10),
              ),
            ),
            Expanded(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.15 : 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.timer_outlined, color: Color(0xFFF59E0B), size: 18),
                      const SizedBox(width: 6),
                      Text(
                        '00:${widget.remaining.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          color: Color(0xFFF59E0B),
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (widget.total > 0)
              GestureDetector(
                onTap: widget.onJumpTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.35),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.grid_view_rounded, size: 16, color: Color(0xFF6366F1)),
                      const SizedBox(width: 6),
                      Text(
                        '${widget.currentIndex + 1}/${widget.total}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        if (widget.onFastModeChanged != null) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'Tez o\'tish',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              const SizedBox(width: 4),
              Transform.scale(
                scale: 0.7,
                child: CupertinoSwitch(
                  value: widget.fastMode,
                  onChanged: widget.onFastModeChanged,
                  activeColor: const Color(0xFF10B981),
                ),
              ),
            ],
          ),
        ],
        if (widget.total > 0 && widget.questions != null) ...[
          const SizedBox(height: 16),
          SizedBox(
            height: 40,
            child: ListView.separated(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              itemCount: widget.total,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final q = widget.questions![index];
                final isCurrent = index == widget.currentIndex;
                final answered = widget.answers.containsKey(q.wordId);

                Gradient? pillGradient;
                Color pillColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
                Color textColor = isDark ? Colors.white60 : const Color(0xFF475569);

                if (answered) {
                  final isCorrect = learningAnswersMatch(widget.answers[q.wordId]!, q.correctAnswer);
                  pillGradient = isCorrect
                      ? const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)])
                      : const LinearGradient(colors: [Color(0xFFF43F5E), Color(0xFFE11D48)]);
                  textColor = Colors.white;
                } else if (isCurrent) {
                  pillGradient = const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF4F46E5)]);
                  textColor = Colors.white;
                }

                return GestureDetector(
                  onTap: () => widget.onQuestionTap?.call(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: pillGradient == null ? pillColor : null,
                      gradient: pillGradient,
                      borderRadius: BorderRadius.circular(12),
                      border: isCurrent
                          ? Border.all(color: Colors.white, width: 2)
                          : Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : Colors.black.withValues(alpha: 0.05),
                            ),
                      boxShadow: isCurrent
                          ? [
                              BoxShadow(
                                color: const Color(0xFF6366F1).withValues(alpha: 0.45),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              )
                            ]
                          : null,
                    ),
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.question,
    required this.index,
    required this.total,
    required this.remaining,
    required this.locked,
    required this.selectedAnswer,
    required this.timedOut,
    required this.onSelect,
  });

  final QuizQuestionModel question;
  final int index;
  final int total;
  final int remaining;
  final bool locked;
  final String? selectedAnswer;
  final bool timedOut;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final showAudio = canRevealQuizAudio(
      direction: question.direction,
      answered: locked || timedOut,
    );
    final audioText = question.direction == 'uz_to_eng'
        ? question.correctAnswer
        : question.speechText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showAudio && audioText.isNotEmpty) ...[
          Center(
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: PronunciationButton(text: audioText, compact: false),
            ),
          ),
        ],
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.06),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Text(
            question.prompt,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              height: 1.3,
            ),
          ),
        ),
        const SizedBox(height: 20),
        for (var i = 0; i < question.options.length; i++) ...[
          QuizOptionCard(
            label: _optionLabel(context, question.options[i]),
            index: i,
            selected: selectedAnswer == question.options[i],
            correct: _optionState(
              question,
              question.options[i],
              locked || timedOut,
              selectedAnswer,
            ),
            onTap: locked ? null : () => onSelect(question.options[i]),
          ),
        ],
      ],
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({
    required this.question,
    required this.selectedAnswer,
    required this.timedOut,
  });

  final QuizQuestionModel question;
  final String? selectedAnswer;
  final bool timedOut;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = AppColors.isDark(context);
    final isCorrect =
        selectedAnswer != null &&
        _sameAnswer(selectedAnswer!, question.correctAnswer);

    final color = isCorrect ? const Color(0xFF10B981) : const Color(0xFFF43F5E);
    final bgColor = isCorrect
        ? const Color(0xFF10B981).withValues(alpha: isDark ? 0.15 : 0.1)
        : const Color(0xFFF43F5E).withValues(alpha: isDark ? 0.15 : 0.1);

    final message = timedOut
        ? l10n.f('quiz.answerTimeOut', {
            'answer': _optionLabel(context, question.correctAnswer),
          })
        : isCorrect
        ? l10n.t('quiz.answerCorrect')
        : l10n.f('quiz.answerWrong', {
            'answer': _optionLabel(context, question.correctAnswer),
          });

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isCorrect ? Icons.check_circle_rounded : Icons.info_rounded,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

bool? _optionState(
  QuizQuestionModel question,
  String option,
  bool revealed,
  String? selectedAnswer,
) {
  if (!revealed) return null;
  if (_sameAnswer(option, question.correctAnswer)) return true;
  if (selectedAnswer == option) return false;
  return null;
}

bool _sameAnswer(String left, String right) {
  return learningAnswersMatch(left, right);
}

String _normalize(String value) {
  return value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
}

String _optionLabel(BuildContext context, String option) {
  final normalized = _normalize(option);
  if (normalized == 'true') return context.l10n.t('quiz.true');
  if (normalized == 'false') return context.l10n.t('quiz.false');
  return option;
}

String _modeTitle(BuildContext context, String mode, bool reviewAll) {
  final l10n = context.l10n;
  if (reviewAll) return l10n.t('quiz.reviewAll');
  return switch (mode) {
    'reverse_quiz' => l10n.t('quiz.reverse'),
    'speed_quiz' => l10n.t('quiz.speed'),
    'true_false' => 'True / False',
    _ => l10n.t('quiz.victorina'),
  };
}
