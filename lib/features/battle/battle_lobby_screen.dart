import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/error_message.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/ios_selection_sheet.dart';
import '../../core/widgets/lesson_picker_sheet.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/shimmer_loading.dart';
import '../../core/widgets/state_views.dart';
import '../../models/api_models.dart';
import '../../services/battle_service.dart';
import '../../services/lesson_service.dart';
import 'battle_screen.dart';
import '../../services/audio_haptic_service.dart';

class BattleLobbyScreen extends StatefulWidget {
  const BattleLobbyScreen({
    required this.lessonService,
    required this.battleService,
    this.initialLesson,
    this.initialDirection = 'eng_to_uz',
    super.key,
  });

  final LessonService lessonService;
  final BattleService battleService;
  final LessonModel? initialLesson;
  final String initialDirection;

  @override
  State<BattleLobbyScreen> createState() => _BattleLobbyScreenState();
}

class _BattleLobbyScreenState extends State<BattleLobbyScreen> {
  late Future<List<LessonModel>> _future;
  final _codeController = TextEditingController();
  LessonModel? _lesson;
  int _limit = 10;
  int _duration = 90;
  late String _direction;
  bool _creating = false;
  bool _joining = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _lesson = widget.initialLesson;
    _direction = widget.initialDirection;
    _future = widget.lessonService.all();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _createBattle() async {
    if (_creating) return;
    AudioHapticService.instance.mediumImpact();
    setState(() {
      _creating = true;
      _error = null;
    });
    try {
      final battle = await widget.battleService.create(
        lessonId: _lesson?.id,
        limit: _limit,
        durationSeconds: _duration,
        direction: _direction,
      );
      if (mounted) _openBattle(battle);
    } on Object catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _joinBattle() async {
    final code = _codeController.text.trim();
    if (code.isEmpty || _joining) return;
    AudioHapticService.instance.mediumImpact();
    setState(() {
      _joining = true;
      _error = null;
    });
    try {
      final battle = await widget.battleService.join(code);
      if (mounted) _openBattle(battle);
    } on Object catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  void _openBattle(BattleStateModel battle) {
    Navigator.of(context).pushReplacement(
      CupertinoPageRoute(
        builder: (_) =>
            BattleScreen(service: widget.battleService, initialBattle: battle),
      ),
    );
  }

  Future<void> _pickLesson(List<LessonModel> lessons) async {
    final result = await showLessonPickerSheet(
      context: context,
      lessons: lessons,
      selectedLesson: _lesson,
      allowAllWords: true,
    );
    if (result != null && mounted) setState(() => _lesson = result.lesson);
  }

  Future<void> _pickLimit() async {
    final value = await showIosSelectionSheet<int>(
      context: context,
      title: context.l10n.t('battle.limit'),
      selected: _limit,
      options: [
        for (final count in const [10, 20, 30, 50])
          IosSelectionOption(
            value: count,
            label: context.l10n.f('quiz.questionCount', {'count': count}),
          ),
      ],
    );
    if (value != null && mounted) setState(() => _limit = value);
  }

  Future<void> _pickDuration() async {
    final value = await showIosSelectionSheet<int>(
      context: context,
      title: context.l10n.t('battle.duration'),
      selected: _duration,
      options: [
        for (final seconds in const [60, 90, 120])
          IosSelectionOption(
            value: seconds,
            label: context.l10n.f('common.seconds', {'seconds': seconds}),
          ),
      ],
    );
    if (value != null && mounted) setState(() => _duration = value);
  }

  Future<void> _pickDirection() async {
    final value = await showIosSelectionSheet<String>(
      context: context,
      title: context.l10n.t('quiz.direction'),
      selected: _direction,
      options: [
        IosSelectionOption(
          value: 'eng_to_uz',
          label: context.l10n.t('quiz.engToUz'),
        ),
        IosSelectionOption(
          value: 'uz_to_eng',
          label: context.l10n.t('quiz.uzToEng'),
        ),
        IosSelectionOption(
          value: 'mixed',
          label: 'Aralash',
        ),
      ],
    );
    if (value != null && mounted) setState(() => _direction = value);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: GradientBackground(
        child: FutureBuilder<List<LessonModel>>(
          future: _future,
          builder: (context, snapshot) {
            final lessons = snapshot.data ?? [];
            if (_lesson != null &&
                !lessons.any((item) => item.id == _lesson!.id)) {
              _lesson = null;
            }
            return ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                20,
                4,
                20,
                MediaQuery.viewInsetsOf(context).bottom + 28,
              ),
              children: [
                Row(
                  children: [
                    CupertinoButton(
                      padding: const EdgeInsets.all(10),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Icon(CupertinoIcons.back),
                    ),
                    Expanded(
                      child: Text(
                        l10n.t('battle.title'),
                        style: AppTextStyles.titleFor(context),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    l10n.t('battle.simpleSubtitle'),
                    style: AppTextStyles.captionFor(context),
                  ),
                ),
                const SizedBox(height: 18),
                if (snapshot.connectionState != ConnectionState.done)
                  const _BattleLobbySkeleton()
                else if (snapshot.hasError)
                  ErrorStateView(message: snapshot.error!)
                else ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppColors.glassSurface(context),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.sports_mma_rounded, color: Colors.amber, size: 54),
                        const SizedBox(height: 16),
                        Text('OCTAGON', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 2)),
                        Text('Birga bir jang yaratish', style: TextStyle(color: Colors.white70, fontSize: 14)),
                        const SizedBox(height: 24),
                        SizedBox(
                          height: 110,
                          child: Row(
                            children: [
                              Expanded(
                                child: _GlassOption(
                                  title: l10n.t('battle.lesson'),
                                  value: _lesson?.title ?? l10n.t('battle.allWords'),
                                  icon: Icons.menu_book_rounded,
                                  color: Colors.blueAccent,
                                  onTap: () => _pickLesson(lessons),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _GlassOption(
                                  title: l10n.t('battle.limit'),
                                  value: '$_limit so\'z',
                                  icon: Icons.format_list_numbered_rounded,
                                  color: Colors.greenAccent,
                                  onTap: _pickLimit,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 110,
                          child: Row(
                            children: [
                              Expanded(
                                child: _GlassOption(
                                  title: l10n.t('battle.duration'),
                                  value: '$_duration soniya',
                                  icon: Icons.timer_rounded,
                                  color: Colors.orangeAccent,
                                  onTap: _pickDuration,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _GlassOption(
                                  title: 'Til',
                                  value: _direction == 'uz_to_eng' ? 'UZ ➔ EN' : (_direction == 'mixed' ? 'Aralash' : 'EN ➔ UZ'),
                                  icon: Icons.translate_rounded,
                                  color: Colors.purpleAccent,
                                  onTap: _pickDirection,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        PrimaryButton(
                          label: l10n.t('battle.createRoom'),
                          icon: Icons.add_circle_outline_rounded,
                          loading: _creating,
                          onPressed: _createBattle,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _SectionLabel(text: l10n.t('battle.join')),
                  const SizedBox(height: 8),
                  GlassCard(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: [
                        CupertinoTextField(
                          controller: _codeController,
                          textCapitalization: TextCapitalization.characters,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _joinBattle(),
                          placeholder: l10n.t('battle.code'),
                          prefix: const Padding(
                            padding: EdgeInsets.only(left: 12),
                            child: Icon(CupertinoIcons.number, size: 19),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                          ),
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        PrimaryButton(
                          label: l10n.t('battle.joinRoom'),
                          icon: CupertinoIcons.arrow_right_circle_fill,
                          loading: _joining,
                          onPressed: _joinBattle,
                        ),
                      ],
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    ErrorStateView(message: userFacingError(context, _error!)),
                  ],
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _GlassOption extends StatelessWidget {
  const _GlassOption({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const Spacer(),
                Icon(Icons.edit_rounded, color: color.withValues(alpha: 0.7), size: 16),
              ],
            ),
            const Spacer(),
            Text(title, style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
      ),
    );
  }
}

class _BattleLobbySkeleton extends StatelessWidget {
  const _BattleLobbySkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        ShimmerBox(width: double.infinity, height: 220, borderRadius: 20),
        SizedBox(height: 14),
        ShimmerBox(width: double.infinity, height: 52, borderRadius: 14),
      ],
    );
  }
}
