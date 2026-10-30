import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/shimmer_loading.dart';
import '../../core/widgets/state_views.dart';
import '../../models/api_models.dart';
import '../../services/ai_service.dart';
import '../../services/api_service.dart';
import '../../services/word_service.dart';

class CameraWordImportScreen extends StatefulWidget {
  const CameraWordImportScreen({
    required this.lesson,
    required this.aiService,
    required this.wordService,
    super.key,
  });

  final LessonModel lesson;
  final AiService aiService;
  final WordService wordService;

  @override
  State<CameraWordImportScreen> createState() => _CameraWordImportScreenState();
}

class _CameraWordImportScreenState extends State<CameraWordImportScreen> {
  final _picker = ImagePicker();
  Uint8List? _image;
  List<AiWordSuggestion> _words = [];
  Set<int> _selected = {};
  bool _extracting = false;
  bool _saving = false;
  String? _error;

  Future<void> _pick(ImageSource source) async {
    if (_extracting) return;
    try {
      final file = await _picker.pickImage(
        source: source,
        imageQuality: 82,
        maxWidth: 1800,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _image = bytes;
        _extracting = true;
        _error = null;
        _words = [];
        _selected = {};
      });
      final words = await widget.aiService.extractWordsFromImage(
        bytes: bytes,
        mimeType: _mimeType(file),
      );
      if (!mounted) return;
      setState(() {
        _words = words;
        _selected = Set<int>.from(
          List.generate(words.length, (index) => index),
        );
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on Object {
      if (mounted) {
        setState(() => _error = context.l10n.t('cameraImport.pickError'));
      }
    } finally {
      if (mounted) setState(() => _extracting = false);
    }
  }

  Future<void> _save() async {
    if (_selected.isEmpty || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.wordService.bulkCreate(
        lessonId: widget.lesson.id,
        words: [
          for (final index in _selected.toList()..sort())
            _words[index].toWordJson(),
        ],
      );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: ListView(
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
                      context.l10n.t('cameraImport.title'),
                      style: AppTextStyles.titleFor(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                context.l10n.t('cameraImport.subtitle'),
                style: AppTextStyles.captionFor(context),
              ),
              const SizedBox(height: 14),
              if (kIsWeb)
                PrimaryButton(
                  label: context.l10n.t('profile.gallery'),
                  icon: Icons.add_photo_alternate_outlined,
                  onPressed: () => _pick(ImageSource.gallery),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: PrimaryButton(
                        label: context.l10n.t('profile.camera'),
                        icon: Icons.photo_camera_rounded,
                        onPressed: () => _pick(ImageSource.camera),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SecondaryButton(
                        label: context.l10n.t('profile.gallery'),
                        icon: Icons.photo_library_outlined,
                        onPressed: () => _pick(ImageSource.gallery),
                      ),
                    ),
                  ],
                ),
              if (_image != null) ...[
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.memory(
                    _image!,
                    height: 220,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ],
              if (_extracting) ...[
                const SizedBox(height: 14),
                const ShimmerLoadingList(itemCount: 4, compact: true),
              ] else if (_image != null &&
                  _words.isEmpty &&
                  _error == null) ...[
                const SizedBox(height: 14),
                EmptyStateView(
                  icon: Icons.text_snippet_outlined,
                  message: context.l10n.t('cameraImport.empty'),
                ),
              ],
              if (_words.isNotEmpty) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.l10n.f('cameraImport.found', {
                          'count': _words.length,
                        }),
                        style: AppTextStyles.sectionFor(context),
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() {
                        _selected = _selected.length == _words.length
                            ? <int>{}
                            : Set<int>.from(
                                List.generate(_words.length, (index) => index),
                              );
                      }),
                      child: Text(
                        context.l10n.t(
                          _selected.length == _words.length
                              ? 'cameraImport.clear'
                              : 'cameraImport.selectAll',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                for (var index = 0; index < _words.length; index++) ...[
                  GlassCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    child: CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _selected.contains(index),
                      activeColor: AppColors.green,
                      title: Text(
                        _words[index].englishWord,
                        style: AppTextStyles.sectionFor(
                          context,
                        ).copyWith(fontSize: 16),
                      ),
                      subtitle: Text(_words[index].uzbekTranslation),
                      onChanged: (checked) => setState(() {
                        if (checked == true) {
                          _selected.add(index);
                        } else {
                          _selected.remove(index);
                        }
                      }),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 8),
                PrimaryButton(
                  label: context.l10n.f('cameraImport.add', {
                    'count': _selected.length,
                  }),
                  icon: Icons.playlist_add_check_rounded,
                  loading: _saving,
                  onPressed: _selected.isEmpty ? null : _save,
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 14),
                ErrorStateView(message: _error!),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String _mimeType(XFile file) {
  final direct = file.mimeType?.toLowerCase();
  if (direct == 'image/png' || direct == 'image/webp') return direct!;
  final path = file.path.toLowerCase();
  if (path.endsWith('.png')) return 'image/png';
  if (path.endsWith('.webp')) return 'image/webp';
  return 'image/jpeg';
}
