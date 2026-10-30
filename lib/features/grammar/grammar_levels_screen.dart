import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/shimmer_loading.dart';
import '../../core/widgets/state_views.dart';
import '../../models/api_models.dart';
import '../../services/ai_service.dart';
import '../../services/grammar_service.dart';
import 'grammar_admin_review_screen.dart';
import 'grammar_topic_list_screen.dart';

class GrammarLevelsScreen extends StatefulWidget {
  const GrammarLevelsScreen({
    required this.service,
    required this.aiService,
    required this.currentUser,
    required this.onProfileChanged,
    super.key,
  });

  final GrammarService service;
  final AiService aiService;
  final UserModel currentUser;
  final ValueChanged<UserModel> onProfileChanged;

  @override
  State<GrammarLevelsScreen> createState() => _GrammarLevelsScreenState();
}

class _GrammarLevelsScreenState extends State<GrammarLevelsScreen> {
  late Future<List<GrammarLevelModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.service.levels();
  }

  void _reload() {
    final future = widget.service.levels();
    setState(() {
      _future = future;
    });
  }

  Future<void> _openAdminGenerator() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GrammarAdminReviewScreen(
          aiService: widget.aiService,
          grammarService: widget.service,
        ),
      ),
    );
    _reload();
  }

  Future<void> _openLevel(GrammarLevelModel level) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GrammarTopicListScreen(
          service: widget.service,
          level: level,
          onProfileChanged: widget.onProfileChanged,
        ),
      ),
    );
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      body: GradientBackground(
        child: FutureBuilder<List<GrammarLevelModel>>(
          future: _future,
          builder: (context, snapshot) {
            final levels = snapshot.data ?? [];
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 34),
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
                        l10n.t('grammar.title'),
                        style: AppTextStyles.titleFor(context),
                      ),
                    ),
                    if (widget.currentUser.role == 'admin' ||
                        widget.currentUser.role == 'teacher')
                      IconButton.filledTonal(
                        tooltip: 'AI grammar',
                        onPressed: _openAdminGenerator,
                        icon: const Icon(Icons.auto_awesome_rounded),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.t('grammar.subtitle'),
                  style: AppTextStyles.captionFor(context),
                ),
                const SizedBox(height: 16),
                if (snapshot.connectionState != ConnectionState.done)
                  const ShimmerLoadingList(itemCount: 6)
                else if (snapshot.hasError)
                  ErrorStateView(message: snapshot.error!, onRetry: _reload)
                else if (levels.isEmpty)
                  EmptyStateView(
                    icon: Icons.school_outlined,
                    message: l10n.t('grammar.empty'),
                  )
                else
                  for (var i = 0; i < levels.length; i++) ...[
                    _LevelPathCard(
                      level: levels[i],
                      active:
                          levels[i].progressPercent < 100 &&
                          (i == 0 || levels[i - 1].progressPercent >= 100),
                      onTap: () => _openLevel(levels[i]),
                    ),
                    if (i != levels.length - 1) const _PathConnector(),
                  ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _LevelPathCard extends StatelessWidget {
  const _LevelPathCard({
    required this.level,
    required this.active,
    required this.onTap,
  });

  final GrammarLevelModel level;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final completed = level.progressPercent >= 100;
    final color = completed
        ? AppColors.green
        : active
        ? AppColors.blue
        : AppColors.purple;
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              level.code,
              style: AppTextStyles.titleFor(context).copyWith(color: color),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(level.titleUz, style: AppTextStyles.sectionFor(context)),
                const SizedBox(height: 4),
                Text(
                  '${level.completedCount}/${level.topicCount} mavzu • ${level.progressPercent}%',
                  style: AppTextStyles.captionFor(context),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    minHeight: 7,
                    value: level.progressPercent / 100,
                    color: color,
                    backgroundColor: color.withValues(alpha: .12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Icon(
            completed
                ? Icons.check_circle_rounded
                : Icons.chevron_right_rounded,
            color: color,
          ),
        ],
      ),
    );
  }
}

class _PathConnector extends StatelessWidget {
  const _PathConnector();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 3,
        height: 18,
        decoration: BoxDecoration(
          color: AppColors.border,
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}
