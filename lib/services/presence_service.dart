import '../models/json_helpers.dart';
import 'api_service.dart';

class PresenceModel {
  const PresenceModel({
    required this.userId,
    required this.isOnline,
    this.isTyping = false,
    this.lastSeenAt,
    this.serverTime,
  });

  factory PresenceModel.fromJson(Map<String, dynamic> json) {
    return PresenceModel(
      userId: asInt(json['user_id']),
      isOnline:
          json['is_online'] == true || json['is_online']?.toString() == '1',
      isTyping:
          json['is_typing'] == true || json['is_typing']?.toString() == '1',
      lastSeenAt: _parseDate(json['last_seen_at']),
      serverTime: _parseDate(json['server_time']),
    );
  }

  final int userId;
  final bool isOnline;
  final bool isTyping;
  final DateTime? lastSeenAt;
  final DateTime? serverTime;
}

class PresenceService {
  PresenceService(this._api);

  final ApiService _api;

  Future<PresenceModel> heartbeat() async {
    final data = await _api.post('/presence/heartbeat.php', const {});
    return PresenceModel.fromJson(_map(data['presence']));
  }

  Future<PresenceModel> status(int userId) async {
    final data = await _api.get(
      '/presence/status.php',
      query: {'user_id': userId.toString()},
    );
    return PresenceModel.fromJson(_map(data['presence']));
  }

  Future<PresenceModel> setTyping({
    required int receiverId,
    required bool isTyping,
  }) async {
    final data = await _api.post('/presence/typing.php', {
      'receiver_id': receiverId,
      'is_typing': isTyping,
    });
    return PresenceModel.fromJson(_map(data['presence']));
  }
}

Map<String, dynamic> _map(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return const {};
}

DateTime? _parseDate(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : DateTime.tryParse(text)?.toLocal();
}
