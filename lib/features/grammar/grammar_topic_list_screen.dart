import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/shimmer_loading.dart';
import '../../core/widgets/state_views.dart';
import '../../models/api_models.dart';
import '../../services/grammar_service.dart';
import 'grammar_lesson_screen.dart';

class GrammarTopicListScreen extends StatefulWidget {
  const GrammarTopicListScreen({
    required this.service,
    required this.level,
    required this.onProfileChanged,
    super.key,
  });

  final GrammarService service;
  final GrammarLevelModel level;
  final ValueChanged<UserModel> onProfileChanged;

  @override
  State<GrammarTopicListScreen> createState() => _GrammarTopicListScreenState();
}

class _GrammarTopicListScreenState extends State<GrammarTopicListScreen> {
  late Future<List<GrammarTopicModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.service.topics(widget.level.code);
  }

  void _reload() {
    final future = widget.service.topics(widget.level.code);
    setState(() {
      _future = future;
    });
  }

  Future<void> _openTopic(GrammarTopicModel topic) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GrammarLessonScreen(
          service: widget.service,
          topicId: topic.id,
          lessonId: topic.lessonId,
          onProfileChanged: widget.onProfileChanged,
        ),
      ),
    );
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientBackground(
        child: FutureBuilder<List<GrammarTopicModel>>(
          future: _future,
          builder: (context, snapshot) {
            final topics = snapshot.data ?? [];
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
                        '${widget.level.code} • ${widget.level.titleUz}',
                        style: AppTextStyles.titleFor(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (snapshot.connectionState != ConnectionState.done)
                  const ShimmerLoadingList(itemCount: 6)
                else if (snapshot.hasError)
                  ErrorStateView(message: snapshot.error!, onRetry: _reload)
                else if (topics.isEmpty)
                  const EmptyStateView(
                    icon: Icons.school_outlined,
                    message: 'Bu darajada hali grammatika mavzulari yo‘q.',
                  )
                else
                  for (var i = 0; i < topics.length; i++) ...[
                    _TopicPathNode(
                      topic: topics[i],
                      index: i + 1,
                      onTap: () => _openTopic(topics[i]),
                    ),
                    if (i != topics.length - 1) const _TopicConnector(),
                  ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TopicPathNode extends StatelessWidget {
  const _TopicPathNode({
    required this.topic,
    required this.index,
    required this.onTap,
  });

  final GrammarTopicModel topic;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = topic.completed
        ? AppColors.green
        : topic.inProgress
        ? AppColors.gold
        : AppColors.blue;
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(15),
      child: Row(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: color.withValues(alpha: .14),
            child: topic.completed
                ? Icon(Icons.check_rounded, color: color)
                : Text(
                    '$index',
                    style: TextStyle(color: color, fontWeight: FontWeight.w900),
                  ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(topic.title, style: AppTextStyles.sectionFor(context)),
                const SizedBox(height: 4),
                Text(
                  '${topic.durationMinutes} daqiqa • ${topic.exerciseCount} mashq',
                  style: AppTextStyles.captionFor(context),
                ),
                if (topic.progressPercent > 0) ...[
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    minHeight: 6,
                    value: topic.progressPercent / 100,
                    color: color,
                    backgroundColor: color.withValues(alpha: .13),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ],
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }
}

class _TopicConnector extends StatelessWidget {
  const _TopicConnector();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 44),
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
