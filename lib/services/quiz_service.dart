import '../models/api_models.dart';
import 'api_service.dart';

class QuizService {
  QuizService(this._api);

  final ApiService _api;

  Future<List<QuizQuestionModel>> generate({
    required int lessonId,
    required String mode,
    int limit = 10,
    String direction = 'eng_to_uz',
    String scope = 'lesson',
  }) async {
    final data = await _api.get(
      '/quiz/generate.php',
      query: {
        'lesson_id': lessonId.toString(),
        'mode': mode,
        'limit': limit.toString(),
        'direction': direction,
        'scope': scope,
      },
    );
    return (data['questions'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(QuizQuestionModel.fromJson)
        .toList();
  }

  Future<List<QuizQuestionModel>> practiceMistakes({
    String mode = 'multiple_choice',
    String direction = 'eng_to_uz',
  }) async {
    final data = await _api.post('/quiz/practice_mistakes.php', {
      'mode': mode,
      'direction': direction,
    });
    return (data['questions'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(QuizQuestionModel.fromJson)
        .toList();
  }

  Future<List<QuizQuestionModel>> generateReview({
    String mode = 'multiple_choice',
    int limit = 10,
    String direction = 'eng_to_uz',
  }) async {
    final data = await _api.get(
      '/quiz/generate_review.php',
      query: {'mode': mode, 'limit': limit.toString(), 'direction': direction},
    );
    return (data['questions'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(QuizQuestionModel.fromJson)
        .toList();
  }

  Future<DueReviewModel> dueReviews({
    String mode = 'multiple_choice',
    int limit = 20,
    String direction = 'eng_to_uz',
  }) async {
    final data = await _api.get(
      '/quiz/due_reviews.php',
      query: {'mode': mode, 'limit': limit.toString(), 'direction': direction},
    );
    return DueReviewModel.fromJson(data);
  }

  Future<QuizResultModel> submit({
    required int lessonId,
    required String mode,
    required List<QuizAnswerModel> answers,
    String direction = 'eng_to_uz',
  }) async {
    final data = await _api.post('/quiz/submit.php', {
      'lesson_id': lessonId,
      'mode': mode,
      'direction': direction,
      'answers': answers.map((item) => item.toJson()).toList(),
    });
    return QuizResultModel.fromJson(data['result'] as Map<String, dynamic>);
  }

  Future<QuizResultModel> submitReview({
    required String mode,
    required List<QuizAnswerModel> answers,
    String direction = 'eng_to_uz',
  }) async {
    final data = await _api.post('/quiz/submit_review.php', {
      'mode': mode,
      'direction': direction,
      'answers': answers.map((item) => item.toJson()).toList(),
    });
    return QuizResultModel.fromJson(data['result'] as Map<String, dynamic>);
  }
}
