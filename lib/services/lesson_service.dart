import '../models/api_models.dart';
import 'api_service.dart';
import 'offline_cache_service.dart';

class LessonPage {
  const LessonPage({required this.lessons, required this.hasMore});
  final List<LessonModel> lessons;
  final bool hasMore;
}

class LessonService {
  LessonService(this._api, [OfflineCacheService? cache])
    : _cache = cache ?? OfflineCacheService();

  final ApiService _api;
  final OfflineCacheService _cache;

  Future<List<LessonModel>> all() async {
    final page = await fetchPage();
    return page.lessons;
  }

  Future<LessonPage> fetchPage({int limit = 50, int afterId = 0}) async {
    try {
      final data = await _api.get('/lessons/index.php', query: {
        'limit': limit.toString(),
        if (afterId > 0) 'after_id': afterId.toString(),
        't': DateTime.now().millisecondsSinceEpoch.toString()
      });
      final lessons = (data['lessons'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(LessonModel.fromJson)
          .toList();
      final hasMore = data['has_more'] == true;
      if (afterId == 0) {
        await _cache.saveLessons(lessons);
      }
      return LessonPage(lessons: lessons, hasMore: hasMore);
    } on ApiException catch (error) {
      if (!error.isNetwork || afterId > 0) rethrow;
      final cached = await _cache.lessons();
      if (cached == null) rethrow;
      return LessonPage(lessons: cached, hasMore: false);
    }
  }

  Future<LessonModel> create({
    required String title,
    required String description,
    required String category,
  }) async {
    final data = await _api.post('/lessons/create.php', {
      'title': title,
      'description': description,
      'category': category,
    });
    return LessonModel.fromJson(data['lesson'] as Map<String, dynamic>);
  }

  Future<LessonModel> update({
    required int id,
    required String title,
    required String description,
    required String category,
  }) async {
    final data = await _api.put('/lessons/update.php', {
      'id': id,
      'title': title,
      'description': description,
      'category': category,
    });
    return LessonModel.fromJson(data['lesson'] as Map<String, dynamic>);
  }

  Future<void> delete(int id) async {
    await _api.delete('/lessons/delete.php', body: {'id': id});
  }

  Future<Map<String, dynamic>> exportBundle(int id) async {
    final data = await _api.get(
      '/lessons/export.php',
      query: {'id': id.toString()},
    );
    return data['bundle'] is Map<String, dynamic>
        ? data['bundle'] as Map<String, dynamic>
        : <String, dynamic>{};
  }

  Future<LessonModel> importBundle(Map<String, dynamic> bundle) async {
    final data = await _api.post('/lessons/import.php', bundle);
    return LessonModel.fromJson(data['lesson'] as Map<String, dynamic>);
  }

  Future<LessonShareModel> shareLesson(int lessonId) async {
    final data = await _api.post('/lessons/share.php', {'lesson_id': lessonId});
    return LessonShareModel.fromJson(data);
  }

  Future<PublicLessonModel> fetchLessonByCode(
    String code, {
    bool includeWords = false,
  }) async {
    final data = await _api.get(
      '/lessons/by_code.php',
      query: {'code': code, if (includeWords) 'include_words': '1'},
    );
    return PublicLessonModel.fromJson(data['lesson'] as Map<String, dynamic>);
  }

  Future<LessonModel> importLessonByCode(String code) async {
    final data = await _api.post('/lessons/import.php', {'share_code': code});
    return LessonModel.fromJson(data['lesson'] as Map<String, dynamic>);
  }

  Future<DiscoverLessonsPage> discover({
    String query = '',
    String category = '',
    String sort = 'popular',
    int page = 1,
    int perPage = 20,
  }) async {
    final data = await _api.get(
      '/lessons/discover.php',
      query: {
        'q': query,
        'category': category,
        'sort': sort,
        'page': page.toString(),
        'per_page': perPage.toString(),
      },
    );
    return DiscoverLessonsPage.fromJson(data);
  }

  Future<LessonModel> togglePublic({
    required int lessonId,
    required bool isPublic,
  }) async {
    final data = await _api.post('/lessons/toggle_public.php', {
      'lesson_id': lessonId,
      'is_public': isPublic,
    });
    return LessonModel.fromJson(data['lesson'] as Map<String, dynamic>);
  }
}
