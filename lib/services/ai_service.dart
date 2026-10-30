import 'dart:convert';
import 'dart:typed_data';

import '../models/api_models.dart';
import 'api_service.dart';

class AiService {
  AiService(this._api);

  final ApiService _api;
  static const _timeout = Duration(seconds: 35);

  Future<AiWordSuggestion> suggestWord(String word) async {
    final data = await _api.post('/ai/suggest_word.php', {
      'word': word,
    }, timeout: _timeout);
    return AiWordSuggestion.fromJson(
      data['suggestion'] as Map<String, dynamic>,
    );
  }

  Future<List<AiWordSuggestion>> bulkSuggest(List<String> words) async {
    final data = await _api.post('/ai/bulk_suggest.php', {
      'words': words,
    }, timeout: _timeout);
    return (data['words'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(AiWordSuggestion.fromJson)
        .toList();
  }

  Future<AiGeneratedLesson> generateLesson(String topic) async {
    final data = await _api.post('/ai/generate_lesson.php', {
      'topic': topic,
    }, timeout: _timeout);
    return AiGeneratedLesson.fromJson(data);
  }

  Future<AiGeneratedGrammarLesson> generateGrammarLesson({
    required String levelCode,
    required String topic,
  }) async {
    final data = await _api.post('/ai/generate_grammar_lesson.php', {
      'level': levelCode,
      'topic': topic,
    }, timeout: _timeout);
    return AiGeneratedGrammarLesson.fromJson(data);
  }

  Future<List<AiWordSuggestion>> extractWordsFromImage({
    required Uint8List bytes,
    required String mimeType,
  }) async {
    final data = await _api.post('/ai/extract_words.php', {
      'image_base64': base64Encode(bytes),
      'mime_type': mimeType,
    }, timeout: const Duration(seconds: 55));
    return (data['words'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(AiWordSuggestion.fromJson)
        .toList();
  }
}
