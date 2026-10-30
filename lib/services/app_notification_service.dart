import '../models/api_models.dart';
import 'api_service.dart';

class AppNotificationService {
  AppNotificationService(this._api);

  final ApiService _api;

  Future<NotificationBatchModel> list({int afterId = 0}) async {
    final data = await _api.get(
      '/notifications/index.php',
      query: {'after_id': afterId.toString(), 'limit': '50'},
    );
    return NotificationBatchModel.fromJson(data);
  }

  Future<int> markRead({int? notificationId}) async {
    final body = <String, dynamic>{};
    if (notificationId != null) body['notification_id'] = notificationId;
    final data = await _api.post('/notifications/read.php', body);
    final value = data['unread_count'];
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  Future<bool> registerDevice({
    required String token,
    required String platform,
    required String locale,
  }) async {
    final data = await _api.post('/notifications/register_device.php', {
      'token': token,
      'platform': platform,
      'locale': locale,
    });
    return data['push_configured'] == true;
  }

  Future<void> unregisterDevice(String token) async {
    await _api.post('/notifications/unregister_device.php', {'token': token});
  }

  Future<LearningPreferencesModel> preferences() async {
    final data = await _api.get('/notifications/preferences.php');
    return LearningPreferencesModel.fromJson(
      data['preferences'] as Map<String, dynamic>,
    );
  }

  Future<LearningPreferencesModel> updatePreferences(
    LearningPreferencesModel preferences,
  ) async {
    final data = await _api.post(
      '/notifications/preferences.php',
      preferences.toJson(),
    );
    return LearningPreferencesModel.fromJson(
      data['preferences'] as Map<String, dynamic>,
    );
  }
}
