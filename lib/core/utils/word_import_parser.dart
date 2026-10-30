import 'dart:convert';

class BulkWordInput {
  const BulkWordInput({
    required this.englishWord,
    required this.uzbekTranslation,
    this.exampleSentence = '',
    this.pronunciation = '',
  });

  final String englishWord;
  final String uzbekTranslation;
  final String exampleSentence;
  final String pronunciation;

  Map<String, String> toJson() {
    return {
      'english_word': englishWord,
      'uzbek_translation': uzbekTranslation,
      'example_sentence': exampleSentence,
      'pronunciation': pronunciation,
    };
  }
}

List<BulkWordInput> parseBulkWords(String raw) {
  final text = raw.trim();
  if (text.isEmpty) throw const FormatException('So‘zlar ro‘yxatini kiriting.');

  if (text.startsWith('[') || text.startsWith('{')) {
    return _parseJsonWords(text);
  }

  final words = <BulkWordInput>[];
  for (final line in const LineSplitter().convert(text)) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    final word = _parseLine(trimmed);
    words.add(word);
  }

  if (words.isEmpty) {
    throw const FormatException('Import uchun so‘z topilmadi.');
  }
  return words;
}

String sampleImportText() {
  return [
    'apple\tolma\tI eat an apple.\tAE-puhl',
    'book\tkitob',
    'water - suv',
    'bright, yorqin',
  ].join('\n');
}

List<BulkWordInput> _parseJsonWords(String text) {
  final decoded = jsonDecode(text);
  final items = decoded is List
      ? decoded
      : decoded is Map<String, dynamic>
      ? decoded['words'] ?? decoded['items']
      : null;

  if (items is! List) {
    throw const FormatException('JSON array yoki {"words": [...]} kerak.');
  }

  return items.map((item) {
    if (item is! Map) {
      throw const FormatException('JSON element object bo‘lishi kerak.');
    }
    final map = item.cast<String, dynamic>();
    final english = _firstText(map, ['english_word', 'word', 'english']);
    final uzbek = _firstText(map, [
      'uzbek_translation',
      'translation',
      'uzbek',
    ]);
    if (english == null || uzbek == null) {
      throw const FormatException('word va translation kerak.');
    }
    return BulkWordInput(
      englishWord: english,
      uzbekTranslation: uzbek,
      exampleSentence:
          _firstText(map, ['example_sentence', 'example', 'sentence']) ?? '',
      pronunciation: _firstText(map, ['pronunciation', 'pronounce']) ?? '',
    );
  }).toList();
}

BulkWordInput _parseLine(String line) {
  final tabParts = line
      .split(RegExp(r'\t+'))
      .map((part) => part.trim())
      .toList();
  if (tabParts.length >= 2) {
    if (tabParts[0].isEmpty || tabParts[1].isEmpty) {
      throw const FormatException(
        'Birinchi ustun so‘z, ikkinchi ustun tarjima bo‘lsin.',
      );
    }
    return BulkWordInput(
      englishWord: tabParts[0],
      uzbekTranslation: tabParts[1],
      exampleSentence: tabParts.length > 2 ? tabParts[2] : '',
      pronunciation: tabParts.length > 3 ? tabParts[3] : '',
    );
  }

  final parts = line.split('|').map((part) => part.trim()).toList();
  final pair = _splitPair(parts.first);
  if (pair == null) {
    throw const FormatException('Qator formati: apple - olma yoki apple, olma');
  }
  return BulkWordInput(
    englishWord: pair.$1,
    uzbekTranslation: pair.$2,
    exampleSentence: parts.length > 1 ? parts[1] : '',
    pronunciation: parts.length > 2 ? parts[2] : '',
  );
}

(String, String)? _splitPair(String value) {
  for (final delimiter in [
    RegExp(r'\s+[-–—]\s+'),
    RegExp(r'\s*=\s*'),
    RegExp(r'\s*,\s*'),
    RegExp(r'\s*;\s*'),
  ]) {
    final parts = value.split(delimiter);
    if (parts.length >= 2) {
      return (parts.first.trim(), parts.sublist(1).join(' ').trim());
    }
  }
  return null;
}

String? _firstText(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key]?.toString().trim();
    if (value != null && value.isNotEmpty) return value;
  }
  return null;
}
