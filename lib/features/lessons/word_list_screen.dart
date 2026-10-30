import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/error_message.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/state_views.dart';
import '../../core/widgets/word_card.dart';
import '../../models/api_models.dart';
import '../../services/ai_service.dart';
import '../../services/word_service.dart';
import '../../services/websocket_service.dart';
import 'add_word_screen.dart';
import 'camera_word_import_screen.dart';

class WordListScreen extends StatefulWidget {
  const WordListScreen({
    required this.lesson,
    required this.wordService,
    required this.aiService,
    required this.websocketService,
    required this.canManage,
    super.key,
  });

  final LessonModel lesson;
  final WordService wordService;
  final AiService aiService;
  final WebSocketService websocketService;
  final bool canManage;

  @override
  State<WordListScreen> createState() => _WordListScreenState();
}

class _WordListScreenState extends State<WordListScreen> {
  List<WordModel>? _words;
  String? _error;
  StreamSubscription? _wsSubscription;

  @override
  void initState() {
    super.initState();
    _reload();
    _wsSubscription = widget.websocketService.events.listen((event) {
      if (!mounted) return;
      final type = event['type'] as String?;
      if (type == 'reconnected') {
        _reload();
        return;
      }
      
      final data = event['data'];
      if (data == null) return;
      
      final lessonId = data['lesson_id'] as int?;
      if (lessonId != widget.lesson.id) return;

      if (type == 'word_added' && data['word'] != null) {
        final newWord = WordModel.fromJson(data['word']);
        setState(() {
          if (_words != null && !_words!.any((w) => w.id == newWord.id)) {
            _words = [newWord, ..._words!];
          }
        });
      } else if (type == 'word_deleted') {
        final wordId = data['word_id'] as int?;
        if (wordId != null) {
          setState(() {
            _words?.removeWhere((w) => w.id == wordId);
          });
        }
      } else if (type == 'word_updated' && data['word'] != null) {
        final updated = WordModel.fromJson(data['word']);
        setState(() {
          if (_words != null) {
            final index = _words!.indexWhere((w) => w.id == updated.id);
            if (index != -1) {
              _words![index] = updated;
            }
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() => _error = null);
    try {
      final data = await widget.wordService.byLesson(widget.lesson.id);
      if (mounted) {
        setState(() {
          _words = data;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _openAddWord() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddWordScreen(
          lesson: widget.lesson,
          wordService: widget.wordService,
          aiService: widget.aiService,
        ),
      ),
    );
    if (changed == true) _reload();
  }

  Future<void> _editWord(WordModel word) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddWordScreen(
          lesson: widget.lesson,
          wordService: widget.wordService,
          aiService: widget.aiService,
          word: word,
        ),
      ),
    );
    if (changed == true) _reload();
  }

  Future<void> _openCameraImport() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CameraWordImportScreen(
          lesson: widget.lesson,
          aiService: widget.aiService,
          wordService: widget.wordService,
        ),
      ),
    );
    if (changed == true) _reload();
  }

  Future<void> _deleteWord(WordModel word) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.t('words.deleteTitle')),
        content: Text(
          context.l10n.f('words.deleteMessage', {'word': word.englishWord}),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.t('common.cancel')),
          ),
          FilledButton.tonalIcon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.delete_outline_rounded),
            label: Text(context.l10n.t('common.delete')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await widget.wordService.delete(word.id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.t('words.deleted'))));
      _reload();
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userFacingError(context, error))));
    }
  }

  Future<void> _exportWords(List<WordModel> words) async {
    final text = words
        .map((word) {
          return [
            word.englishWord,
            word.uzbekTranslation,
            word.exampleSentence,
            word.pronunciation,
          ].join('\t').trimRight();
        })
        .join('\n');
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.t('words.exported'))));
  }

  Future<void> _toggleStar(WordModel word, bool isStarred) async {
    final current = _words ?? [];
    setState(() {
      _words = [
        for (final item in current)
          item.id == word.id ? item.copyWith(isStarred: isStarred) : item,
      ];
    });
    try {
      await widget.wordService.setStarred(word.id, isStarred);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.t(isStarred ? 'words.starred' : 'words.unstarred'),
          ),
        ),
      );
    } on Object {
      if (!mounted) return;
      setState(() {
        _words = current;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.t('common.networkError'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      body: GradientBackground(
        child: RefreshIndicator(
          onRefresh: _reload,
          child: Builder(
            builder: (context) {
              final words = _words ?? [];
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
                          widget.lesson.title,
                          style: AppTextStyles.titleFor(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.f('words.list', {'category': widget.lesson.category}),
                    style: AppTextStyles.captionFor(context),
                  ),
                  const SizedBox(height: 14),
                  if (widget.canManage) ...[
                    Row(
                      children: [
                        Expanded(
                          child: PrimaryButton(
                            label: l10n.t('words.add'),
                            icon: Icons.playlist_add_rounded,
                            onPressed: _openAddWord,
                          ),
                        ),
                        const SizedBox(width: 10),
                        IconButton.filledTonal(
                          onPressed: _openCameraImport,
                          tooltip: l10n.t('cameraImport.title'),
                          icon: const Icon(Icons.document_scanner_outlined),
                        ),
                        const SizedBox(width: 6),
                        IconButton.filledTonal(
                          onPressed: words.isEmpty ? null : () => _exportWords(words),
                          tooltip: l10n.t('words.export'),
                          icon: const Icon(Icons.ios_share_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ] else if (words.isNotEmpty) ...[
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton.filledTonal(
                        onPressed: () => _exportWords(words),
                        tooltip: l10n.t('words.export'),
                        icon: const Icon(Icons.ios_share_rounded),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (_words == null && _error == null)
                    const LoadingStateView()
                  else if (_error != null)
                    ErrorStateView(message: _error!, onRetry: _reload)
                  else if (words.isEmpty)
                    EmptyStateView(
                      icon: Icons.translate_rounded,
                      message: l10n.t('words.empty'),
                    )
                  else
                    for (final word in words) ...[
                      WordCard(
                        word: word,
                        onToggleStar: (value) => _toggleStar(word, value),
                        onEdit: widget.canManage ? () => _editWord(word) : null,
                        onDelete: widget.canManage ? () => _deleteWord(word) : null,
                      ),
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
