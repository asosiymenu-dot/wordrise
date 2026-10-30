import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/state_views.dart';
import '../../models/api_models.dart';
import '../../services/api_service.dart';
import '../../services/speaking_service.dart';

class SpeakingScreen extends StatefulWidget {
  const SpeakingScreen({
    required this.service,
    required this.currentUser,
    super.key,
  });

  final SpeakingService service;
  final UserModel currentUser;

  @override
  State<SpeakingScreen> createState() => _SpeakingScreenState();
}

class _SpeakingScreenState extends State<SpeakingScreen> {
  final _speech = SpeechToText();
  final _topicController = TextEditingController(text: 'daily life');
  final List<Map<String, String>> _history = [];
  SpeakingQuestionModel? _question;
  SpeakingFeedbackModel? _feedback;
  bool _speechReady = false;
  bool _loadingQuestion = false;
  bool _listening = false;
  bool _submitting = false;
  String _transcript = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _loadQuestion();
  }

  @override
  void dispose() {
    _speech.stop();
    _topicController.dispose();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    try {
      final ready = await _speech.initialize(
        onError: (_) {
          if (mounted) setState(() => _listening = false);
        },
        onStatus: (status) {
          if (mounted && status == 'done') setState(() => _listening = false);
        },
      );
      if (mounted) setState(() => _speechReady = ready);
    } on Object {
      if (mounted) {
        setState(() {
          _speechReady = false;
          _listening = false;
        });
      }
    }
  }

  Future<void> _loadQuestion({String? forcedQuestion}) async {
    setState(() {
      _loadingQuestion = true;
      _feedback = null;
      _transcript = '';
      _error = null;
    });
    try {
      if (forcedQuestion != null && forcedQuestion.trim().isNotEmpty) {
        _question = SpeakingQuestionModel(
          question: forcedQuestion.trim(),
          topic: _topicController.text.trim(),
          level: widget.currentUser.englishLevel,
          hintUz: context.l10n.t('speaking.answerHint'),
          sampleAnswer: '',
        );
      } else {
        _question = await widget.service.question(
          level: widget.currentUser.englishLevel,
          topic: _topicController.text.trim().isEmpty
              ? 'daily life'
              : _topicController.text.trim(),
          history: _history,
        );
      }
    } on ApiException catch (error) {
      _error = error.message;
    } finally {
      if (mounted) setState(() => _loadingQuestion = false);
    }
  }

  Future<void> _toggleListening() async {
    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    if (!_speechReady) {
      await _initSpeech();
    }
    if (!_speechReady) {
      setState(() => _error = context.l10n.t('speaking.micUnavailable'));
      return;
    }

    setState(() {
      _listening = true;
      _error = null;
    });
    try {
      await _speech.listen(
        onResult: (result) {
          if (!mounted) return;
          setState(() => _transcript = result.recognizedWords);
        },
        listenOptions: SpeechListenOptions(
          localeId: 'en_US',
          listenFor: const Duration(seconds: 45),
          pauseFor: const Duration(seconds: 4),
        ),
      );
    } on Object {
      if (mounted) {
        setState(() {
          _listening = false;
          _error = context.l10n.t('speaking.micUnavailable');
        });
      }
    }
  }

  Future<void> _submitAnswer() async {
    final question = _question;
    final answer = _transcript.trim();
    if (question == null || answer.isEmpty) return;
    await _speech.stop();
    setState(() {
      _listening = false;
      _submitting = true;
      _error = null;
    });
    try {
      final feedback = await widget.service.feedback(
        level: widget.currentUser.englishLevel,
        question: question.question,
        answer: answer,
      );
      _history.add({'question': question.question, 'answer': answer});
      if (_history.length > 8) _history.removeAt(0);
      if (mounted) setState(() => _feedback = feedback);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
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
                    l10n.t('speaking.title'),
                    style: AppTextStyles.titleFor(context),
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: _loadingQuestion ? null : () => _loadQuestion(),
                  icon: const Icon(Icons.auto_awesome_rounded),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              l10n.t('speaking.subtitle'),
              style: AppTextStyles.captionFor(context),
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _topicController,
              label: l10n.t('speaking.topic'),
              icon: Icons.topic_rounded,
            ),
            const SizedBox(height: 14),
            if (_loadingQuestion)
              LoadingStateView(message: l10n.t('speaking.loadingQuestion'))
            else if (_question != null)
              _QuestionGlass(question: _question!),
            const SizedBox(height: 14),
            GlassCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _toggleListening,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: _listening
                              ? const [AppColors.softRed, AppColors.gold]
                              : const [AppColors.blue, AppColors.purple],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color:
                                (_listening
                                        ? AppColors.softRed
                                        : AppColors.blue)
                                    .withValues(alpha: .28),
                            blurRadius: 28,
                            offset: const Offset(0, 14),
                          ),
                        ],
                      ),
                      child: Icon(
                        _listening ? Icons.stop_rounded : Icons.mic_rounded,
                        color: Colors.white,
                        size: 38,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _listening
                        ? l10n.t('speaking.listening')
                        : l10n.t('speaking.tapMic'),
                    style: AppTextStyles.sectionFor(
                      context,
                    ).copyWith(fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(
                        alpha: AppColors.isDark(context) ? .08 : .42,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.divider(context)),
                    ),
                    child: Text(
                      _transcript.isEmpty
                          ? l10n.t('speaking.transcriptEmpty')
                          : _transcript,
                      style: AppTextStyles.bodyFor(context).copyWith(
                        color: _transcript.isEmpty
                            ? AppColors.textMuted(context)
                            : AppColors.textPrimary(context),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  PrimaryButton(
                    label: l10n.t('speaking.sendAnswer'),
                    icon: Icons.send_rounded,
                    loading: _submitting,
                    onPressed: _transcript.trim().isEmpty
                        ? null
                        : _submitAnswer,
                  ),
                ],
              ),
            ),
            if (_feedback != null) ...[
              const SizedBox(height: 14),
              _FeedbackGlass(
                feedback: _feedback!,
                onNext: () =>
                    _loadQuestion(forcedQuestion: _feedback!.nextQuestion),
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

class _QuestionGlass extends StatelessWidget {
  const _QuestionGlass({required this.question});

  final SpeakingQuestionModel question;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${question.level} • ${question.topic}',
            style: AppTextStyles.captionFor(
              context,
            ).copyWith(color: AppColors.blue, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          Text(
            question.question,
            style: AppTextStyles.titleFor(context).copyWith(height: 1.18),
          ),
          if (question.hintUz.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(question.hintUz, style: AppTextStyles.captionFor(context)),
          ],
        ],
      ),
    );
  }
}

class _FeedbackGlass extends StatelessWidget {
  const _FeedbackGlass({required this.feedback, required this.onNext});

  final SpeakingFeedbackModel feedback;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.t('speaking.feedback'),
                  style: AppTextStyles.sectionFor(context),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.green.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${feedback.score}/100',
                  style: const TextStyle(
                    color: AppColors.green,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(feedback.feedbackUz, style: AppTextStyles.bodyFor(context)),
          const SizedBox(height: 12),
          _TipLine(icon: Icons.spellcheck_rounded, text: feedback.grammarTipUz),
          const SizedBox(height: 8),
          _TipLine(
            icon: Icons.record_voice_over_rounded,
            text: feedback.pronunciationTipUz,
          ),
          const SizedBox(height: 12),
          Text(
            feedback.correctedAnswer,
            style: AppTextStyles.sectionFor(
              context,
            ).copyWith(fontSize: 16, color: AppColors.blue),
          ),
          const SizedBox(height: 14),
          SecondaryButton(
            label: l10n.t('speaking.nextQuestion'),
            icon: Icons.arrow_forward_rounded,
            onPressed: onNext,
          ),
        ],
      ),
    );
  }
}

class _TipLine extends StatelessWidget {
  const _TipLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) return const SizedBox.shrink();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.purple),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: AppTextStyles.captionFor(context))),
      ],
    );
  }
}
