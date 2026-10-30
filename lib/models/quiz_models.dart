import 'json_helpers.dart';
import 'user_model.dart';

class QuizQuestionModel {
  const QuizQuestionModel({
    required this.wordId,
    required this.lessonId,
    required this.mode,
    required this.prompt,
    required this.correctAnswer,
    required this.options,
    this.direction = 'eng_to_uz',
    this.shownTranslation,
    this.speechText = '',
    this.pronunciation = '',
  });

  factory QuizQuestionModel.fromJson(Map<String, dynamic> json) {
    return QuizQuestionModel(
      wordId: asInt(json['word_id']),
      lessonId: asInt(json['lesson_id']),
      mode: json['mode']?.toString() ?? 'multiple_choice',
      direction: json['direction']?.toString() ?? 'eng_to_uz',
      prompt: json['prompt']?.toString() ?? '',
      correctAnswer: json['correct_answer']?.toString() ?? '',
      shownTranslation: json['shown_translation']?.toString(),
      speechText: json['speech_text']?.toString() ?? '',
      pronunciation: json['pronunciation']?.toString() ?? '',
      options: (json['options'] as List? ?? [])
          .map((item) => item.toString())
          .toList(),
    );
  }

  final int wordId;
  final int lessonId;
  final String mode;
  final String direction;
  final String prompt;
  final String correctAnswer;
  final String? shownTranslation;
  final String speechText;
  final String pronunciation;
  final List<String> options;
}

class QuizAnswerModel {
  const QuizAnswerModel({
    required this.wordId,
    required this.answer,
    this.direction,
    this.shownTranslation,
    this.answerMs,
  });

  final int wordId;
  final String answer;
  final String? direction;
  final String? shownTranslation;
  final int? answerMs;

  Map<String, dynamic> toJson() {
    return {
      'word_id': wordId,
      'answer': answer,
      if (direction != null) 'direction': direction,
      if (shownTranslation != null) 'shown_translation': shownTranslation,
      if (answerMs != null) 'answer_ms': answerMs,
    };
  }
}

class DueReviewModel {
  const DueReviewModel({required this.dueCount, required this.questions});

  factory DueReviewModel.fromJson(Map<String, dynamic> json) {
    return DueReviewModel(
      dueCount: asInt(json['due_count']),
      questions: (json['questions'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(QuizQuestionModel.fromJson)
          .toList(),
    );
  }

  final int dueCount;
  final List<QuizQuestionModel> questions;
}

class QuizResultModel {
  const QuizResultModel({
    required this.id,
    required this.lessonId,
    required this.mode,
    required this.correctCount,
    required this.wrongCount,
    required this.earnedXp,
    required this.maxCorrectStreak,
    this.profile,
  });

  factory QuizResultModel.fromJson(Map<String, dynamic> json) {
    return QuizResultModel(
      id: asInt(json['id']),
      lessonId: asInt(json['lesson_id']),
      mode: json['mode']?.toString() ?? '',
      correctCount: asInt(json['correct_count']),
      wrongCount: asInt(json['wrong_count']),
      earnedXp: asInt(json['earned_xp']),
      maxCorrectStreak: asInt(json['max_correct_streak']),
      profile: json['profile'] is Map<String, dynamic>
          ? UserModel.fromJson(json['profile'] as Map<String, dynamic>)
          : null,
    );
  }

  final int id;
  final int lessonId;
  final String mode;
  final int correctCount;
  final int wrongCount;
  final int earnedXp;
  final int maxCorrectStreak;
  final UserModel? profile;
}
