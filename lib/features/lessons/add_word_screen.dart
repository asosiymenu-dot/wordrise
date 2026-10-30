import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/word_import_parser.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/state_views.dart';
import '../../models/api_models.dart';
import '../../services/ai_service.dart';
import '../../services/api_service.dart';
import '../../services/word_service.dart';

class AddWordScreen extends StatefulWidget {
  const AddWordScreen({
    required this.lesson,
    required this.wordService,
    required this.aiService,
    this.word,
    super.key,
  });

  final LessonModel lesson;
  final WordService wordService;
  final AiService aiService;
  final WordModel? word;

  @override
  State<AddWordScreen> createState() => _AddWordScreenState();
}

class _AddWordScreenState extends State<AddWordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _english = TextEditingController();
  final _uzbek = TextEditingController();
  final _example = TextEditingController();
  final _pronunciation = TextEditingController();
  final _bulk = TextEditingController();
  bool _bulkMode = false;
  bool _loading = false;
  bool _aiLoading = false;
  String? _error;

  bool get _editing => widget.word != null;

  @override
  void initState() {
    super.initState();
    final word = widget.word;
    if (word != null) {
      _english.text = word.englishWord;
      _uzbek.text = word.uzbekTranslation;
      _example.text = word.exampleSentence;
      _pronunciation.text = word.pronunciation;
    }
  }

  @override
  void dispose() {
    _english.dispose();
    _uzbek.dispose();
    _example.dispose();
    _pronunciation.dispose();
    _bulk.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (_bulkMode) {
        final words = parseBulkWords(_bulk.text);
        await widget.wordService.bulkCreate(
          lessonId: widget.lesson.id,
          words: words.map((item) => item.toJson()).toList(),
        );
      } else {
        if (!_formKey.currentState!.validate()) return;
        if (_editing) {
          await widget.wordService.update(
            id: widget.word!.id,
            englishWord: _english.text.trim(),
            uzbekTranslation: _uzbek.text.trim(),
            exampleSentence: _example.text.trim(),
            pronunciation: _pronunciation.text.trim(),
          );
        } else {
          await widget.wordService.create(
            lessonId: widget.lesson.id,
            englishWord: _english.text.trim(),
            uzbekTranslation: _uzbek.text.trim(),
            exampleSentence: _example.text.trim(),
            pronunciation: _pronunciation.text.trim(),
          );
        }
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    } on FormatException catch (error) {
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _fillWithAi() async {
    final word = _english.text.trim();
    if (word.isEmpty || _aiLoading) {
      setState(() => _error = context.l10n.t('ai.enterWord'));
      return;
    }
    setState(() {
      _aiLoading = true;
      _error = null;
    });
    try {
      final suggestion = await widget.aiService.suggestWord(word);
      if (!mounted) return;
      setState(() {
        _english.text = suggestion.englishWord.isEmpty
            ? word
            : suggestion.englishWord;
        _uzbek.text = suggestion.uzbekTranslation;
        _example.text = suggestion.exampleSentence;
        _pronunciation.text = suggestion.pronunciation;
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _aiLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final parsedCount = _bulkMode ? _safeParsedCount(_bulk.text) : 1;

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
                    _editing ? l10n.t('words.edit') : l10n.t('words.addMany'),
                    style: AppTextStyles.titleFor(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (!_editing) ...[
              SegmentedButton<bool>(
                selected: {_bulkMode},
                onSelectionChanged: (value) =>
                    setState(() => _bulkMode = value.first),
                segments: [
                  ButtonSegment(
                    value: false,
                    label: Text(l10n.t('words.single')),
                    icon: const Icon(Icons.add_rounded),
                  ),
                  ButtonSegment(
                    value: true,
                    label: Text(l10n.t('words.importTable')),
                    icon: const Icon(Icons.table_chart_outlined),
                  ),
                ],
              ),
              const SizedBox(height: 14),
            ],
            GlassCard(
              child: _bulkMode && !_editing
                  ? _bulkForm(parsedCount)
                  : _singleForm(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              ErrorStateView(message: _error!),
            ],
            const SizedBox(height: 16),
            PrimaryButton(
              label: _bulkMode
                  ? l10n.f('words.import', {'count': parsedCount})
                  : _editing
                  ? l10n.t('words.update')
                  : l10n.t('words.save'),
              icon: _bulkMode
                  ? Icons.playlist_add_check_rounded
                  : Icons.check_rounded,
              loading: _loading,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }

  Widget _singleForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          AppTextField(
            controller: _english,
            label: context.l10n.t('words.english'),
            icon: Icons.abc_rounded,
            validator: (value) => _required(context, value),
          ),
          if (!_editing) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: _aiLoading ? null : _fillWithAi,
                icon: _aiLoading
                    ? const SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome_rounded),
                label: Text(context.l10n.t('ai.fillWord')),
              ),
            ),
          ],
          const SizedBox(height: 12),
          AppTextField(
            controller: _uzbek,
            label: context.l10n.t('words.translation'),
            icon: Icons.translate_rounded,
            validator: (value) => _required(context, value),
          ),
          const SizedBox(height: 12),
          AppTextField(
            controller: _example,
            label: context.l10n.t('words.example'),
            icon: Icons.notes_rounded,
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          AppTextField(
            controller: _pronunciation,
            label: context.l10n.t('words.pronunciation'),
            icon: Icons.record_voice_over_rounded,
          ),
        ],
      ),
    );
  }

  Widget _bulkForm(int parsedCount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.t('words.paste'),
          style: AppTextStyles.sectionFor(context),
        ),
        const SizedBox(height: 6),
        Text(
          context.l10n.t('words.importHelp'),
          style: AppTextStyles.captionFor(context),
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
                  setState(() => _bulk.text = text);
                },
                icon: const Icon(Icons.content_paste_rounded),
                label: Text(context.l10n.t('words.pasteClipboard')),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: () =>
                    setState(() => _bulk.text = sampleImportText()),
                icon: const Icon(Icons.auto_awesome_rounded),
                label: Text(context.l10n.t('words.sample')),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _bulk,
          minLines: 10,
          maxLines: 14,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: context.l10n.t('words.importText'),
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          context.l10n.f('words.detected', {'count': parsedCount}),
          style: AppTextStyles.captionFor(
            context,
          ).copyWith(color: AppColors.green),
        ),
      ],
    );
  }
}

int _safeParsedCount(String value) {
  try {
    return parseBulkWords(value).length;
  } on Object {
    return 0;
  }
}

String? _required(BuildContext context, String? value) {
  if (value == null || value.trim().isEmpty) {
    return context.l10n.t('common.required');
  }
  return null;
}
