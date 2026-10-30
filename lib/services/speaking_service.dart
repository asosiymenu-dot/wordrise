import '../models/api_models.dart';
import 'api_service.dart';

class SpeakingService {
  SpeakingService(this._api);

  final ApiService _api;
  static const _timeout = Duration(seconds: 35);

  Future<SpeakingQuestionModel> question({
    required String level,
    required String topic,
    List<Map<String, String>> history = const [],
  }) async {
    final data = await _api.post('/ai/speaking_question.php', {
      'level': level,
      'topic': topic,
      'history': history,
    }, timeout: _timeout);
    return SpeakingQuestionModel.fromJson(data);
  }

  Future<SpeakingFeedbackModel> feedback({
    required String level,
    required String question,
    required String answer,
  }) async {
    final data = await _api.post('/ai/speaking_feedback.php', {
      'level': level,
      'question': question,
      'answer': answer,
    }, timeout: _timeout);
    return SpeakingFeedbackModel.fromJson(
      data['feedback'] as Map<String, dynamic>,
    );
  }
}
