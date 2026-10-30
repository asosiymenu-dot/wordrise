import 'json_helpers.dart';
import 'word_model.dart';

class LessonShareModel {
  const LessonShareModel({
    required this.shareCode,
    required this.shareUrl,
    required this.appLink,
  });

  factory LessonShareModel.fromJson(Map<String, dynamic> json) {
    return LessonShareModel(
      shareCode: json['share_code']?.toString() ?? '',
      shareUrl: json['share_url']?.toString() ?? '',
      appLink: json['app_link']?.toString() ?? '',
    );
  }

  final String shareCode;
  final String shareUrl;
  final String appLink;
}

class PublicLessonModel {
  const PublicLessonModel({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.shareCode,
    required this.wordCount,
    required this.importCount,
    required this.authorName,
    this.authorAvatar,
    this.words = const [],
  });

  factory PublicLessonModel.fromJson(Map<String, dynamic> json) {
    return PublicLessonModel(
      id: asInt(json['id']),
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      category: json['category']?.toString() ?? 'General',
      shareCode: json['share_code']?.toString() ?? '',
      wordCount: asInt(json['word_count']),
      importCount: asInt(json['import_count']),
      authorName: json['author_name']?.toString() ?? '',
      authorAvatar: asNullableString(json['author_avatar']),
      words: (json['words'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(WordModel.fromJson)
          .toList(),
    );
  }

  final int id;
  final String title;
  final String description;
  final String category;
  final String shareCode;
  final int wordCount;
  final int importCount;
  final String authorName;
  final String? authorAvatar;
  final List<WordModel> words;
}

class DiscoverLessonsPage {
  const DiscoverLessonsPage({
    required this.lessons,
    required this.page,
    required this.perPage,
    required this.hasMore,
  });

  factory DiscoverLessonsPage.fromJson(Map<String, dynamic> json) {
    return DiscoverLessonsPage(
      lessons: (json['lessons'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(PublicLessonModel.fromJson)
          .toList(),
      page: asInt(json['page']),
      perPage: asInt(json['per_page']),
      hasMore: asBool(json['has_more']),
    );
  }

  final List<PublicLessonModel> lessons;
  final int page;
  final int perPage;
  final bool hasMore;
}

class AiWordSuggestion {
  const AiWordSuggestion({
    required this.englishWord,
    required this.uzbekTranslation,
    required this.exampleSentence,
    required this.exampleSentenceUz,
    required this.pronunciation,
    required this.partOfSpeech,
    required this.synonyms,
    required this.difficultyLevel,
  });

  factory AiWordSuggestion.fromJson(Map<String, dynamic> json) {
    return AiWordSuggestion(
      englishWord: json['english_word']?.toString() ?? '',
      uzbekTranslation: json['uzbek_translation']?.toString() ?? '',
      exampleSentence: json['example_sentence']?.toString() ?? '',
      exampleSentenceUz: json['example_sentence_uz']?.toString() ?? '',
      pronunciation: json['pronunciation']?.toString() ?? '',
      partOfSpeech: json['part_of_speech']?.toString() ?? 'other',
      synonyms: (json['synonyms'] as List? ?? [])
          .map((item) => item.toString())
          .toList(),
      difficultyLevel: json['difficulty_level']?.toString() ?? 'A1',
    );
  }

  final String englishWord;
  final String uzbekTranslation;
  final String exampleSentence;
  final String exampleSentenceUz;
  final String pronunciation;
  final String partOfSpeech;
  final List<String> synonyms;
  final String difficultyLevel;

  Map<String, String> toWordJson() {
    return {
      'english_word': englishWord,
      'uzbek_translation': uzbekTranslation,
      'example_sentence': exampleSentence,
      'pronunciation': pronunciation,
    };
  }
}

class AiGeneratedLesson {
  const AiGeneratedLesson({required this.lesson, required this.words});

  factory AiGeneratedLesson.fromJson(Map<String, dynamic> json) {
    return AiGeneratedLesson(
      lesson: Map<String, dynamic>.from(json['lesson'] as Map? ?? {}),
      words: (json['words'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(AiWordSuggestion.fromJson)
          .toList(),
    );
  }

  final Map<String, dynamic> lesson;
  final List<AiWordSuggestion> words;
}
