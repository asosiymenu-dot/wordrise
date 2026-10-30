import '../models/api_models.dart';
import 'api_service.dart';

class GrammarService {
  GrammarService(this._api);

  final ApiService _api;

  Future<List<GrammarLevelModel>> levels() async {
    final data = await _api.get('/grammar/levels.php');
    return (data['levels'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(GrammarLevelModel.fromJson)
        .toList();
  }

  Future<List<GrammarTopicModel>> topics(String levelCode) async {
    final data = await _api.get(
      '/grammar/topics.php',
      query: {'level': levelCode},
    );
    return (data['topics'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(GrammarTopicModel.fromJson)
        .toList();
  }

  Future<GrammarTopicModel?> nextTopic() async {
    final data = await _api.get('/grammar/next.php');
    return data['topic'] is Map<String, dynamic>
        ? GrammarTopicModel.fromJson(data['topic'] as Map<String, dynamic>)
        : null;
  }

  Future<List<GrammarLessonModel>> all({String level = ''}) async {
    final data = await _api.get(
      '/grammar/index.php',
      query: {if (level.isNotEmpty) 'level': level},
    );
    return (data['lessons'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(GrammarLessonModel.fromJson)
        .toList();
  }

  Future<GrammarDetailModel> detail(int lessonId) async {
    final data = await _api.get(
      '/grammar/detail.php',
      query: {'id': lessonId.toString()},
    );
    return GrammarDetailModel.fromJson(data);
  }

  Future<GrammarDetailModel> detailByTopic(int topicId) async {
    final data = await _api.get(
      '/grammar/detail.php',
      query: {'topic_id': topicId.toString()},
    );
    return GrammarDetailModel.fromJson(data);
  }

  Future<GrammarSubmitResultModel> submit({
    required int topicId,
    required Map<int, String> answers,
  }) async {
    final data = await _api.post('/grammar/submit.php', {
      'topic_id': topicId,
      'answers': answers.entries
          .map((entry) => {'exercise_id': entry.key, 'answer': entry.value})
          .toList(),
    });
    return GrammarSubmitResultModel.fromJson(data);
  }

  Future<List<GrammarExerciseModel>> reviewMistakes({int limit = 20}) async {
    final data = await _api.get(
      '/grammar/review_mistakes.php',
      query: {'limit': limit.toString()},
    );
    return (data['exercises'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(GrammarExerciseModel.fromJson)
        .toList();
  }

  Future<GrammarDetailModel> saveGenerated(
    AiGeneratedGrammarLesson generated,
  ) async {
    final data = await _api.post(
      '/grammar/save_generated.php',
      generated.toSaveJson(),
      timeout: const Duration(seconds: 25),
    );
    return GrammarDetailModel.fromJson(data);
  }
}
