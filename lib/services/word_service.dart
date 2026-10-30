import '../models/api_models.dart';
import 'api_service.dart';
import 'offline_cache_service.dart';

class WordService {
  WordService(this._api, [OfflineCacheService? cache])
    : _cache = cache ?? OfflineCacheService();

  final ApiService _api;
  final OfflineCacheService _cache;

  Future<List<WordModel>> byLesson(int lessonId) async {
    try {
      final data = await _api.get(
        '/words/index.php',
        query: {
          'lesson_id': lessonId.toString(),
          't': DateTime.now().millisecondsSinceEpoch.toString(),
        },
      );
      final words = (data['words'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(WordModel.fromJson)
          .toList();
      await _cache.saveWords(lessonId, words);
      return words;
    } on ApiException catch (error) {
      if (!error.isNetwork) rethrow;
      final cached = await _cache.words(lessonId);
      if (cached == null) rethrow;
      return cached;
    }
  }

  Future<WordModel> create({
    required int lessonId,
    required String englishWord,
    required String uzbekTranslation,
    String exampleSentence = '',
    String pronunciation = '',
  }) async {
    final data = await _api.post('/words/create.php', {
      'lesson_id': lessonId,
      'english_word': englishWord,
      'uzbek_translation': uzbekTranslation,
      'example_sentence': exampleSentence,
      'pronunciation': pronunciation,
    });
    return WordModel.fromJson(data['word'] as Map<String, dynamic>);
  }

  Future<List<WordModel>> bulkCreate({
    required int lessonId,
    required List<Map<String, String>> words,
  }) async {
    final data = await _api.post('/words/bulk_create.php', {
      'lesson_id': lessonId,
      'words': words,
    });
    return (data['words'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(WordModel.fromJson)
        .toList();
  }

  Future<WordModel> update({
    required int id,
    required String englishWord,
    required String uzbekTranslation,
    String exampleSentence = '',
    String pronunciation = '',
  }) async {
    final data = await _api.put('/words/update.php', {
      'id': id,
      'english_word': englishWord,
      'uzbek_translation': uzbekTranslation,
      'example_sentence': exampleSentence,
      'pronunciation': pronunciation,
    });
    return WordModel.fromJson(data['word'] as Map<String, dynamic>);
  }

  Future<void> delete(int id) async {
    await _api.delete('/words/delete.php', body: {'id': id});
  }

  Future<void> setStarred(int wordId, bool isStarred) async {
    await _api.post('/words/star.php', {
      'word_id': wordId,
      'is_starred': isStarred,
    });
  }

  Future<List<WordModel>> starred() async {
    final data = await _api.get('/words/starred.php');
    return (data['words'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(WordModel.fromJson)
        .toList();
  }
}
