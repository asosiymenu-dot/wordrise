import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/lesson_picker_sheet.dart';
import '../../core/widgets/shimmer_loading.dart';
import '../../core/widgets/state_views.dart';
import '../../models/api_models.dart';
import '../../services/battle_service.dart';
import '../../services/lesson_service.dart';
import '../../services/quiz_service.dart';
import '../../services/word_service.dart';
import '../battle/battle_lobby_screen.dart';
import 'flashcard_screen.dart';
import 'match_words_screen.dart';
import 'quiz_screen.dart';
import 'typing_test_screen.dart';
import '../../services/audio_haptic_service.dart';

class QuizModeSelectionScreen extends StatefulWidget {
  const QuizModeSelectionScreen({
    required this.lessonService,
    required this.wordService,
    required this.quizService,
    required this.battleService,
    required this.currentUser,
    required this.onProfileChanged,
    super.key,
  });

  final LessonService lessonService;
  final WordService wordService;
  final QuizService quizService;
  final BattleService battleService;
  final UserModel currentUser;
  final ValueChanged<UserModel> onProfileChanged;

  @override
  State<QuizModeSelectionScreen> createState() =>
      _QuizModeSelectionScreenState();
}

class _QuizModeSelectionScreenState extends State<QuizModeSelectionScreen> {
  late Future<List<LessonModel>> _future;
  LessonModel? _lesson;
  int? _savedLessonId;
  int _reviewLimit = 20;
  String _direction = 'eng_to_uz';
  String _scope = 'all'; // Default to all words for maximum convenience

  @override
  void initState() {
    super.initState();
    _future = widget.lessonService.all();
    _loadSavedSettings();
  }

  Future<void> _loadSavedSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _savedLessonId = prefs.getInt('quiz_saved_lesson_id');
        _reviewLimit = prefs.getInt('quiz_saved_review_limit') ?? 20;
        _direction = prefs.getString('quiz_saved_direction') ?? 'eng_to_uz';
        _scope = prefs.getString('quiz_saved_scope') ?? 'all';
      });
    }
  }

  Future<void> _setScope(String scope) async {
    AudioHapticService.instance.selectionClick();
    setState(() => _scope = scope);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('quiz_saved_scope', scope);
  }

  Future<void> _setDirection(String direction) async {
    AudioHapticService.instance.selectionClick();
    setState(() => _direction = direction);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('quiz_saved_direction', direction);
  }

  Future<void> _setReviewLimit(int limit) async {
    AudioHapticService.instance.selectionClick();
    setState(() => _reviewLimit = limit);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('quiz_saved_review_limit', limit);
  }

  void _reload() {
    setState(() {
      _future = widget.lessonService.all();
    });
  }

  @override
  Widget build(BuildContext context) {
    return GradientBackground(
      child: FutureBuilder<List<LessonModel>>(
        future: _future,
        builder: (context, snapshot) {
          final lessons = snapshot.data ?? [];
          final lesson = _selectedLesson(lessons);

          return ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Random Viktorina',
                        style: AppTextStyles.displayFor(context),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'So\'z boyligingizni qulay formatda sinang',
                        style: AppTextStyles.captionFor(context),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: Color(0xFF8B5CF6),
                      size: 24,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (snapshot.connectionState != ConnectionState.done)
                const _QuizHubSkeleton()
              else if (snapshot.hasError)
                ErrorStateView(message: snapshot.error!, onRetry: _reload)
              else ...[
                // 1. SCOPE SELECTOR (Barcha so'zlar vs Mavzu bo'yicha)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.glassSurface(context),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.isDark(context)
                          ? Colors.white.withValues(alpha: 0.06)
                          : AppColors.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _ScopePill(
                          title: 'Barcha so\'zlar',
                          icon: Icons.all_inclusive_rounded,
                          selected: _scope == 'all',
                          onTap: () => _setScope('all'),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: _ScopePill(
                          title: 'Mavzu bo\'yicha',
                          icon: Icons.menu_book_rounded,
                          selected: _scope == 'lesson',
                          onTap: () => _setScope('lesson'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // 2. LESSON PICKER (Shows when 'Mavzu bo'yicha' is chosen)
                if (_scope == 'lesson') ...[
                  _LessonSelectCard(
                    lesson: lesson,
                    onTap: () => _pickLesson(lessons),
                  ),
                  const SizedBox(height: 14),
                ],

                // 3. SETTINGS BOX (Direction + Limit)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.glassSurface(context),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: AppColors.isDark(context)
                          ? Colors.white.withValues(alpha: 0.05)
                          : AppColors.border,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Direction
                      Row(
                        children: [
                          const Icon(
                            Icons.swap_horiz_rounded,
                            color: Color(0xFF10B981),
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Yo\'nalish',
                            style: TextStyle(
                              color: AppColors.textSecondary(context),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _ChoiceChip(
                              label: 'EN ➔ UZ',
                              selected: _direction == 'eng_to_uz',
                              onTap: () => _setDirection('eng_to_uz'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _ChoiceChip(
                              label: 'UZ ➔ EN',
                              selected: _direction == 'uz_to_eng',
                              onTap: () => _setDirection('uz_to_eng'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _ChoiceChip(
                              label: 'Aralash',
                              icon: Icons.shuffle_rounded,
                              selected: _direction == 'mixed',
                              onTap: () => _setDirection('mixed'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Limit Chips
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.format_list_numbered_rounded,
                                color: Color(0xFF38BDF8),
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Savollar soni',
                                style: TextStyle(
                                  color: AppColors.textSecondary(context),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            _reviewLimit == 9999 ? 'Barchasi' : '$_reviewLimit ta',
                            style: const TextStyle(
                              color: Color(0xFF38BDF8),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final count in [10, 20, 30, 50, 100]) ...[
                              _CountChip(
                                label: '$count',
                                selected: _reviewLimit == count,
                                onTap: () => _setReviewLimit(count),
                              ),
                              const SizedBox(width: 8),
                            ],
                            _CountChip(
                              label: 'Barchasi',
                              icon: Icons.all_inclusive_rounded,
                              selected: _reviewLimit == 9999,
                              onTap: () => _setReviewLimit(9999),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // 4. QUIZ MODES GRID
                _ModeHeroCard(
                  title: 'Klassik Test',
                  subtitle: '4 ta variantli tezkor viktorina',
                  badge: 'Eng ommabop',
                  icon: Icons.quiz_rounded,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2563EB), Color(0xFF06B6D4)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  onTap: () => _openQuiz('multiple_choice'),
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: _ModeMiniCard(
                        title: 'Yozish mashqi',
                        subtitle: 'Imlo va yozish',
                        icon: Icons.keyboard_rounded,
                        color: const Color(0xFF10B981),
                        onTap: _openTyping,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ModeMiniCard(
                        title: 'Flashcardlar',
                        subtitle: '3D Xotira kartalari',
                        icon: Icons.style_rounded,
                        color: const Color(0xFFF59E0B),
                        onTap: _openFlashcard,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: _ModeMiniCard(
                        title: 'Moslashtirish',
                        subtitle: 'So\'z juftliklari',
                        icon: Icons.extension_rounded,
                        color: const Color(0xFF8B5CF6),
                        onTap: _openMatch,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ModeMiniCard(
                        title: '1v1 Jang',
                        subtitle: 'Duel bellashuv',
                        icon: Icons.sports_mma_rounded,
                        color: const Color(0xFFE11D48),
                        onTap: _openBattle,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  LessonModel? _selectedLesson(List<LessonModel> lessons) {
    if (lessons.isEmpty) return null;
    final current = _lesson;
    if (current != null && lessons.any((item) => item.id == current.id)) {
      return current;
    }
    if (_savedLessonId != null) {
      final saved = lessons.where((item) => item.id == _savedLessonId).firstOrNull;
      if (saved != null) {
        _lesson = saved;
        return saved;
      }
    }
    _lesson = lessons.first;
    return _lesson;
  }

  Future<void> _pickLesson(List<LessonModel> lessons) async {
    final result = await showLessonPickerSheet(
      context: context,
      lessons: lessons,
      selectedLesson: _lesson,
    );
    final picked = result?.lesson;
    if (picked != null && mounted) {
      setState(() => _lesson = picked);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('quiz_saved_lesson_id', picked.id);
    }
  }

  void _openQuiz(String mode) {
    final lesson = _lesson;
    AudioHapticService.instance.lightImpact();
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => MultipleChoiceQuizScreen(
          lesson: lesson ??
              const LessonModel(
                id: 0,
                userId: 0,
                title: 'Barcha so\'zlar',
                description: '',
                category: 'General',
                wordCount: 0,
                createdAt: '',
              ),
          mode: mode,
          direction: _direction,
          reviewLimit: _reviewLimit,
          scope: _scope,
          quizService: widget.quizService,
          onProfileChanged: widget.onProfileChanged,
        ),
      ),
    );
  }

  void _openTyping() {
    final lesson = _lesson;
    AudioHapticService.instance.lightImpact();
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => TypingTestScreen(
          lesson: lesson ??
              const LessonModel(
                id: 0,
                userId: 0,
                title: 'Barcha so\'zlar',
                description: '',
                category: 'General',
                wordCount: 0,
                createdAt: '',
              ),
          quizService: widget.quizService,
          onProfileChanged: widget.onProfileChanged,
          direction: _direction == 'eng_to_uz' ? 'uz_to_eng' : 'eng_to_uz',
          scope: _scope,
          reviewLimit: _reviewLimit,
        ),
      ),
    );
  }

  void _openFlashcard() {
    final lesson = _lesson;
    if (lesson == null) return;
    AudioHapticService.instance.lightImpact();
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => FlashcardScreen(lesson: lesson, wordService: widget.wordService),
      ),
    );
  }

  void _openMatch() {
    final lesson = _lesson;
    if (lesson == null) return;
    AudioHapticService.instance.lightImpact();
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => MatchWordsScreen(lesson: lesson, wordService: widget.wordService),
      ),
    );
  }

  void _openBattle() {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => BattleLobbyScreen(
          lessonService: widget.lessonService,
          battleService: widget.battleService,
          initialLesson: _lesson,
          initialDirection: _direction,
        ),
      ),
    );
  }
}

class _ScopePill extends StatelessWidget {
  const _ScopePill({
    required this.title,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF8B5CF6) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? Colors.white : AppColors.textSecondary(context),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: selected ? Colors.white : AppColors.textSecondary(context),
                fontSize: 14,
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LessonSelectCard extends StatelessWidget {
  const _LessonSelectCard({
    required this.lesson,
    required this.onTap,
  });

  final LessonModel? lesson;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.glassSurface(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.book_rounded,
                color: Color(0xFF8B5CF6),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lesson?.title ?? 'Darsni tanlang',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textPrimary(context),
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    lesson != null ? '${lesson!.wordCount} ta so\'z • ${lesson!.category}' : 'Tanlash uchun bosing',
                    style: TextStyle(
                      color: AppColors.textSecondary(context),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.isDark(context)
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'O\'zgartirish',
                style: TextStyle(
                  color: Color(0xFF8B5CF6),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF10B981).withValues(alpha: 0.2)
              : (AppColors.isDark(context) ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.04)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? const Color(0xFF10B981) : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 13,
                color: selected ? const Color(0xFF10B981) : AppColors.textSecondary(context),
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                color: selected ? const Color(0xFF10B981) : AppColors.textSecondary(context),
                fontSize: 12,
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF38BDF8).withValues(alpha: 0.25)
              : (AppColors.isDark(context) ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? const Color(0xFF38BDF8) : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: selected ? const Color(0xFF38BDF8) : AppColors.textSecondary(context),
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                color: selected ? const Color(0xFF38BDF8) : AppColors.textSecondary(context),
                fontSize: 13,
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeHeroCard extends StatelessWidget {
  const _ModeHeroCard({
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String badge;
  final IconData icon;
  final Gradient gradient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2563EB).withValues(alpha: 0.25),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: Colors.white, size: 34),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          badge,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Color(0xFF2563EB),
                size: 24,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeMiniCard extends StatelessWidget {
  const _ModeMiniCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 105,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.glassSurface(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: color.withValues(alpha: 0.25),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                Icon(
                  Icons.arrow_forward_rounded,
                  color: color.withValues(alpha: 0.8),
                  size: 16,
                ),
              ],
            ),
            const Spacer(),
            Text(
              title,
              style: TextStyle(
                color: AppColors.textPrimary(context),
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.textSecondary(context),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuizHubSkeleton extends StatelessWidget {
  const _QuizHubSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        ShimmerBox(
          width: double.infinity,
          height: 54,
          borderRadius: 16,
        ),
        SizedBox(height: 14),
        ShimmerBox(
          width: double.infinity,
          height: 140,
          borderRadius: 18,
        ),
        SizedBox(height: 14),
        ShimmerBox(
          width: double.infinity,
          height: 110,
          borderRadius: 22,
        ),
      ],
    );
  }
}
