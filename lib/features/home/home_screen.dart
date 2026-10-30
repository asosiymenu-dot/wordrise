import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/user_avatar.dart';
import '../../models/api_models.dart';
import '../../services/smart_learn_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    required this.user,
    this.stats,
    required this.smartLearnService,
    required this.onStartSmartLearn,
    required this.onStartQuiz,
    required this.onStartDueReviews,
    required this.onStartMistakes,
    required this.onOpenBadges,
    required this.onOpenStarred,
    required this.onOpenBattle,
    required this.onOpenLeaderboard,
    required this.onOpenLessons,
    required this.onOpenProfile,
    required this.onOpenMessages,
    super.key,
  });

  final UserModel user;
  final ProfileStatsModel? stats;
  final SmartLearnService smartLearnService;
  final Future<void> Function() onStartSmartLearn;
  final VoidCallback onStartQuiz;
  final VoidCallback onStartDueReviews;
  final VoidCallback onStartMistakes;
  final VoidCallback onOpenBadges;
  final VoidCallback onOpenStarred;
  final VoidCallback onOpenBattle;
  final VoidCallback onOpenLeaderboard;
  final VoidCallback onOpenLessons;
  final VoidCallback onOpenProfile;
  final VoidCallback onOpenMessages;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final progressValue = (stats?.progressPercentage ?? 0) / 100.0;
    final wordsLeft = (stats?.totalWords ?? 0) - (stats?.masteredWords ?? 0);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
              children: [
                _TopDashboard(
              user: user,
              onOpenProfile: onOpenProfile,
              onOpenMessages: onOpenMessages,
              onOpenLeaderboard: onOpenLeaderboard,
              onOpenBadges: onOpenBadges,
            ),
            const SizedBox(height: 16),
            _ProgressCard(
              streak: user.streak,
              progressPercentage: stats?.progressPercentage ?? 0,
              progressValue: progressValue,
              wordsLeft: wordsLeft > 0 ? wordsLeft : 0,
              masteredWords: stats?.masteredWords ?? user.totalLearned,
              totalWords: stats?.totalWords ?? 0,
              user: user,
              onStartLearn: () => onStartSmartLearn(),
            ),
            const SizedBox(height: 16),
            _MainQuizHeroCard(
              totalWords: stats?.totalWords ?? 0,
              onTap: onStartQuiz,
            ),
            const SizedBox(height: 14),
            _FullWidthBattleCard(
              title: l10n.t('home.battleTitle'),
              subtitle: l10n.t('home.battleSubtitle'),
              icon: Icons.sports_mma_rounded,
              onTap: onOpenBattle,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _GridItem(
                    title: l10n.t('home.dueReviewsTitle'),
                    icon: Icons.checklist_rtl_rounded,
                    color: AppColors.glassSurface(context),
                    iconColor: Colors.lightBlueAccent,
                    onTap: onStartDueReviews,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _GridItem(
                    title: l10n.t('home.mistakesTitle'),
                    icon: Icons.heart_broken_rounded,
                    color: AppColors.glassSurface(context),
                    iconColor: AppColors.softRed,
                    onTap: onStartMistakes,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _GridItem(
                    title: l10n.t('lessons.title'),
                    icon: Icons.my_library_books_rounded,
                    color: AppColors.glassSurface(context),
                    iconColor: Colors.orangeAccent,
                    onTap: onOpenLessons,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _GridItem(
                    title: l10n.t('words.starredTitle'),
                    icon: Icons.bookmark_rounded,
                    color: AppColors.glassSurface(context),
                    iconColor: Colors.amber,
                    onTap: onOpenStarred,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _GridItem(
                    title: 'Aqlli Mashg‘ulot',
                    icon: Icons.auto_awesome_rounded,
                    color: AppColors.glassSurface(context),
                    iconColor: Colors.tealAccent,
                    onTap: () => onStartSmartLearn(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _GridItem(
                    title: 'Nishonlar va Yutuqlar',
                    icon: Icons.emoji_events_rounded,
                    color: AppColors.glassSurface(context),
                    iconColor: Colors.purpleAccent,
                    onTap: onOpenBadges,
                  ),
                ),
              ],
            ),
          ],
        ),
        ),
        ),
      ),
    );
  }
}

class _TopDashboard extends StatelessWidget {
  const _TopDashboard({
    required this.user,
    required this.onOpenProfile,
    required this.onOpenMessages,
    required this.onOpenLeaderboard,
    required this.onOpenBadges,
  });

  final UserModel user;
  final VoidCallback onOpenProfile;
  final VoidCallback onOpenMessages;
  final VoidCallback onOpenLeaderboard;
  final VoidCallback onOpenBadges;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        children: [
          UserAvatar(
            name: user.name,
            avatarUrl: user.avatar,
            size: 48,
            online: true,
            border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.5), width: 2),
            onTap: onOpenProfile,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: onOpenProfile,
              behavior: HitTestBehavior.opaque,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          user.name,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.textPrimary(context),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.verified_rounded, color: Colors.blueAccent, size: 16),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.military_tech_rounded, color: Colors.amber, size: 15),
                      const SizedBox(width: 4),
                      Text(
                        'LVL ${user.level} • ${user.xp} XP',
                        style: const TextStyle(
                          color: Colors.amber,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: onOpenLeaderboard,
                tooltip: 'Peshqadamlar',
                icon: const Icon(Icons.emoji_events_rounded, color: Colors.amber, size: 24),
              ),
              IconButton(
                onPressed: onOpenMessages,
                tooltip: 'Xabarlar',
                icon: Icon(Icons.mail_outline_rounded, color: AppColors.textSecondary(context)),
              ),
              IconButton(
                onPressed: onOpenProfile,
                tooltip: 'Sozlamalar',
                icon: Icon(Icons.settings_outlined, color: AppColors.textSecondary(context)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MainQuizHeroCard extends StatelessWidget {
  const _MainQuizHeroCard({
    required this.totalWords,
    required this.onTap,
  });

  final int totalWords;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6366F1), Color(0xFF8B5CF6), Color(0xFF9333EA)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6366F1).withValues(alpha: 0.35),
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
                color: Colors.white.withValues(alpha: 0.22),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.5),
              ),
              child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 34),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Flexible(
                        child: Text(
                          'Random Viktorina',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.local_fire_department_rounded, color: Colors.amberAccent, size: 12),
                            SizedBox(width: 2),
                            Text(
                              'HOT',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    totalWords > 0
                        ? '$totalWords ta so‘z • Barcha mavzular / Rejimlar'
                        : 'Barcha mavzular & Tezkor testlar',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.streak,
    required this.progressPercentage,
    required this.progressValue,
    required this.wordsLeft,
    required this.masteredWords,
    required this.totalWords,
    required this.user,
    required this.onStartLearn,
  });

  final int streak;
  final int progressPercentage;
  final double progressValue;
  final int wordsLeft;
  final int masteredWords;
  final int totalWords;
  final UserModel user;
  final VoidCallback onStartLearn;

  void _showProgressDetails(BuildContext context) {
    final currentLvl = user.level;
    final lvlProgress = levelProgress(user.xp);
    final title = levelTitle(user.level);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final isDark = AppColors.isDark(ctx);
        return Container(
          color: Theme.of(ctx).scaffoldBackgroundColor,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.analytics_rounded, color: Colors.blueAccent, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'O‘quv Jarayoni Tahlili',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Barcha so‘zlar va daraja statistikasi',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Level Progress
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.military_tech_rounded, color: Colors.amber, size: 20),
                            const SizedBox(width: 6),
                            Text(
                              'Daraja $currentLvl • $title',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ],
                        ),
                        Text(
                          '${user.xp} XP',
                          style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: lvlProgress.clamp(0.0, 1.0),
                        minHeight: 8,
                        backgroundColor: isDark ? Colors.white10 : Colors.black12,
                        valueColor: const AlwaysStoppedAnimation(Colors.blueAccent),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Word Breakdown Row
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: Colors.green, size: 22),
                          const SizedBox(height: 6),
                          Text(
                            '$masteredWords',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                          ),
                          const Text('O‘zlashtirilgan', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.auto_stories_rounded, color: Colors.orange, size: 22),
                          const SizedBox(height: 6),
                          Text(
                            '$wordsLeft',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange),
                          ),
                          const Text('Qolgan so‘zlar', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.layers_rounded, color: Colors.blue, size: 22),
                          const SizedBox(height: 6),
                          Text(
                            '$totalWords',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
                          ),
                          const Text('Jami so‘zlar', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Action button
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  onStartLearn();
                },
                icon: const Icon(Icons.auto_awesome_rounded, color: Colors.white),
                label: const Text('Aqlli Mashg‘ulotni Boshlash'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);

    return InkWell(
      onTap: () => _showProgressDetails(context),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black12,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.trending_up_rounded, color: Colors.blueAccent, size: 18),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Umumiy Progress',
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black87,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.local_fire_department_rounded, color: Colors.orange, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '$streak kun',
                        style: const TextStyle(
                          color: Colors.orange,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Big % & Words Remaining
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '$progressPercentage',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1,
                      ),
                    ),
                    Text(
                      '%',
                      style: TextStyle(
                        color: Colors.blueAccent,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Text(
                  '$masteredWords / $totalWords so‘z',
                  style: TextStyle(
                    color: isDark ? Colors.white60 : Colors.black54,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Multi-segment modern gradient progress bar
            Container(
              height: 10,
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Stack(
                children: [
                  FractionallySizedBox(
                    widthFactor: progressValue.clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF10B981), Color(0xFF06B6D4), Color(0xFF3B82F6)],
                        ),
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF06B6D4).withValues(alpha: 0.4),
                            blurRadius: 6,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Bottom quick breakdown chips
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'O‘rganildi: $masteredWords',
                      style: TextStyle(
                        color: isDark ? Colors.white60 : Colors.black54,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF94A3B8),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Qolgan: $wordsLeft',
                      style: TextStyle(
                        color: isDark ? Colors.white60 : Colors.black54,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text(
                      'Batafsil',
                      style: const TextStyle(
                        color: Colors.blueAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: Colors.blueAccent, size: 16),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


class _FullWidthBattleCard extends StatelessWidget {
  const _FullWidthBattleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFE11D48), Color(0xFFF97316)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE11D48).withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 30),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 18),
          ],
        ),
      ),
    );
  }
}

class _GridItem extends StatelessWidget {
  const _GridItem({
    required this.title,
    required this.icon,
    required this.color,
    required this.iconColor,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final Color color;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 75,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 26),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                maxLines: 2,
                style: TextStyle(
                  color: AppColors.textPrimary(context),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
