import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/primary_button.dart';
import '../../models/app_update_model.dart';

class ForcedUpdateScreen extends StatefulWidget {
  const ForcedUpdateScreen({
    required this.release,
    required this.checking,
    required this.onDownload,
    required this.onCheckAgain,
    super.key,
  });

  final AppReleaseModel release;
  final bool checking;
  final Future<bool> Function() onDownload;
  final Future<void> Function() onCheckAgain;

  @override
  State<ForcedUpdateScreen> createState() => _ForcedUpdateScreenState();
}

class _ForcedUpdateScreenState extends State<ForcedUpdateScreen> {
  bool _openingDownload = false;
  bool _downloadOpened = false;
  bool _openFailed = false;

  Future<void> _download() async {
    if (_openingDownload) return;
    setState(() {
      _openingDownload = true;
      _openFailed = false;
    });
    final opened = await widget.onDownload();
    if (!mounted) return;
    setState(() {
      _openingDownload = false;
      _downloadOpened = opened;
      _openFailed = !opened;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final notes = widget.release.releaseNotes?.trim() ?? '';
    final fileSize = _formatFileSize(widget.release.fileSizeBytes);
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: GradientBackground(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 56,
                ),
                child: Center(
                  child: GlassCard(
                    borderRadius: 28,
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            color: AppColors.blue.withValues(alpha: .12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            CupertinoIcons.arrow_down_circle_fill,
                            size: 44,
                            color: AppColors.blue,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          l10n.t('update.requiredTitle'),
                          textAlign: TextAlign.center,
                          style: AppTextStyles.displayFor(
                            context,
                          ).copyWith(fontSize: 27),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          l10n.t('update.requiredBody'),
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodyFor(context).copyWith(
                            color: AppColors.textSecondary(context),
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceMuted(context),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                CupertinoIcons.app_badge_fill,
                                color: AppColors.purple,
                                size: 21,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  l10n.f('update.version', {
                                    'version': widget.release.versionName,
                                  }),
                                  style: AppTextStyles.bodyFor(
                                    context,
                                  ).copyWith(fontWeight: FontWeight.w600),
                                ),
                              ),
                              if (fileSize != null)
                                Text(
                                  fileSize,
                                  style: AppTextStyles.captionFor(context),
                                ),
                            ],
                          ),
                        ),
                        if (notes.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              notes,
                              style: AppTextStyles.bodyFor(
                                context,
                              ).copyWith(height: 1.42),
                            ),
                          ),
                        ],
                        if (_downloadOpened) ...[
                          const SizedBox(height: 14),
                          Text(
                            l10n.t('update.downloadOpened'),
                            textAlign: TextAlign.center,
                            style: AppTextStyles.captionFor(
                              context,
                            ).copyWith(color: AppColors.green),
                          ),
                        ],
                        if (_openFailed) ...[
                          const SizedBox(height: 14),
                          Text(
                            l10n.t('update.openFailed'),
                            textAlign: TextAlign.center,
                            style: AppTextStyles.captionFor(
                              context,
                            ).copyWith(color: AppColors.softRed),
                          ),
                        ],
                        const SizedBox(height: 20),
                        PrimaryButton(
                          label: l10n.t('update.download'),
                          icon: CupertinoIcons.arrow_down_to_line,
                          loading: _openingDownload,
                          onPressed: _download,
                        ),
                        const SizedBox(height: 10),
                        SecondaryButton(
                          label: widget.checking
                              ? l10n.t('update.checking')
                              : l10n.t('update.checkAgain'),
                          icon: CupertinoIcons.refresh,
                          onPressed: widget.checking
                              ? null
                              : widget.onCheckAgain,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              CupertinoIcons.lock_shield_fill,
                              size: 14,
                              color: AppColors.green,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                l10n.t('update.secureSource'),
                                textAlign: TextAlign.center,
                                style: AppTextStyles.captionFor(context),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String? _formatFileSize(int? bytes) {
  if (bytes == null || bytes <= 0) return null;
  final megabytes = bytes / (1024 * 1024);
  return '${megabytes.toStringAsFixed(megabytes >= 10 ? 0 : 1)} MB';
}
