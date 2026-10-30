import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/quiz_option_card.dart';
import '../../core/widgets/state_views.dart';
import '../../models/api_models.dart';
import '../../services/api_service.dart';
import '../../services/battle_service.dart';

class BattleScreen extends StatefulWidget {
  const BattleScreen({
    required this.service,
    required this.initialBattle,
    super.key,
  });

  final BattleService service;
  final BattleStateModel initialBattle;

  @override
  State<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends State<BattleScreen> {
  Timer? _poller;
  Timer? _secondTicker;
  late BattleStateModel _battle;
  int _currentIndex = 0;
  int _localTimeLeft = 0;
  int _localCountdown = 0;
  DateTime _questionStartedAt = DateTime.now();
  int? _lastQuestionId;
  bool _answering = false;
  bool _refreshing = false;
  bool _rematching = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _battle = widget.initialBattle;
    _localTimeLeft = _battle.timeLeft;
    _localCountdown = _battle.countdownSeconds;
    _syncCurrentQuestion();
    _poller = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _refresh(silent: true),
    );
    _secondTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !_battle.active) return;
      if (_battle.countdown) {
        if (_localCountdown > 0) {
          setState(() => _localCountdown--);
        }
        if (_localCountdown <= 0) _refresh(silent: true);
      } else if (_localTimeLeft > 0) {
        setState(() => _localTimeLeft--);
      } else {
        _refresh(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _poller?.cancel();
    _secondTicker?.cancel();
    super.dispose();
  }

  Future<void> _refresh({bool silent = false}) async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final next = await widget.service.state(_battle.id);
      if (!mounted) return;
      setState(() {
        _battle = next;
        _localTimeLeft = next.timeLeft;
        _localCountdown = next.countdownSeconds;
        _error = null;
      });
      _syncCurrentQuestion();
    } on ApiException catch (error) {
      if (!silent && mounted) setState(() => _error = error.message);
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _answer(String option) async {
    if (_answering ||
        !_battle.active ||
        _battle.countdown ||
        _battle.questions.isEmpty) {
      return;
    }
    final question = _battle.questions[_currentIndex];
    if (_battle.myAnswersByQuestion.containsKey(question.id)) return;

    setState(() {
      _answering = true;
      _error = null;
    });
    final elapsed = DateTime.now()
        .difference(_questionStartedAt)
        .inMilliseconds;
    try {
      final next = await widget.service.answer(
        battleId: _battle.id,
        questionId: question.id,
        answer: option,
        answeredMs: elapsed,
      );
      if (!mounted) return;
      setState(() {
        _battle = next;
        _localTimeLeft = next.timeLeft;
        _localCountdown = next.countdownSeconds;
      });
      Future.delayed(const Duration(milliseconds: 700), () {
        if (!mounted) return;
        setState(_moveToNextUnanswered);
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _answering = false);
    }
  }

  void _syncCurrentQuestion() {
    final questions = _battle.questions;
    if (questions.isEmpty) return;
    final answers = _battle.myAnswersByQuestion;
    final current = questions[_currentIndex.clamp(0, questions.length - 1)];
    if (!answers.containsKey(current.id)) {
      _resetQuestionClock(current.id);
      return;
    }
    _moveToNextUnanswered();
  }

  void _moveToNextUnanswered() {
    final questions = _battle.questions;
    final answers = _battle.myAnswersByQuestion;
    final nextIndex = questions.indexWhere(
      (question) => !answers.containsKey(question.id),
    );
    if (nextIndex >= 0) {
      _currentIndex = nextIndex;
      _resetQuestionClock(questions[nextIndex].id);
    }
  }

  void _resetQuestionClock(int questionId) {
    if (_lastQuestionId == questionId) return;
    _lastQuestionId = questionId;
    _questionStartedAt = DateTime.now();
  }

  Future<void> _rematch() async {
    if (_rematching) return;
    setState(() {
      _rematching = true;
      _error = null;
    });
    try {
      await widget.service.rematch(_battle.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.t('battle.rematchSent'))),
      );
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _rematching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      body: GradientBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
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
                    l10n.t('battle.title'),
                    style: AppTextStyles.titleFor(context),
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: () => _refresh(),
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_battle.waiting)
              _WaitingCard(battle: _battle)
            else ...[
              _ScoreCard(battle: _battle, timeLeft: _localTimeLeft),
              const SizedBox(height: 14),
              if (_battle.finished)
                _FinishedCard(
                  battle: _battle,
                  rematching: _rematching,
                  onRematch: _rematch,
                  onBack: () => Navigator.of(context).pop(),
                )
              else if (_battle.countdown)
                _CountdownCard(seconds: _localCountdown)
              else
                _QuestionCard(
                  battle: _battle,
                  index: _currentIndex,
                  answering: _answering,
                  onAnswer: _answer,
                ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 14),
              ErrorStateView(message: _error!),
            ],
          ],
        ),
      ),
    );
  }
}

class _CountdownCard extends StatelessWidget {
  const _CountdownCard({required this.seconds});

  final int seconds;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 42, horizontal: 20),
      child: Column(
        children: [
          Text(
            context.l10n.t('battle.getReady'),
            style: AppTextStyles.sectionFor(context),
          ),
          const SizedBox(height: 14),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 240),
            transitionBuilder: (child, animation) => ScaleTransition(
              scale: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutBack,
              ),
              child: FadeTransition(opacity: animation, child: child),
            ),
            child: Text(
              '${seconds.clamp(1, 3)}',
              key: ValueKey(seconds),
              style: AppTextStyles.displayFor(
                context,
              ).copyWith(color: AppColors.green, fontSize: 72),
            ),
          ),
        ],
      ),
    );
  }
}

class _WaitingCard extends StatelessWidget {
  const _WaitingCard({required this.battle});

  final BattleStateModel battle;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Icon(
            Icons.group_add_rounded,
            size: 52,
            color: AppColors.blue.withValues(alpha: .9),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.t('battle.waiting'),
            style: AppTextStyles.titleFor(context),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.t('battle.shareCode'),
            textAlign: TextAlign.center,
            style: AppTextStyles.captionFor(context),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.blue.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: SelectableText(
              battle.roomCode,
              style: AppTextStyles.displayFor(
                context,
              ).copyWith(color: AppColors.blue, letterSpacing: 2),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: battle.roomCode));
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(l10n.t('battle.copied'))));
            },
            icon: const Icon(Icons.copy_rounded),
            label: Text(l10n.t('battle.copyCode')),
          ),
        ],
      ),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({required this.battle, required this.timeLeft});

  final BattleStateModel battle;
  final int timeLeft;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  battle.direction == 'uz_to_eng'
                      ? context.l10n.t('quiz.uzToEng')
                      : context.l10n.t('quiz.engToUz'),
                  style: AppTextStyles.captionFor(context).copyWith(
                    color: AppColors.blue,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _TimerPill(seconds: timeLeft),
            ],
          ),
          const SizedBox(height: 12),
          for (final score in battle.scoreboard) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    score.user.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.sectionFor(
                      context,
                    ).copyWith(fontSize: 15),
                  ),
                ),
                Text(
                  '${score.correctCount}/${battle.questionLimit}',
                  style: AppTextStyles.sectionFor(
                    context,
                  ).copyWith(fontSize: 15, color: AppColors.green),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: battle.questionLimit == 0
                    ? 0
                    : score.answeredCount / battle.questionLimit,
                minHeight: 8,
                backgroundColor: Colors.white.withValues(alpha: .16),
                valueColor: const AlwaysStoppedAnimation(AppColors.blue),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _TimerPill extends StatelessWidget {
  const _TimerPill({required this.seconds});

  final int seconds;

  @override
  Widget build(BuildContext context) {
    final color = seconds <= 10 ? AppColors.softRed : AppColors.blue;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .13),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_rounded, size: 17, color: color),
          const SizedBox(width: 4),
          Text(
            context.l10n.f('common.seconds', {'seconds': seconds}),
            style: TextStyle(color: color, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.battle,
    required this.index,
    required this.answering,
    required this.onAnswer,
  });

  final BattleStateModel battle;
  final int index;
  final bool answering;
  final ValueChanged<String> onAnswer;

  @override
  Widget build(BuildContext context) {
    final questions = battle.questions;
    if (questions.isEmpty) {
      return EmptyStateView(
        icon: Icons.quiz_rounded,
        message: context.l10n.t('quiz.empty'),
      );
    }
    final safeIndex = index.clamp(0, questions.length - 1);
    final question = questions[safeIndex];
    final answer = battle.myAnswersByQuestion[question.id];
    final revealed = answer != null;

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.f('quiz.question', {
              'current': safeIndex + 1,
              'total': questions.length,
            }),
            style: AppTextStyles.captionFor(
              context,
            ).copyWith(color: AppColors.blue, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 14),
          Text(
            question.prompt,
            style: AppTextStyles.displayFor(context).copyWith(fontSize: 30),
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.t('quiz.choose'),
            style: AppTextStyles.captionFor(context),
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < question.options.length; i++) ...[
            QuizOptionCard(
              index: i,
              label: question.options[i],
              selected: answer?.givenAnswer == question.options[i],
              correct: _optionState(question, question.options[i], revealed, answer),
              onTap: answering || revealed ? null : () => onAnswer(question.options[i]),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _FinishedCard extends StatelessWidget {
  const _FinishedCard({
    required this.battle,
    required this.rematching,
    required this.onRematch,
    required this.onBack,
  });

  final BattleStateModel battle;
  final bool rematching;
  final VoidCallback onRematch;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final winner = battle.scoreboard.isEmpty ? null : battle.scoreboard.first;
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Icon(
            Icons.emoji_events_rounded,
            color: AppColors.gold,
            size: 54,
          ),
          const SizedBox(height: 12),
          Text(
            context.l10n.t('battle.finished'),
            style: AppTextStyles.titleFor(context),
          ),
          if (winner != null) ...[
            const SizedBox(height: 8),
            Text(
              context.l10n.f('battle.winner', {'name': winner.user.name}),
              textAlign: TextAlign.center,
              style: AppTextStyles.sectionFor(
                context,
              ).copyWith(color: AppColors.green),
            ),
          ],
          const SizedBox(height: 14),
          for (final score in battle.scoreboard)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(child: Text(_initial(score.user.name))),
              title: Text(score.user.name),
              subtitle: Text(
                '${context.l10n.f('battle.answered', {'count': score.answeredCount, 'total': battle.questionLimit})} • ${(score.averageMs / 1000).toStringAsFixed(1)}s',
              ),
              trailing: Text(
                '${score.correctCount}',
                style: AppTextStyles.titleFor(
                  context,
                ).copyWith(color: AppColors.green),
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onBack,
                  icon: const Icon(Icons.chat_bubble_outline_rounded),
                  label: Text(context.l10n.t('battle.backToChat')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: rematching ? null : onRematch,
                  icon: rematching
                      ? const SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.replay_rounded),
                  label: Text(context.l10n.t('battle.rematch')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

bool? _optionState(
  BattleQuestionModel question,
  String option,
  bool revealed,
  BattleAnswerModel? answer,
) {
  if (!revealed) return null;
  if (_sameAnswer(option, question.correctAnswer)) return true;
  if (answer?.givenAnswer == option) return false;
  return null;
}

bool _sameAnswer(String left, String right) {
  return left.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase() ==
      right.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
}

String _initial(String value) {
  final text = value.trim();
  return text.isEmpty ? '?' : text[0].toUpperCase();
}
