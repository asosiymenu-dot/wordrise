import 'json_helpers.dart';

class SpeakingQuestionModel {
  const SpeakingQuestionModel({
    required this.question,
    required this.topic,
    required this.level,
    required this.hintUz,
    required this.sampleAnswer,
  });

  factory SpeakingQuestionModel.fromJson(Map<String, dynamic> json) {
    return SpeakingQuestionModel(
      question: json['question']?.toString() ?? '',
      topic: json['topic']?.toString() ?? '',
      level: json['level']?.toString() ?? 'A1',
      hintUz: json['hint_uz']?.toString() ?? '',
      sampleAnswer: json['sample_answer']?.toString() ?? '',
    );
  }

  final String question;
  final String topic;
  final String level;
  final String hintUz;
  final String sampleAnswer;
}

class SpeakingFeedbackModel {
  const SpeakingFeedbackModel({
    required this.score,
    required this.isClear,
    required this.correctedAnswer,
    required this.feedbackUz,
    required this.pronunciationTipUz,
    required this.grammarTipUz,
    required this.nextQuestion,
  });

  factory SpeakingFeedbackModel.fromJson(Map<String, dynamic> json) {
    return SpeakingFeedbackModel(
      score: asInt(json['score']),
      isClear: asBool(json['is_clear']),
      correctedAnswer: json['corrected_answer']?.toString() ?? '',
      feedbackUz: json['feedback_uz']?.toString() ?? '',
      pronunciationTipUz: json['pronunciation_tip_uz']?.toString() ?? '',
      grammarTipUz: json['grammar_tip_uz']?.toString() ?? '',
      nextQuestion: json['next_question']?.toString() ?? '',
    );
  }

  final int score;
  final bool isClear;
  final String correctedAnswer;
  final String feedbackUz;
  final String pronunciationTipUz;
  final String grammarTipUz;
  final String nextQuestion;
}
