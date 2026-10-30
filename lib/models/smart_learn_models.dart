import 'json_helpers.dart';
import 'user_model.dart';

class SmartLearnDashboardModel {
  const SmartLearnDashboardModel({
    required this.dailyGoalMinutes,
    required this.preferredDirection,
    required this.todayMinutes,
    required this.goalCompleted,
    required this.dueCount,
    required this.weakCount,
    required this.newCount,
    required this.masteredCount,
    required this.totalWords,
    required this.suggestedCount,
    this.starredCount = 0,
    this.activeSession,
  });

  factory SmartLearnDashboardModel.fromJson(Map<String, dynamic> json) {
    return SmartLearnDashboardModel(
      dailyGoalMinutes: asInt(json['daily_goal_minutes']),
      preferredDirection: json['preferred_direction']?.toString() ?? 'mixed',
      todayMinutes: asInt(json['today_minutes']),
      goalCompleted: asBool(json['goal_completed']),
      dueCount: asInt(json['due_count']),
      weakCount: asInt(json['weak_count']),
      newCount: asInt(json['new_count']),
      masteredCount: asInt(json['mastered_count']),
      totalWords: asInt(json['total_words']),
      suggestedCount: asInt(json['suggested_count']),
      starredCount: asInt(json['starred_count']),
      activeSession: json['active_session'] is Map<String, dynamic>
          ? SmartLearnSessionModel.fromJson(
              json['active_session'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  final int dailyGoalMinutes;
  final String preferredDirection;
  final int todayMinutes;
  final bool goalCompleted;
  final int dueCount;
  final int weakCount;
  final int newCount;
  final int masteredCount;
  final int totalWords;
  final int suggestedCount;
  final int starredCount;
  final SmartLearnSessionModel? activeSession;

  double get dailyProgress => dailyGoalMinutes <= 0
      ? 0
      : (todayMinutes / dailyGoalMinutes).clamp(0, 1).toDouble();
}

class SmartLearnSessionModel {
  const SmartLearnSessionModel({
    required this.id,
    required this.status,
    required this.dailyGoalMinutes,
    required this.direction,
    required this.plannedCount,
    required this.answeredCount,
    required this.correctCount,
    required this.wrongCount,
    required this.earnedXp,
    required this.progress,
    required this.startedAt,
    required this.lastActivityAt,
    this.completedAt,
  });

  factory SmartLearnSessionModel.fromJson(Map<String, dynamic> json) {
    return SmartLearnSessionModel(
      id: asInt(json['id']),
      status: json['status']?.toString() ?? 'active',
      dailyGoalMinutes: asInt(json['daily_goal_minutes']),
      direction: json['direction']?.toString() ?? 'mixed',
      plannedCount: asInt(json['planned_count']),
      answeredCount: asInt(json['answered_count']),
      correctCount: asInt(json['correct_count']),
      wrongCount: asInt(json['wrong_count']),
      earnedXp: asInt(json['earned_xp']),
      progress: asDouble(json['progress'], 0).clamp(0, 1).toDouble(),
      startedAt: json['started_at']?.toString() ?? '',
      lastActivityAt: json['last_activity_at']?.toString() ?? '',
      completedAt: asNullableString(json['completed_at']),
    );
  }

  final int id;
  final String status;
  final int dailyGoalMinutes;
  final String direction;
  final int plannedCount;
  final int answeredCount;
  final int correctCount;
  final int wrongCount;
  final int earnedXp;
  final double progress;
  final String startedAt;
  final String lastActivityAt;
  final String? completedAt;

  bool get completed => status == 'completed';
}

class SmartLearnQuestionModel {
  const SmartLearnQuestionModel({
    required this.itemId,
    required this.wordId,
    required this.position,
    required this.sourceBucket,
    required this.attemptNo,
    required this.direction,
    required this.mode,
    required this.prompt,
    required this.options,
    required this.pronunciation,
    required this.exampleSentence,
    required this.hint,
  });

  factory SmartLearnQuestionModel.fromJson(Map<String, dynamic> json) {
    return SmartLearnQuestionModel(
      itemId: asInt(json['item_id']),
      wordId: asInt(json['word_id']),
      position: asInt(json['position']),
      sourceBucket: json['source_bucket']?.toString() ?? 'new',
      attemptNo: asInt(json['attempt_no']),
      direction: json['direction']?.toString() ?? 'eng_to_uz',
      mode: json['mode']?.toString() ?? 'choice',
      prompt: json['prompt']?.toString() ?? '',
      options: (json['options'] as List? ?? [])
          .map((item) => item.toString())
          .toList(),
      pronunciation: json['pronunciation']?.toString() ?? '',
      exampleSentence: json['example_sentence']?.toString() ?? '',
      hint: json['hint']?.toString() ?? '',
    );
  }

  final int itemId;
  final int wordId;
  final int position;
  final String sourceBucket;
  final int attemptNo;
  final String direction;
  final String mode;
  final String prompt;
  final List<String> options;
  final String pronunciation;
  final String exampleSentence;
  final String hint;

  bool get typing => mode == 'typing';
  bool get retry => attemptNo > 1;
}

class SmartLearnFeedbackModel {
  const SmartLearnFeedbackModel({
    required this.isCorrect,
    required this.correctAnswer,
    required this.givenAnswer,
    required this.answerMs,
    required this.code,
    required this.explanation,
    required this.exampleSentence,
    required this.duplicate,
  });

  factory SmartLearnFeedbackModel.fromJson(Map<String, dynamic> json) {
    return SmartLearnFeedbackModel(
      isCorrect: asBool(json['is_correct']),
      correctAnswer: json['correct_answer']?.toString() ?? '',
      givenAnswer: json['given_answer']?.toString() ?? '',
      answerMs: asInt(json['answer_ms']),
      code: json['code']?.toString() ?? '',
      explanation: json['explanation']?.toString() ?? '',
      exampleSentence: json['example_sentence']?.toString() ?? '',
      duplicate: asBool(json['duplicate']),
    );
  }

  final bool isCorrect;
  final String correctAnswer;
  final String givenAnswer;
  final int answerMs;
  final String code;
  final String explanation;
  final String exampleSentence;
  final bool duplicate;
}

class SmartLearnStateModel {
  const SmartLearnStateModel({
    required this.session,
    this.question,
    this.feedback,
    this.profile,
    this.offline = false,
  });

  factory SmartLearnStateModel.fromJson(Map<String, dynamic> json) {
    return SmartLearnStateModel(
      session: SmartLearnSessionModel.fromJson(
        json['session'] as Map<String, dynamic>,
      ),
      question: json['question'] is Map<String, dynamic>
          ? SmartLearnQuestionModel.fromJson(
              json['question'] as Map<String, dynamic>,
            )
          : null,
      feedback: json['feedback'] is Map<String, dynamic>
          ? SmartLearnFeedbackModel.fromJson(
              json['feedback'] as Map<String, dynamic>,
            )
          : null,
      profile: json['profile'] is Map<String, dynamic>
          ? UserModel.fromJson(json['profile'] as Map<String, dynamic>)
          : null,
      offline: asBool(json['offline']),
    );
  }

  final SmartLearnSessionModel session;
  final SmartLearnQuestionModel? question;
  final SmartLearnFeedbackModel? feedback;
  final UserModel? profile;
  final bool offline;
}
