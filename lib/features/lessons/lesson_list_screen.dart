import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/word_import_parser.dart';
import '../../core/utils/error_message.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/lesson_card.dart';
import '../../core/widgets/ios_selection_sheet.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/state_views.dart';
import '../../models/api_models.dart';
import '../../services/ai_service.dart';
import '../../services/lesson_service.dart';
import '../../services/word_service.dart';
import '../../services/websocket_service.dart';
import 'ai_lesson_screen.dart';
import 'create_lesson_sheet.dart';
import 'discover_lessons_screen.dart';
import 'lesson_share_import_sheet.dart';
import 'word_list_screen.dart';

class LessonListScreen extends StatefulWidget {
  const LessonListScreen({
    required this.lessonService,
    required this.wordService,
    required this.aiService,
    required this.websocketService,
    required this.currentUser,
    super.key,
  });

  final LessonService lessonService;
  final WordService wordService;
  final AiService aiService;
  final WebSocketService websocketService;
  final UserModel currentUser;

  @override
  State<LessonListScreen> createState() => _LessonListScreenState();
}

class _LessonListScreenState extends State<LessonListScreen> {
  List<LessonModel>? _lessons;
  String? _error;
  bool _hasMore = false;
  bool _loadingOlder = false;
  final _search = TextEditingController();
  final _scroll = ScrollController();
  String _query = '';
  StreamSubscription? _wsSubscription;

  @override
  void initState() {
    super.initState();
    _reload();
    _scroll.addListener(_handleScroll);
    
    _wsSubscription = widget.websocketService.events.listen((event) {
      if (!mounted) return;
      final type = event['type'] as String?;
      if (type == 'reconnected') {
        _reload();
      } else if (type == 'lesson_added' && event['data'] != null) {
        final newLesson = LessonModel.fromJson(event['data']);
        setState(() {
          if (_lessons != null && !_lessons!.any((l) => l.id == newLesson.id)) {
            _lessons = [newLesson, ..._lessons!];
          }
        });
      } else if (type == 'lesson_deleted' && event['data'] != null) {
        final lessonId = event['data']['lesson_id'] as int?;
        if (lessonId != null) {
          setState(() {
            _lessons?.removeWhere((l) => l.id == lessonId);
          });
        }
      } else if (type == 'lesson_updated' && event['data'] != null) {
        final updated = LessonModel.fromJson(event['data']);
        setState(() {
          if (_lessons != null) {
            final index = _lessons!.indexWhere((l) => l.id == updated.id);
            if (index != -1) {
              _lessons![index] = updated;
            }
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _scroll.removeListener(_handleScroll);
    _scroll.dispose();
    _wsSubscription?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (_scroll.hasClients && _scroll.position.extentAfter < 180) {
      unawaited(_loadOlder());
    }
  }

  Future<void> _reload() async {
    setState(() => _error = null);
    try {
      final page = await widget.lessonService.fetchPage(limit: 50);
      if (mounted) {
        setState(() {
          _lessons = page.lessons;
          _hasMore = page.hasMore;
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

  Future<void> _loadOlder() async {
    if (_loadingOlder || !_hasMore || _lessons == null || _lessons!.isEmpty) return;
    _loadingOlder = true;
    try {
      final lastId = _lessons!.last.id;
      final page = await widget.lessonService.fetchPage(limit: 50, afterId: lastId);
      if (!mounted) return;
      setState(() {
        _lessons!.addAll(page.lessons);
        _hasMore = page.hasMore;
      });
    } catch (_) {
    } finally {
      _loadingOlder = false;
    }
  }

  Future<void> _createLesson() async {
    final input = await showCreateLessonSheet(context);
    if (input == null) return;
    try {
      await widget.lessonService.create(
        title: input.title,
        description: input.description,
        category: input.category,
      );
      if (mounted) _reload();
    } on Object catch (error) {
      _showError(error);
    }
  }

  Future<void> _editLesson(LessonModel lesson) async {
    final input = await showCreateLessonSheet(context, initial: lesson);
    if (input == null) return;
    try {
      await widget.lessonService.update(
        id: lesson.id,
        title: input.title,
        description: input.description,
        category: input.category,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.t('lessons.updated'))),
      );
      _reload();
    } on Object catch (error) {
      _showError(error);
    }
  }

  Future<void> _deleteLesson(LessonModel lesson) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.t('lessons.deleteTitle')),
        content: Text(
          context.l10n.f('lessons.deleteMessage', {'lesson': lesson.title}),
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
    if (confirmed != true) return;
    try {
      await widget.lessonService.delete(lesson.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.t('lessons.deleted'))),
      );
      _reload();
    } on Object catch (error) {
      _showError(error);
    }
  }

  Future<void> _exportLesson(LessonModel lesson) async {
    try {
      final bundle = await widget.lessonService.exportBundle(lesson.id);
      if (!mounted) return;
      final format = await _showExportLessonSheet(context);
      if (format == null) return;
      final text = format == _LessonExportFormat.json
          ? const JsonEncoder.withIndent('  ').convert(bundle)
          : _bundleToTableText(bundle);
      await Clipboard.setData(ClipboardData(text: text));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            format == _LessonExportFormat.json
                ? context.l10n.t('lessons.exportedJson')
                : context.l10n.t('lessons.exportedTable'),
          ),
        ),
      );
    } on Object catch (error) {
      _showError(error);
    }
  }

  Future<void> _importLesson() async {
    final bundle = await showImportLessonSheet(context);
    if (bundle == null) return;
    try {
      await widget.lessonService.importBundle(bundle);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.t('lessons.imported'))),
      );
      _reload();
    } on Object catch (error) {
      _showError(error);
    }
  }

  Future<void> _createAiLesson() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AiLessonScreen(
          aiService: widget.aiService,
          lessonService: widget.lessonService,
          wordService: widget.wordService,
        ),
      ),
    );
    if (changed == true) _reload();
  }

  Future<void> _openDiscover() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            DiscoverLessonsScreen(lessonService: widget.lessonService),
      ),
    );
    if (mounted) _reload();
  }

  Future<void> _shareLesson(LessonModel lesson) async {
    final l10n = context.l10n;
    try {
      final share = await widget.lessonService.shareLesson(lesson.id);
      final text = l10n.f('share.message', {
        'lesson': lesson.title,
        'code': share.shareCode,
        'url': share.shareUrl,
        'appLink': share.appLink,
      });
      await SharePlus.instance.share(ShareParams(text: text));
      if (mounted) _reload();
    } on Object catch (error) {
      _showError(error);
    }
  }

  bool _canManage(LessonModel lesson) {
    return lesson.userId == widget.currentUser.id ||
        widget.currentUser.role == 'admin';
  }

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(userFacingError(context, error))));
  }

  Future<void> _showListActions() async {
    final action = await showIosSelectionSheet<_LessonListAction>(
      context: context,
      title: context.l10n.t('common.actions'),
      selected: null,
      options: [
        IosSelectionOption(
          value: _LessonListAction.discover,
          label: context.l10n.t('discover.title'),
          icon: CupertinoIcons.compass,
        ),
        IosSelectionOption(
          value: _LessonListAction.ai,
          label: context.l10n.t('ai.lessonTitle'),
          icon: CupertinoIcons.sparkles,
        ),
        IosSelectionOption(
          value: _LessonListAction.import,
          label: context.l10n.t('lessons.import'),
          icon: CupertinoIcons.arrow_down_doc,
        ),
      ],
    );
    switch (action) {
      case _LessonListAction.discover:
        await _openDiscover();
      case _LessonListAction.ai:
        await _createAiLesson();
      case _LessonListAction.import:
        await _importLesson();
      case null:
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return GradientBackground(
      child: RefreshIndicator(
        onRefresh: _reload,
        child: Builder(
          builder: (context) {
            final lessons = _lessons ?? [];
            final normalizedQuery = _query.trim().toLowerCase();
            final visibleLessons = normalizedQuery.isEmpty
                ? lessons
                : lessons.where((lesson) {
                    return lesson.title.toLowerCase().contains(
                          normalizedQuery,
                        ) ||
                        lesson.description.toLowerCase().contains(
                          normalizedQuery,
                        ) ||
                        lesson.category.toLowerCase().contains(normalizedQuery);
                  }).toList();
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
                  itemCount: 4 + visibleLessons.length + (_loadingOlder ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  l10n.t('lessons.title'),
                                  style: AppTextStyles.displayFor(context),
                                ),
                              ),
                              CupertinoButton(
                                padding: const EdgeInsets.all(10),
                                onPressed: _showListActions,
                                child: const Icon(CupertinoIcons.ellipsis),
                              ),
                              const SizedBox(width: 8),
                              IconButton.filled(
                                onPressed: _createLesson,
                                icon: const Icon(Icons.add_rounded),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n.t('lessons.subtitle'),
                            style: AppTextStyles.captionFor(context),
                          ),
                        ],
                      );
                    }
                    if (index == 1) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 16, bottom: 16),
                        child: AppTextField(
                          controller: _search,
                          label: l10n.t('lessons.search'),
                          icon: Icons.search_rounded,
                          onChanged: (value) => setState(() => _query = value),
                        ),
                      );
                    }
                    if (index == 2) {
                      if (_lessons == null && _error == null) {
                        return const LoadingStateView();
                      } else if (_error != null) {
                        return ErrorStateView(message: _error!, onRetry: _reload);
                      } else if (lessons.isEmpty) {
                        return EmptyStateView(
                          icon: Icons.menu_book_outlined,
                          message: l10n.t('lessons.empty'),
                        );
                      } else if (visibleLessons.isEmpty) {
                        return EmptyStateView(
                          icon: Icons.search_off_rounded,
                          message: l10n.t('lessons.searchEmpty'),
                        );
                      }
                      return const SizedBox.shrink();
                    }
                    
                    if (index == 3 + visibleLessons.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(child: CupertinoActivityIndicator()),
                      );
                    }

                    final lessonIndex = index - 3;
                    if (lessonIndex >= 0 && lessonIndex < visibleLessons.length) {
                      final lesson = visibleLessons[lessonIndex];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: LessonCard(
                          lesson: lesson,
                          onEdit: _canManage(lesson) ? () => _editLesson(lesson) : null,
                          onExport: () => _exportLesson(lesson),
                          onShare: _canManage(lesson) ? () => _shareLesson(lesson) : null,
                          onDelete: _canManage(lesson) ? () => _deleteLesson(lesson) : null,
                          onTap: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => WordListScreen(
                                  lesson: lesson,
                                  wordService: widget.wordService,
                                  aiService: widget.aiService,
                                  websocketService: widget.websocketService,
                                  canManage: _canManage(lesson),
                                ),
                              ),
                            );
                            _reload();
                          },
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

enum _LessonListAction { discover, ai, import }

class LessonInput {
  const LessonInput({
    required this.title,
    required this.description,
    required this.category,
  });

  final String title;
  final String description;
  final String category;
}

Future<Map<String, dynamic>?> showImportLessonSheet(BuildContext context) {
  final code = TextEditingController();
  final title = TextEditingController();
  final category = TextEditingController(text: 'Imported');
  final description = TextEditingController();
  final words = TextEditingController();
  String? error;

  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.isDark(context)
                    ? AppColors.darkSurface
                    : Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(30),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    context.l10n.t('lessons.import'),
                    style: AppTextStyles.titleFor(context),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.t('lessons.importHint'),
                    style: AppTextStyles.captionFor(context),
                  ),
                  const SizedBox(height: 14),
                  AppTextField(
                    controller: code,
                    label: context.l10n.t('share.codeOrLink'),
                    icon: Icons.link_rounded,
                  ),
                  const SizedBox(height: 10),
                  FilledButton.tonalIcon(
                    onPressed: () {
                      final shareCode = extractLessonShareCode(code.text);
                      if (shareCode == null) {
                        setModalState(
                          () => error = context.l10n.t('share.invalidCode'),
                        );
                        return;
                      }
                      Navigator.of(context).pop({'share_code': shareCode});
                    },
                    icon: const Icon(Icons.download_rounded),
                    label: Text(context.l10n.t('share.importByCode')),
                  ),
                  const SizedBox(height: 14),
                  Divider(color: AppColors.divider(context)),
                  const SizedBox(height: 14),
                  AppTextField(
                    controller: title,
                    label: context.l10n.t('lessons.titleField'),
                    icon: Icons.menu_book_outlined,
                  ),
                  const SizedBox(height: 10),
                  AppTextField(
                    controller: category,
                    label: context.l10n.t('lessons.category'),
                    icon: Icons.category_outlined,
                  ),
                  const SizedBox(height: 10),
                  AppTextField(
                    controller: description,
                    label: context.l10n.t('lessons.description'),
                    icon: Icons.notes_rounded,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: () async {
                            final data = await Clipboard.getData('text/plain');
                            final text = data?.text;
                            if (text == null || text.trim().isEmpty) return;
                            setModalState(() => words.text = text);
                          },
                          icon: const Icon(Icons.content_paste_rounded),
                          label: Text(context.l10n.t('words.pasteClipboard')),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: () => setModalState(
                            () => words.text = sampleImportText(),
                          ),
                          icon: const Icon(Icons.auto_awesome_rounded),
                          label: Text(context.l10n.t('words.sample')),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: words,
                    minLines: 8,
                    maxLines: 12,
                    decoration: InputDecoration(
                      labelText: context.l10n.t('lessons.importWords'),
                      alignLabelWithHint: true,
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      error!,
                      style: AppTextStyles.captionFor(
                        context,
                      ).copyWith(color: AppColors.softRed),
                    ),
                  ],
                  const SizedBox(height: 16),
                  PrimaryButton(
                    label: context.l10n.t('lessons.importAction'),
                    icon: Icons.file_upload_outlined,
                    onPressed: () {
                      try {
                        final raw = words.text.trim();
                        if (raw.startsWith('{')) {
                          final decoded = jsonDecode(raw);
                          if (decoded is! Map<String, dynamic>) {
                            throw const FormatException(
                              'JSON object expected.',
                            );
                          }
                          Navigator.of(context).pop(decoded);
                          return;
                        }
                        final parsed = parseBulkWords(raw);
                        if (title.text.trim().isEmpty) {
                          throw FormatException(
                            context.l10n.t('lessons.titleRequired'),
                          );
                        }
                        Navigator.of(context).pop({
                          'lesson': {
                            'title': title.text.trim(),
                            'description': description.text.trim(),
                            'category': category.text.trim().isEmpty
                                ? 'Imported'
                                : category.text.trim(),
                          },
                          'words': parsed.map((item) => item.toJson()).toList(),
                        });
                      } on Object catch (parseError) {
                        setModalState(() => error = parseError.toString());
                      }
                    },
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  ).whenComplete(() {
    code.dispose();
    title.dispose();
    category.dispose();
    description.dispose();
    words.dispose();
  });
}

Future<_LessonExportFormat?> _showExportLessonSheet(BuildContext context) {
  return showIosSelectionSheet<_LessonExportFormat>(
    context: context,
    title: context.l10n.t('lessons.export'),
    selected: null,
    options: [
      IosSelectionOption(
        value: _LessonExportFormat.table,
        label: context.l10n.t('lessons.exportTable'),
        icon: CupertinoIcons.table,
      ),
      IosSelectionOption(
        value: _LessonExportFormat.json,
        label: context.l10n.t('lessons.exportJson'),
        icon: CupertinoIcons.chevron_left_slash_chevron_right,
      ),
    ],
  );
}

enum _LessonExportFormat { table, json }

String _bundleToTableText(Map<String, dynamic> bundle) {
  final words = (bundle['words'] as List? ?? []).whereType<Map>().toList();
  return words
      .map((word) {
        return [
          word['english_word']?.toString() ?? '',
          word['uzbek_translation']?.toString() ?? '',
          word['example_sentence']?.toString() ?? '',
          word['pronunciation']?.toString() ?? '',
        ].join('\t').trimRight();
      })
      .join('\n');
}

