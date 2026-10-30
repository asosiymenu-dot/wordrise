import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/api_models.dart';

class OfflineCacheService {
  int _userId = 0;

  void useUser(int userId) {
    _userId = userId > 0 ? userId : 0;
  }

  String _key(String name) => 'wordrise_u${_userId}_$name';

  Future<void> saveLessons(List<LessonModel> lessons) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key('lessons_v1'),
      jsonEncode(lessons.map((item) => item.toJson()).toList()),
    );
  }

  Future<List<LessonModel>?> lessons() async {
    final raw = await _readList(_key('lessons_v1'));
    if (raw == null) return null;
    return raw.map(LessonModel.fromJson).toList();
  }

  Future<void> saveWords(int lessonId, List<WordModel> words) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key('words_${lessonId}_v1'),
      jsonEncode(words.map((item) => item.toJson()).toList()),
    );
  }

  Future<List<WordModel>?> words(int lessonId) async {
    final direct = await _readList(_key('words_${lessonId}_v1'));
    if (direct != null) return direct.map(WordModel.fromJson).toList();
    final pack = await smartPack();
    final packedWords = (pack?['words'] as List? ?? [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .where((item) => _int(item['lesson_id']) == lessonId)
        .map((item) {
          item['review_interval'] ??= item['interval'];
          return WordModel.fromJson(item);
        })
        .toList();
    return packedWords.isEmpty ? null : packedWords;
  }

  Future<void> saveSmartPack(Map<String, dynamic> pack) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key('smart_pack_v1'), jsonEncode(pack));
  }

  Future<Map<String, dynamic>?> smartPack() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key('smart_pack_v1'));
    if (raw == null || raw.isEmpty) return null;
    try {
      final value = jsonDecode(raw);
      return value is Map ? Map<String, dynamic>.from(value) : null;
    } on FormatException {
      return null;
    }
  }

  Future<void> saveOfflineSession(Map<String, dynamic> session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key('smart_session_v1'), jsonEncode(session));
  }

  Future<Map<String, dynamic>?> offlineSession() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key('smart_session_v1'));
    if (raw == null || raw.isEmpty) return null;
    try {
      final value = jsonDecode(raw);
      return value is Map ? Map<String, dynamic>.from(value) : null;
    } on FormatException {
      return null;
    }
  }

  Future<void> clearOfflineSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key('smart_session_v1'));
  }

  Future<void> clearAllCache() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('wordrise_u')).toList();
    for (final key in keys) {
      await prefs.remove(key);
    }
  }

  Future<List<Map<String, dynamic>>> pendingReviewEvents() async {
    return await _readList(_key('review_events_v1')) ?? [];
  }

  Future<void> savePendingReviewEvents(
    List<Map<String, dynamic>> events,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key('review_events_v1'),
      jsonEncode(events.take(500).toList()),
    );
  }

  Future<List<Map<String, dynamic>>?> _readList(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final value = jsonDecode(raw);
      if (value is! List) return null;
      return value
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } on FormatException {
      return null;
    }
  }
}

int _int(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
