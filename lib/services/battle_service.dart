import '../models/api_models.dart';
import 'api_service.dart';

class BattleService {
  BattleService(this._api);

  final ApiService _api;

  Future<BattleStateModel> create({
    int? lessonId,
    int limit = 10,
    int durationSeconds = 90,
    String direction = 'eng_to_uz',
  }) async {
    final body = <String, dynamic>{
      'limit': limit,
      'duration_seconds': durationSeconds,
      'direction': direction,
    };
    if (lessonId != null) body['lesson_id'] = lessonId;
    final data = await _api.post('/battle/create.php', body);
    return BattleStateModel.fromJson(data['battle'] as Map<String, dynamic>);
  }

  Future<BattleStateModel> join(String roomCode) async {
    final data = await _api.post('/battle/join.php', {'room_code': roomCode});
    return BattleStateModel.fromJson(data['battle'] as Map<String, dynamic>);
  }

  Future<BattleStateModel> state(int battleId) async {
    final data = await _api.get(
      '/battle/state.php',
      query: {'battle_id': battleId.toString()},
    );
    return BattleStateModel.fromJson(data['battle'] as Map<String, dynamic>);
  }

  Future<BattleStateModel> answer({
    required int battleId,
    required int questionId,
    required String answer,
    required int answeredMs,
  }) async {
    final data = await _api.post('/battle/answer.php', {
      'battle_id': battleId,
      'question_id': questionId,
      'answer': answer,
      'answered_ms': answeredMs,
    });
    return BattleStateModel.fromJson(data['battle'] as Map<String, dynamic>);
  }

  Future<BattleInviteModel> invite({
    required int receiverId,
    int? lessonId,
    int limit = 10,
    int durationSeconds = 90,
    String direction = 'eng_to_uz',
  }) async {
    final body = <String, dynamic>{
      'receiver_id': receiverId,
      'limit': limit,
      'duration_seconds': durationSeconds,
      'direction': direction,
    };
    if (lessonId != null) body['lesson_id'] = lessonId;
    final data = await _api.post('/battle/invite.php', body);
    return BattleInviteModel.fromJson(data['invite'] as Map<String, dynamic>);
  }

  Future<BattleInviteResponse> respond({
    required int inviteId,
    required String action,
  }) async {
    final data = await _api.post('/battle/respond.php', {
      'invite_id': inviteId,
      'action': action,
    });
    return BattleInviteResponse.fromJson(data);
  }

  Future<BattleInviteModel> rematch(int battleId) async {
    final data = await _api.post('/battle/rematch.php', {
      'battle_id': battleId,
    });
    return BattleInviteModel.fromJson(data['invite'] as Map<String, dynamic>);
  }
}

class BattleInviteResponse {
  const BattleInviteResponse({required this.invite, this.battle});

  factory BattleInviteResponse.fromJson(Map<String, dynamic> json) {
    return BattleInviteResponse(
      invite: BattleInviteModel.fromJson(
        json['invite'] as Map<String, dynamic>,
      ),
      battle: json['battle'] is Map<String, dynamic>
          ? BattleStateModel.fromJson(json['battle'] as Map<String, dynamic>)
          : null,
    );
  }

  final BattleInviteModel invite;
  final BattleStateModel? battle;
}
