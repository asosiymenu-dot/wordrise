import 'json_helpers.dart';
import 'user_model.dart';

class GrammarLevelModel {
  const GrammarLevelModel({
    required this.id,
    required this.code,
    required this.titleUz,
    required this.topicCount,
    required this.completedCount,
    required this.progressPercent,
  });

  factory GrammarLevelModel.fromJson(Map<String, dynamic> json) {
    return GrammarLevelModel(
      id: asInt(json['id']),
      code: json['code']?.toString() ?? 'A1',
      titleUz: json['title_uz']?.toString() ?? '',
      topicCount: asInt(json['topic_count']),
      completedCount: asInt(json['completed_count']),
      progressPercent: asInt(json['progress_percent']),
    );
  }

  final int id;
  final String code;
  final String titleUz;
  final int topicCount;
  final int completedCount;
  final int progressPercent;
}

class GrammarTopicModel {
  const GrammarTopicModel({
    required this.id,
    required this.levelId,
    required this.levelCode,
    required this.title,
    required this.lessonTitle,
    required this.lessonId,
    required this.icon,
    required this.durationMinutes,
    required this.exerciseCount,
    required this.progressPercent,
    required this.status,
  });

  factory GrammarTopicModel.fromJson(Map<String, dynamic> json) {
    return GrammarTopicModel(
      id: asInt(json['id']),
      levelId: asInt(json['level_id']),
      levelCode: json['level_code']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      lessonTitle: json['lesson_title']?.toString() ?? '',
      lessonId: asInt(json['lesson_id']),
      icon: json['icon']?.toString() ?? 'school',
      durationMinutes: asInt(json['duration_minutes']),
      exerciseCount: asInt(json['exercise_count']),
      progressPercent: asInt(json['progress_percent']),
      status: json['status']?.toString() ?? 'not_started',
    );
  }

  final int id;
  final int levelId;
  final String levelCode;
  final String title;
  final String lessonTitle;
  final int lessonId;
  final String icon;
  final int durationMinutes;
  final int exerciseCount;
  final int progressPercent;
  final String status;

  bool get completed => progressPercent >= 100 || status == 'completed';
  bool get inProgress => progressPercent > 0 && !completed;
}

class GrammarExampleModel {
  const GrammarExampleModel({required this.en, required this.uz});

  factory GrammarExampleModel.fromJson(Object? json) {
    if (json is Map) {
      return GrammarExampleModel(
        en: json['en']?.toString() ?? '',
        uz: json['uz']?.toString() ?? '',
      );
    }
    if (json is List && json.length >= 2) {
      return GrammarExampleModel(
        en: json[0].toString(),
        uz: json[1].toString(),
      );
    }
    return const GrammarExampleModel(en: '', uz: '');
  }

  final String en;
  final String uz;
}

class GrammarLessonModel {
  const GrammarLessonModel({
    required this.id,
    required this.topicId,
    required this.title,
    required this.level,
    required this.content,
    required this.examples,
    required this.commonMistakes,
    required this.exerciseCount,
  });

  factory GrammarLessonModel.fromJson(Map<String, dynamic> json) {
    return GrammarLessonModel(
      id: asInt(json['id']),
      topicId: asInt(json['topic_id']),
      title: json['title']?.toString() ?? '',
      level: json['level']?.toString() ?? 'A1',
      content: json['content']?.toString() ?? '',
      examples: (json['examples'] as List? ?? [])
          .map(GrammarExampleModel.fromJson)
          .where((item) => item.en.isNotEmpty || item.uz.isNotEmpty)
          .toList(),
      commonMistakes: json['common_mistakes']?.toString() ?? '',
      exerciseCount: asInt(json['exercise_count']),
    );
  }

  final int id;
  final int topicId;
  final String title;
  final String level;
  final String content;
  final List<GrammarExampleModel> examples;
  final String commonMistakes;
  final int exerciseCount;
}

class GrammarExerciseModel {
  const GrammarExerciseModel({
    required this.id,
    required this.lessonId,
    required this.exerciseType,
    required this.question,
    required this.options,
    required this.correctAnswer,
    required this.correctAnswers,
    required this.explanation,
  });

  factory GrammarExerciseModel.fromJson(Map<String, dynamic> json) {
    return GrammarExerciseModel(
      id: asInt(json['id']),
      lessonId: asInt(json['lesson_id']),
      exerciseType: json['exercise_type']?.toString() ?? 'multiple_choice',
      question: json['question']?.toString() ?? '',
      options: (json['options'] as List? ?? [])
          .map((item) => item.toString())
          .toList(),
      correctAnswer: json['correct_answer']?.toString() ?? '',
      correctAnswers: (json['correct_answers'] as List? ?? [])
          .map((item) => item.toString())
          .toList(),
      explanation: json['explanation']?.toString() ?? '',
    );
  }

  final int id;
  final int lessonId;
  final String exerciseType;
  final String question;
  final List<String> options;
  final String correctAnswer;
  final List<String> correctAnswers;
  final String explanation;
}

class GrammarDetailModel {
  const GrammarDetailModel({required this.lesson, required this.exercises});

  factory GrammarDetailModel.fromJson(Map<String, dynamic> json) {
    return GrammarDetailModel(
      lesson: GrammarLessonModel.fromJson(
        json['lesson'] as Map<String, dynamic>,
      ),
      exercises: (json['exercises'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(GrammarExerciseModel.fromJson)
          .toList(),
    );
  }

  final GrammarLessonModel lesson;
  final List<GrammarExerciseModel> exercises;
}

class GrammarSubmitResultModel {
  const GrammarSubmitResultModel({
    required this.correctCount,
    required this.wrongCount,
    required this.earnedXp,
    required this.progressPercent,
    required this.profile,
  });

  factory GrammarSubmitResultModel.fromJson(Map<String, dynamic> json) {
    return GrammarSubmitResultModel(
      correctCount: asInt(json['correct_count']),
      wrongCount: asInt(json['wrong_count']),
      earnedXp: asInt(json['earned_xp']),
      progressPercent: asInt(json['progress_percent']),
      profile: json['profile'] is Map<String, dynamic>
          ? UserModel.fromJson(json['profile'] as Map<String, dynamic>)
          : null,
    );
  }

  final int correctCount;
  final int wrongCount;
  final int earnedXp;
  final int progressPercent;
  final UserModel? profile;
}

class AiGeneratedGrammarLesson {
  const AiGeneratedGrammarLesson({
    required this.level,
    required this.topic,
    required this.icon,
    required this.durationMinutes,
    required this.lesson,
    required this.exercises,
  });

  factory AiGeneratedGrammarLesson.fromJson(Map<String, dynamic> json) {
    return AiGeneratedGrammarLesson(
      level: json['level']?.toString() ?? 'A1',
      topic: json['topic']?.toString() ?? '',
      icon: json['icon']?.toString() ?? 'school',
      durationMinutes: asInt(json['duration_minutes']),
      lesson: Map<String, dynamic>.from(json['lesson'] as Map? ?? {}),
      exercises: (json['exercises'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(),
    );
  }

  final String level;
  final String topic;
  final String icon;
  final int durationMinutes;
  final Map<String, dynamic> lesson;
  final List<Map<String, dynamic>> exercises;

  Map<String, dynamic> toSaveJson() {
    return {
      'level': level,
      'topic': topic,
      'icon': icon,
      'duration_minutes': durationMinutes,
      'lesson': lesson,
      'exercises': exercises,
    };
  }
}
