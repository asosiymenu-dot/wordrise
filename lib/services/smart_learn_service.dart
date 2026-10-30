import '../models/api_models.dart';
import 'api_service.dart';
import 'offline_cache_service.dart';
import 'offline_learning_service.dart';

class SmartLearnService {
  SmartLearnService(this._api, [OfflineLearningService? offline])
    : _offline = offline ?? OfflineLearningService(_api, OfflineCacheService());

  final ApiService _api;
  final OfflineLearningService _offline;

  Future<SmartLearnDashboardModel> dashboard() async {
    try {
      final data = await _api.get('/smart_learn/dashboard.php');
      return SmartLearnDashboardModel.fromJson(
        data['dashboard'] as Map<String, dynamic>,
      );
    } on ApiException catch (error) {
      if (!error.isNetwork) rethrow;
      return _offline.dashboard();
    }
  }

  Future<void> updateSettings({
    required int dailyGoalMinutes,
    required String preferredDirection,
  }) async {
    await _api.post('/smart_learn/settings.php', {
      'daily_goal_minutes': dailyGoalMinutes,
      'preferred_direction': preferredDirection,
    });
  }

  Future<SmartLearnStateModel> start({
    int? dailyGoalMinutes,
    String? direction,
    bool resume = true,
  }) async {
    final body = <String, dynamic>{'resume': resume};
    if (dailyGoalMinutes != null) {
      body['daily_goal_minutes'] = dailyGoalMinutes;
    }
    if (direction != null) body['direction'] = direction;
    try {
      final data = await _api.post('/smart_learn/start.php', body);
      return SmartLearnStateModel.fromJson(data);
    } on ApiException catch (error) {
      if (!error.isNetwork) rethrow;
      return _offline.start(
        dailyGoalMinutes: dailyGoalMinutes,
        direction: direction,
        resume: resume,
      );
    }
  }

  Future<SmartLearnStateModel> state(int sessionId) async {
    if (sessionId < 0) return _offline.state(sessionId);
    final data = await _api.get(
      '/smart_learn/session.php',
      query: {'session_id': sessionId.toString()},
    );
    return SmartLearnStateModel.fromJson(data);
  }

  Future<SmartLearnStateModel> answer({
    required int sessionId,
    required int itemId,
    required String answer,
    required int answerMs,
  }) async {
    if (sessionId < 0) {
      return _offline.answer(
        sessionId: sessionId,
        itemId: itemId,
        answer: answer,
        answerMs: answerMs,
      );
    }
    final data = await _api.post('/smart_learn/answer.php', {
      'session_id': sessionId,
      'item_id': itemId,
      'answer': answer,
      'answer_ms': answerMs,
    });
    return SmartLearnStateModel.fromJson(data);
  }

  Future<void> refreshOfflinePack() => _offline.refreshPack();

  Future<UserModel?> syncPending() => _offline.syncPending();
}
