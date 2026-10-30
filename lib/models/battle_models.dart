import 'json_helpers.dart';
import 'leaderboard_models.dart';

class BattleInviteModel {
  const BattleInviteModel({
    required this.id,
    required this.battleId,
    required this.senderId,
    required this.receiverId,
    required this.status,
    required this.battleStatus,
    required this.roomCode,
    required this.direction,
    required this.questionLimit,
    required this.durationSeconds,
    required this.expiresAt,
    required this.canAccept,
    required this.canDecline,
    required this.canCancel,
    this.messageId,
    this.lessonId,
    this.lessonTitle,
    this.rematchOfId,
    this.sender,
    this.receiver,
  });

  factory BattleInviteModel.fromJson(Map<String, dynamic> json) {
    return BattleInviteModel(
      id: asInt(json['id']),
      battleId: asInt(json['battle_id']),
      messageId: json['message_id'] == null ? null : asInt(json['message_id']),
      senderId: asInt(json['sender_id']),
      receiverId: asInt(json['receiver_id']),
      sender: json['sender'] is Map<String, dynamic>
          ? PublicUserModel.fromJson(json['sender'] as Map<String, dynamic>)
          : null,
      receiver: json['receiver'] is Map<String, dynamic>
          ? PublicUserModel.fromJson(json['receiver'] as Map<String, dynamic>)
          : null,
      status: json['status']?.toString() ?? 'pending',
      battleStatus: json['battle_status']?.toString() ?? 'waiting',
      roomCode: json['room_code']?.toString() ?? '',
      lessonId: json['lesson_id'] == null ? null : asInt(json['lesson_id']),
      lessonTitle: asNullableString(json['lesson_title']),
      direction: json['direction']?.toString() ?? 'eng_to_uz',
      questionLimit: asInt(json['question_limit']),
      durationSeconds: asInt(json['duration_seconds']),
      rematchOfId: json['rematch_of_id'] == null
          ? null
          : asInt(json['rematch_of_id']),
      expiresAt: json['expires_at']?.toString() ?? '',
      canAccept: asBool(json['can_accept']),
      canDecline: asBool(json['can_decline']),
      canCancel: asBool(json['can_cancel']),
    );
  }

  final int id;
  final int battleId;
  final int? messageId;
  final int senderId;
  final int receiverId;
  final PublicUserModel? sender;
  final PublicUserModel? receiver;
  final String status;
  final String battleStatus;
  final String roomCode;
  final int? lessonId;
  final String? lessonTitle;
  final String direction;
  final int questionLimit;
  final int durationSeconds;
  final int? rematchOfId;
  final String expiresAt;
  final bool canAccept;
  final bool canDecline;
  final bool canCancel;

  bool get pending => status == 'pending';
  bool get accepted => status == 'accepted';
}

class BattleQuestionModel {
  const BattleQuestionModel({
    required this.id,
    required this.wordId,
    required this.prompt,
    required this.correctAnswer,
    required this.options,
    required this.orderIndex,
  });

  factory BattleQuestionModel.fromJson(Map<String, dynamic> json) {
    return BattleQuestionModel(
      id: asInt(json['id']),
      wordId: asInt(json['word_id']),
      prompt: json['prompt']?.toString() ?? '',
      correctAnswer: json['correct_answer']?.toString() ?? '',
      options: (json['options'] as List? ?? [])
          .map((item) => item.toString())
          .toList(),
      orderIndex: asInt(json['order_index']),
    );
  }

  final int id;
  final int wordId;
  final String prompt;
  final String correctAnswer;
  final List<String> options;
  final int orderIndex;
}

class BattleAnswerModel {
  const BattleAnswerModel({
    required this.questionId,
    required this.givenAnswer,
    required this.isCorrect,
    required this.answeredMs,
  });

  factory BattleAnswerModel.fromJson(Map<String, dynamic> json) {
    return BattleAnswerModel(
      questionId: asInt(json['question_id']),
      givenAnswer: json['given_answer']?.toString() ?? '',
      isCorrect: asBool(json['is_correct']),
      answeredMs: asInt(json['answered_ms']),
    );
  }

  final int questionId;
  final String givenAnswer;
  final bool isCorrect;
  final int answeredMs;
}

class BattleScoreModel {
  const BattleScoreModel({
    required this.user,
    required this.correctCount,
    required this.answeredCount,
    required this.averageMs,
  });

  factory BattleScoreModel.fromJson(Map<String, dynamic> json) {
    return BattleScoreModel(
      user: PublicUserModel.fromJson(json['user'] as Map<String, dynamic>),
      correctCount: asInt(json['correct_count']),
      answeredCount: asInt(json['answered_count']),
      averageMs: asInt(json['average_ms']),
    );
  }

  final PublicUserModel user;
  final int correctCount;
  final int answeredCount;
  final int averageMs;
}

class BattleStateModel {
  const BattleStateModel({
    required this.id,
    required this.roomCode,
    required this.status,
    required this.direction,
    required this.questionLimit,
    required this.durationSeconds,
    required this.timeLeft,
    required this.phase,
    required this.countdownSeconds,
    required this.version,
    required this.questions,
    required this.myAnswers,
    required this.scoreboard,
    this.startedAt,
    this.startsAt,
    this.finishedAt,
    this.finishedReason,
    this.creator,
    this.opponent,
  });

  factory BattleStateModel.fromJson(Map<String, dynamic> json) {
    return BattleStateModel(
      id: asInt(json['id']),
      roomCode: json['room_code']?.toString() ?? '',
      status: json['status']?.toString() ?? 'waiting',
      phase:
          json['phase']?.toString() ?? json['status']?.toString() ?? 'waiting',
      direction: json['direction']?.toString() ?? 'eng_to_uz',
      questionLimit: asInt(json['question_limit']),
      durationSeconds: asInt(json['duration_seconds']),
      timeLeft: asInt(json['time_left']),
      countdownSeconds: asInt(json['countdown_seconds']),
      version: asInt(json['version']),
      startedAt: asNullableString(json['started_at']),
      startsAt: asNullableString(json['starts_at']),
      finishedAt: asNullableString(json['finished_at']),
      finishedReason: asNullableString(json['finished_reason']),
      creator: json['creator'] is Map<String, dynamic>
          ? PublicUserModel.fromJson(json['creator'] as Map<String, dynamic>)
          : null,
      opponent: json['opponent'] is Map<String, dynamic>
          ? PublicUserModel.fromJson(json['opponent'] as Map<String, dynamic>)
          : null,
      questions: (json['questions'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(BattleQuestionModel.fromJson)
          .toList(),
      myAnswers: (json['my_answers'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(BattleAnswerModel.fromJson)
          .toList(),
      scoreboard: (json['scoreboard'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(BattleScoreModel.fromJson)
          .toList(),
    );
  }

  final int id;
  final String roomCode;
  final String status;
  final String phase;
  final String direction;
  final int questionLimit;
  final int durationSeconds;
  final int timeLeft;
  final int countdownSeconds;
  final int version;
  final String? startedAt;
  final String? startsAt;
  final String? finishedAt;
  final String? finishedReason;
  final PublicUserModel? creator;
  final PublicUserModel? opponent;
  final List<BattleQuestionModel> questions;
  final List<BattleAnswerModel> myAnswers;
  final List<BattleScoreModel> scoreboard;

  bool get waiting => status == 'waiting';
  bool get active => status == 'active';
  bool get countdown => phase == 'countdown';
  bool get finished => status == 'finished' || status == 'cancelled';

  Map<int, BattleAnswerModel> get myAnswersByQuestion {
    return {for (final answer in myAnswers) answer.questionId: answer};
  }
}
