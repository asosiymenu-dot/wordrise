import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../../services/audio_haptic_service.dart';

class IosSelectionOption<T> {
  const IosSelectionOption({
    required this.value,
    required this.label,
    this.icon,
    this.destructive = false,
  });

  final T value;
  final String label;
  final IconData? icon;
  final bool destructive;
}

Future<T?> showIosSelectionSheet<T>({
  required BuildContext context,
  required String title,
  required T? selected,
  required List<IosSelectionOption<T>> options,
}) {
  AudioHapticService.instance.selectionClick();
  return showCupertinoModalPopup<T>(
    context: context,
    builder: (context) {
      final isDark = AppColors.isDark(context);
      return CupertinoTheme(
        data: CupertinoTheme.of(context).copyWith(
          brightness: isDark ? Brightness.dark : Brightness.light,
          primaryColor: AppColors.blue,
        ),
        child: CupertinoActionSheet(
          title: Text(title),
          actions: [
            for (final option in options)
              CupertinoActionSheetAction(
                isDefaultAction: option.value == selected,
                isDestructiveAction: option.destructive,
                onPressed: () {
                  AudioHapticService.instance.selectionClick();
                  Navigator.of(context).pop(option.value);
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (option.value == selected) ...[
                      const Icon(CupertinoIcons.check_mark, size: 17),
                      const SizedBox(width: 8),
                    ] else if (option.icon != null) ...[
                      Icon(option.icon, size: 19),
                      const SizedBox(width: 8),
                    ],
                    Flexible(child: Text(option.label)),
                  ],
                ),
              ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.t('common.cancel')),
          ),
        ),
      );
    },
  );
}

class IosSettingRow extends StatelessWidget {
  const IosSettingRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.onTap,
    this.showDivider = true,
    super.key,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;
  final VoidCallback onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title, $value',
      child: Column(
        children: [
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            minimumSize: const Size(44, 52),
            pressedOpacity: .62,
            onPressed: onTap,
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: iconColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyFor(
                      context,
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: AppTextStyles.captionFor(context),
                  ),
                ),
                const SizedBox(width: 5),
                Icon(
                  CupertinoIcons.chevron_forward,
                  size: 16,
                  color: AppColors.textMuted(context).withValues(alpha: .7),
                ),
              ],
            ),
          ),
          if (showDivider)
            Padding(
              padding: const EdgeInsets.only(left: 56),
              child: Divider(height: 1, color: AppColors.divider(context)),
            ),
        ],
      ),
    );
  }
}
