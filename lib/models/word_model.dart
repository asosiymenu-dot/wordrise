import 'json_helpers.dart';

class WordModel {
  const WordModel({
    required this.id,
    required this.lessonId,
    required this.englishWord,
    required this.uzbekTranslation,
    required this.exampleSentence,
    required this.pronunciation,
    this.nextReviewAt,
    this.reviewInterval = 0,
    this.easeFactor = 2.5,
    this.isStarred = false,
    this.lessonTitle = '',
    this.status = 'new',
    this.correctCount = 0,
    this.wrongCount = 0,
    this.lapseCount = 0,
    this.consecutiveCorrect = 0,
    this.difficulty = 1,
  });

  factory WordModel.fromJson(Map<String, dynamic> json) {
    return WordModel(
      id: asInt(json['id']),
      lessonId: asInt(json['lesson_id']),
      englishWord: json['english_word']?.toString() ?? '',
      uzbekTranslation: json['uzbek_translation']?.toString() ?? '',
      exampleSentence: json['example_sentence']?.toString() ?? '',
      pronunciation: json['pronunciation']?.toString() ?? '',
      nextReviewAt: asNullableString(json['next_review_at']),
      reviewInterval: asInt(json['review_interval']),
      easeFactor: asDouble(json['ease_factor'], 2.5),
      isStarred: asBool(json['is_starred']),
      lessonTitle: json['lesson_title']?.toString() ?? '',
      status:
          json['status']?.toString() ??
          json['progress_status']?.toString() ??
          'new',
      correctCount: asInt(json['correct_count']),
      wrongCount: asInt(json['wrong_count']),
      lapseCount: asInt(json['lapse_count']),
      consecutiveCorrect: asInt(json['consecutive_correct']),
      difficulty: asDouble(json['difficulty'], 1),
    );
  }

  final int id;
  final int lessonId;
  final String englishWord;
  final String uzbekTranslation;
  final String exampleSentence;
  final String pronunciation;
  final String? nextReviewAt;
  final int reviewInterval;
  final double easeFactor;
  final bool isStarred;
  final String lessonTitle;
  final String status;
  final int correctCount;
  final int wrongCount;
  final int lapseCount;
  final int consecutiveCorrect;
  final double difficulty;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'lesson_id': lessonId,
      'lesson_title': lessonTitle,
      'english_word': englishWord,
      'uzbek_translation': uzbekTranslation,
      'example_sentence': exampleSentence,
      'pronunciation': pronunciation,
      'next_review_at': nextReviewAt,
      'review_interval': reviewInterval,
      'interval': reviewInterval,
      'ease_factor': easeFactor,
      'is_starred': isStarred,
      'status': status,
      'correct_count': correctCount,
      'wrong_count': wrongCount,
      'lapse_count': lapseCount,
      'consecutive_correct': consecutiveCorrect,
      'difficulty': difficulty,
    };
  }

  WordModel copyWith({bool? isStarred}) {
    return WordModel(
      id: id,
      lessonId: lessonId,
      englishWord: englishWord,
      uzbekTranslation: uzbekTranslation,
      exampleSentence: exampleSentence,
      pronunciation: pronunciation,
      nextReviewAt: nextReviewAt,
      reviewInterval: reviewInterval,
      easeFactor: easeFactor,
      isStarred: isStarred ?? this.isStarred,
      lessonTitle: lessonTitle,
      status: status,
      correctCount: correctCount,
      wrongCount: wrongCount,
      lapseCount: lapseCount,
      consecutiveCorrect: consecutiveCorrect,
      difficulty: difficulty,
    );
  }
}
