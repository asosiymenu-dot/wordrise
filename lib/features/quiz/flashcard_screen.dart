import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/ios_selection_sheet.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/pronunciation_button.dart';
import '../../core/widgets/shimmer_loading.dart';
import '../../core/widgets/state_views.dart';
import '../../models/api_models.dart';
import '../../services/word_service.dart';
import '../../services/audio_haptic_service.dart';

class FlashcardScreen extends StatefulWidget {
  const FlashcardScreen({
    required this.lesson,
    required this.wordService,
    super.key,
  });

  final LessonModel lesson;
  final WordService wordService;

  @override
  State<FlashcardScreen> createState() => _FlashcardScreenState();
}

class _FlashcardScreenState extends State<FlashcardScreen> {
  late Future<List<WordModel>> _future;
  List<WordModel> _allWords = [];
  List<WordModel> _queue = [];
  final Map<int, int> _againAttempts = {};
  final Set<int> _resolved = {};
  final Set<int> _known = {};
  final Set<int> _hard = {};
  int _limit = 20;
  int _sessionTotal = 0;
  bool _flipped = false;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _future = widget.wordService.byLesson(widget.lesson.id);
    _future
        .then((words) {
          if (!mounted) return;
          _allWords = words;
          _prepareSession();
        })
        .catchError((_) {});
  }

  void _prepareSession() {
    final shuffled = [..._allWords]..shuffle();
    final count = _limit == 0
        ? shuffled.length
        : math.min(_limit, shuffled.length);
    setState(() {
      _queue = shuffled.take(count).toList();
      _sessionTotal = count;
      _againAttempts.clear();
      _resolved.clear();
      _known.clear();
      _hard.clear();
      _flipped = false;
      _finished = count == 0;
    });
  }

  Future<void> _pickLimit() async {
    final picked = await showIosSelectionSheet<int>(
      context: context,
      title: context.l10n.t('flashcard.sessionSize'),
      selected: _limit,
      options: [
        for (final value in const [10, 20, 30])
          IosSelectionOption(
            value: value,
            label: context.l10n.f('quiz.questionCount', {'count': value}),
          ),
        IosSelectionOption(
          value: 0,
          label: context.l10n.t('flashcard.allWords'),
        ),
      ],
    );
    if (picked == null || !mounted || picked == _limit) return;
    _limit = picked;
    _prepareSession();
  }

  void _flip() {
    if (_queue.isEmpty || _finished) return;
    AudioHapticService.instance.selectionClick();
    setState(() => _flipped = !_flipped);
  }

  void _rateCurrent({required bool known}) {
    if (!_flipped || _queue.isEmpty || _finished) return;
    final word = _queue.removeAt(0);
    if (known) {
      AudioHapticService.instance.playSuccess();
      _known.add(word.id);
      _resolved.add(word.id);
    } else {
      AudioHapticService.instance.playFail();
      final attempts = (_againAttempts[word.id] ?? 0) + 1;
      _againAttempts[word.id] = attempts;
      if (attempts < 2) {
        _queue.insert(math.min(3, _queue.length), word);
      } else {
        _hard.add(word.id);
        _resolved.add(word.id);
      }
    }

    setState(() {
      _flipped = false;
      _finished = _queue.isEmpty;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      body: GradientBackground(
        child: FutureBuilder<List<WordModel>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done &&
                _allWords.isEmpty) {
              return const _FlashcardLoading();
            }
            if (snapshot.hasError && _allWords.isEmpty) {
              return _StatePage(
                child: ErrorStateView(message: snapshot.error!),
              );
            }
            if (_allWords.isEmpty) {
              return _StatePage(
                child: EmptyStateView(
                  icon: CupertinoIcons.rectangle_stack,
                  message: l10n.t('flashcard.empty'),
                ),
              );
            }

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 4, 8, 8),
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
                              l10n.t('quiz.flashcard'),
                              style: AppTextStyles.titleFor(context),
                            ),
                            Text(
                              widget.lesson.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.captionFor(context),
                            ),
                          ],
                        ),
                      ),
                      CupertinoButton(
                        padding: const EdgeInsets.all(10),
                        onPressed: _pickLimit,
                        child: const Icon(CupertinoIcons.slider_horizontal_3),
                      ),
                    ],
                  ),
                ),
                if (!_finished) _buildProgress(context),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 320),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: ScaleTransition(
                          scale: Tween(
                            begin: .975,
                            end: 1.0,
                          ).animate(animation),
                          child: child,
                        ),
                      );
                    },
                    child: _finished
                        ? _FlashcardSummary(
                            key: const ValueKey('summary'),
                            known: _known.length,
                            hard: _hard.length,
                            total: _sessionTotal,
                            onRestart: _prepareSession,
                            onClose: () => Navigator.of(context).pop(),
                          )
                        : _FlashcardPractice(
                            key: ValueKey(
                              '${_queue.first.id}-${_flipped ? 'back' : 'front'}',
                            ),
                            word: _queue.first,
                            flipped: _flipped,
                            onFlip: _flip,
                            onKnown: () => _rateCurrent(known: true),
                            onAgain: () => _rateCurrent(known: false),
                          ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildProgress(BuildContext context) {
    final progress = _sessionTotal == 0
        ? 0.0
        : _resolved.length / _sessionTotal;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Row(
        children: [
          Expanded(
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
          const SizedBox(width: 10),
          Text(
            '${_resolved.length}/$_sessionTotal',
            style: AppTextStyles.captionFor(
              context,
            ).copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _FlashcardPractice extends StatelessWidget {
  const _FlashcardPractice({
    required this.word,
    required this.flipped,
    required this.onFlip,
    required this.onKnown,
    required this.onAgain,
    super.key,
  });

  final WordModel word;
  final bool flipped;
  final VoidCallback onFlip;
  final VoidCallback onKnown;
  final VoidCallback onAgain;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      child: Column(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: onFlip,
              onHorizontalDragEnd: flipped
                  ? (details) {
                      final velocity = details.primaryVelocity ?? 0;
                      if (velocity > 180) onKnown();
                      if (velocity < -180) onAgain();
                    }
                  : null,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: SizedBox(
                    width: double.infinity,
                    child: GlassCard(
                      padding: const EdgeInsets.all(28),
                      opacity: .66,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color:
                                  (flipped ? AppColors.green : AppColors.blue)
                                      .withValues(alpha: .12),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              flipped
                                  ? CupertinoIcons.textformat_alt
                                  : CupertinoIcons.book_fill,
                              color: flipped ? AppColors.green : AppColors.blue,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            flipped ? word.uzbekTranslation : word.englishWord,
                            textAlign: TextAlign.center,
                            style: AppTextStyles.displayFor(context),
                          ),
                          const SizedBox(height: 12),
                          PronunciationButton(
                            text: word.englishWord,
                            compact: true,
                          ),
                          if (flipped && word.exampleSentence.isNotEmpty) ...[
                            const SizedBox(height: 18),
                            Text(
                              word.exampleSentence,
                              textAlign: TextAlign.center,
                              style: AppTextStyles.bodyFor(context),
                            ),
                          ] else if (!flipped &&
                              word.pronunciation.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Text(
                              word.pronunciation,
                              style: AppTextStyles.captionFor(context),
                            ),
                          ],
                          const SizedBox(height: 22),
                          Text(
                            flipped
                                ? l10n.t('flashcard.swipeHint')
                                : l10n.t('flashcard.tapToFlip'),
                            textAlign: TextAlign.center,
                            style: AppTextStyles.captionFor(context),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (!flipped)
            PrimaryButton(
              label: l10n.t('flashcard.show'),
              icon: CupertinoIcons.arrow_2_circlepath,
              onPressed: onFlip,
            )
          else
            Row(
              children: [
                Expanded(
                  child: SecondaryButton(
                    label: l10n.t('flashcard.again'),
                    icon: CupertinoIcons.arrow_counterclockwise,
                    onPressed: onAgain,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: PrimaryButton(
                    label: l10n.t('flashcard.known'),
                    icon: CupertinoIcons.check_mark,
                    onPressed: onKnown,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _FlashcardSummary extends StatelessWidget {
  const _FlashcardSummary({
    required this.known,
    required this.hard,
    required this.total,
    required this.onRestart,
    required this.onClose,
    super.key,
  });

  final int known;
  final int hard;
  final int total;
  final VoidCallback onRestart;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: GlassCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Icon(
                  CupertinoIcons.check_mark_circled_solid,
                  color: AppColors.green,
                  size: 54,
                ),
                const SizedBox(height: 14),
                Text(
                  context.l10n.t('flashcard.complete'),
                  style: AppTextStyles.titleFor(context),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _SummaryValue(
                        value: '$known',
                        label: context.l10n.t('flashcard.known'),
                        color: AppColors.green,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _SummaryValue(
                        value: '$hard',
                        label: context.l10n.t('flashcard.hard'),
                        color: AppColors.softRed,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _SummaryValue(
                        value: '$total',
                        label: context.l10n.t('flashcard.total'),
                        color: AppColors.blue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                PrimaryButton(
                  label: context.l10n.t('flashcard.restart'),
                  icon: CupertinoIcons.refresh,
                  onPressed: onRestart,
                ),
                CupertinoButton(
                  onPressed: onClose,
                  child: Text(context.l10n.t('common.close')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: AppTextStyles.sectionFor(
              context,
            ).copyWith(color: color, fontSize: 20),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.captionFor(context),
          ),
        ],
      ),
    );
  }
}

class _FlashcardLoading extends StatelessWidget {
  const _FlashcardLoading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(20, 72, 20, 30),
      child: Column(
        children: [
          ShimmerBox(width: 220, height: 28, borderRadius: 8),
          SizedBox(height: 28),
          Expanded(
            child: ShimmerBox(
              width: double.infinity,
              height: double.infinity,
              borderRadius: 22,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatePage extends StatelessWidget {
  const _StatePage({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 72, 20, 30),
      children: [child],
    );
  }
}
