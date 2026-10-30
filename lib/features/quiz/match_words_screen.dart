import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/state_views.dart';
import '../../models/api_models.dart';
import '../../services/audio_haptic_service.dart';
import '../../services/word_service.dart';

class MatchWordsScreen extends StatefulWidget {
  const MatchWordsScreen({
    required this.lesson,
    required this.wordService,
    super.key,
  });

  final LessonModel lesson;
  final WordService wordService;

  @override
  State<MatchWordsScreen> createState() => _MatchWordsScreenState();
}

class _MatchWordsScreenState extends State<MatchWordsScreen> {
  late Future<List<WordModel>> _future;
  WordModel? _left;
  WordModel? _right;
  final Set<int> _solved = {};
  int _limit = 8;
  List<WordModel> _roundWords = [];
  List<WordModel> _translations = [];
  String? _feedback;
  bool _feedbackCorrect = false;

  @override
  void initState() {
    super.initState();
    _future = widget.wordService.byLesson(widget.lesson.id);
  }

  void _buildRound(List<WordModel> allWords) {
    final shuffled = [...allWords]..shuffle();
    final count = _limit.clamp(2, allWords.length).toInt();
    final selected = shuffled.take(count).toList();
    final translations = [...selected]..shuffle();
    _roundWords = selected;
    _translations = translations;
    _solved.clear();
    _left = null;
    _right = null;
    _feedback = null;
  }

  void _setLimit(int value, List<WordModel> allWords) {
    setState(() {
      _limit = value;
      _buildRound(allWords);
    });
  }

  void _check() {
    if (_left == null || _right == null) return;
    final correct = _left!.id == _right!.id;
    if (correct) {
      AudioHapticService.instance.playSuccess();
      _solved.add(_left!.id);
    } else {
      AudioHapticService.instance.playFail();
    }
    _feedbackCorrect = correct;
    _feedback = correct
        ? context.l10n.t('match.correct')
        : context.l10n.t('match.wrong');
    _left = null;
    _right = null;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      body: GradientBackground(
        child: FutureBuilder<List<WordModel>>(
          future: _future,
          builder: (context, snapshot) {
            final allWords = snapshot.data ?? [];
            if (allWords.isNotEmpty && _roundWords.isEmpty) {
              _buildRound(allWords);
            }
            final words = _roundWords;
            final translations = _translations;
            return ListView(
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
                        l10n.t('quiz.match'),
                        style: AppTextStyles.titleFor(context),
                      ),
                    ),
                    IconButton.filledTonal(
                      onPressed: allWords.length < 2
                          ? null
                          : () => setState(() => _buildRound(allWords)),
                      icon: const Icon(Icons.shuffle_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (snapshot.connectionState != ConnectionState.done)
                  const LoadingStateView()
                else if (allWords.length < 2)
                  EmptyStateView(
                    icon: Icons.hub_rounded,
                    message: l10n.t('match.empty'),
                  )
                else ...[
                  GlassCard(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.t('match.limit'),
                          style: AppTextStyles.sectionFor(
                            context,
                          ).copyWith(fontSize: 16),
                        ),
                        const SizedBox(height: 10),
                        SegmentedButton<int>(
                          selected: {_limit},
                          onSelectionChanged: (value) =>
                              _setLimit(value.first, allWords),
                          segments: const [
                            ButtonSegment(value: 6, label: Text('6')),
                            ButtonSegment(value: 8, label: Text('8')),
                            ButtonSegment(value: 10, label: Text('10')),
                            ButtonSegment(value: 12, label: Text('12')),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${_solved.length}/${words.length}',
                          style: AppTextStyles.captionFor(context),
                        ),
                      ),
                      Text(
                        l10n.t('match.randomRound'),
                        style: AppTextStyles.captionFor(context),
                      ),
                    ],
                  ),
                  if (_feedback != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _feedback!,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.captionFor(context).copyWith(
                        color: _feedbackCorrect
                            ? AppColors.green
                            : AppColors.softRed,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            for (final word in words)
                              _MatchTile(
                                label: word.englishWord,
                                solved: _solved.contains(word.id),
                                selected: _left?.id == word.id,
                                onTap: () {
                                  setState(() => _left = word);
                                  _check();
                                },
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          children: [
                            for (final word in translations)
                              _MatchTile(
                                label: word.uzbekTranslation,
                                solved: _solved.contains(word.id),
                                selected: _right?.id == word.id,
                                onTap: () {
                                  setState(() => _right = word);
                                  _check();
                                },
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MatchTile extends StatelessWidget {
  const _MatchTile({
    required this.label,
    required this.solved,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool solved;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        onTap: solved ? null : onTap,
        opacity: solved || selected ? .56 : .30,
        padding: const EdgeInsets.all(14),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: AppTextStyles.sectionFor(context).copyWith(
            fontSize: 15,
            color: solved ? AppColors.green : AppColors.textPrimary(context),
          ),
        ),
      ),
    );
  }
}
