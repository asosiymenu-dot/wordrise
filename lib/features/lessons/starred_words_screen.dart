import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/shimmer_loading.dart';
import '../../core/widgets/state_views.dart';
import '../../core/widgets/word_card.dart';
import '../../models/api_models.dart';
import '../../services/word_service.dart';

class StarredWordsScreen extends StatefulWidget {
  const StarredWordsScreen({required this.service, super.key});

  final WordService service;

  @override
  State<StarredWordsScreen> createState() => _StarredWordsScreenState();
}

class _StarredWordsScreenState extends State<StarredWordsScreen> {
  late Future<List<WordModel>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = widget.service.starred();
  }

  Future<void> _remove(WordModel word) async {
    try {
      await widget.service.setStarred(word.id, false);
      if (!mounted) return;
      setState(_reload);
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.t('common.networkError'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: FutureBuilder<List<WordModel>>(
            future: _future,
            builder: (context, snapshot) {
              final words = snapshot.data ?? [];
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
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
                          context.l10n.t('words.starredTitle'),
                          style: AppTextStyles.titleFor(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (snapshot.connectionState != ConnectionState.done)
                    const ShimmerLoadingList(itemCount: 5, compact: true)
                  else if (snapshot.hasError)
                    ErrorStateView(
                      message: context.l10n.t('common.networkError'),
                      onRetry: () => setState(_reload),
                    )
                  else if (words.isEmpty)
                    EmptyStateView(
                      icon: Icons.star_border_rounded,
                      message: context.l10n.t('words.starredEmpty'),
                    )
                  else
                    for (final word in words) ...[
                      WordCard(word: word, onToggleStar: (_) => _remove(word)),
                      const SizedBox(height: 10),
                    ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
