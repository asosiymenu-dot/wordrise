import 'package:flutter/material.dart';

import '../../services/pronunciation_service.dart';
import '../localization/app_localizations.dart';

class PronunciationButton extends StatelessWidget {
  const PronunciationButton({
    required this.text,
    this.compact = false,
    super.key,
  });

  final String text;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      tooltip: context.l10n.t('words.listen'),
      visualDensity: compact ? VisualDensity.compact : VisualDensity.standard,
      onPressed: text.trim().isEmpty
          ? null
          : () => PronunciationService.instance.speak(text),
      icon: Icon(Icons.volume_up_rounded, size: compact ? 19 : 22),
    );
  }
}
