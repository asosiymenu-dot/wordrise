import 'dart:math';

import '../models/api_models.dart';
import 'api_service.dart';
import 'offline_cache_service.dart';

class OfflineLearningService {
  OfflineLearningService(this._api, this._cache);

  final ApiService _api;
  final OfflineCacheService _cache;

  Future<void> refreshPack() async {
    final data = await _api.get(
      '/smart_learn/offline_pack.php',
      query: {'limit': '200'},
      timeout: const Duration(seconds: 20),
    );
    final pack = data['pack'];
    if (pack is! Map) {
      throw const ApiException('Offline pack response is invalid.');
    }
    await _cache.saveSmartPack(Map<String, dynamic>.from(pack));
  }

  Future<SmartLearnDashboardModel> dashboard() async {
    final pack = await _requiredPack();
    final words = _maps(pack['words']);
    final counts = <String, int>{};
    for (final word in words) {
      final bucket = word['bucket']?.toString() ?? 'new';
      counts[bucket] = (counts[bucket] ?? 0) + 1;
    }
    final active = await _cache.offlineSession();
    final activeModel = active != null && active['status'] == 'active'
        ? _sessionModel(active)
        : null;
    return SmartLearnDashboardModel(
      dailyGoalMinutes: _integer(pack['daily_goal_minutes'], fallback: 10),
      preferredDirection: pack['preferred_direction']?.toString() ?? 'mixed',
      todayMinutes: 0,
      goalCompleted: false,
      dueCount: counts['due'] ?? 0,
      weakCount: counts['weak'] ?? 0,
      newCount: counts['new'] ?? 0,
      masteredCount: counts['mastered'] ?? counts['mature'] ?? 0,
      totalWords: words.length,
      suggestedCount: min(
        words.length,
        _integer(pack['daily_goal_minutes'], fallback: 10) * 2,
      ),
      starredCount: words.where((item) => item['is_starred'] == true).length,
      activeSession: activeModel,
    );
  }

  Future<SmartLearnStateModel> start({
    int? dailyGoalMinutes,
    String? direction,
    bool resume = true,
  }) async {
    if (resume) {
      final saved = await _cache.offlineSession();
      if (saved != null && saved['status'] == 'active') {
        return _state(saved);
      }
    }
    final pack = await _requiredPack();
    final allWords = _maps(pack['words']);
    if (allWords.isEmpty) {
      throw const ApiException(
        'Offline mashq uchun saqlangan so‘zlar yo‘q.',
        type: ApiExceptionType.network,
      );
    }
    final goal =
        dailyGoalMinutes ?? _integer(pack['daily_goal_minutes'], fallback: 10);
    final selected = _balancedWords(allWords, min(allWords.length, goal * 2));
    final now = DateTime.now();
    final nonce = now.microsecondsSinceEpoch.remainder(900000000);
    final safeDirection = _direction(
      direction ?? pack['preferred_direction']?.toString(),
    );
    final items = <Map<String, dynamic>>[];
    for (var index = 0; index < selected.length; index++) {
      items.add(
        _item(
          selected[index],
          allWords,
          index: index,
          itemId: -(nonce + index + 1),
          sessionDirection: safeDirection,
          attempt: 1,
        ),
      );
    }
    final session = <String, dynamic>{
      'id': -nonce,
      'status': 'active',
      'daily_goal_minutes': goal,
      'direction': safeDirection,
      'answered_count': 0,
      'correct_count': 0,
      'wrong_count': 0,
      'earned_xp': 0,
      'current_index': 0,
      'next_item_id': -(nonce + items.length + 1),
      'started_at': now.toIso8601String(),
      'last_activity_at': now.toIso8601String(),
      'items': items,
      'retry_word_ids': <int>[],
    };
    await _cache.saveOfflineSession(session);
    return _state(session);
  }

  Future<SmartLearnStateModel> state(int sessionId) async {
    final session = await _cache.offlineSession();
    if (session == null || _integer(session['id']) != sessionId) {
      throw const ApiException(
        'Offline sessiya topilmadi.',
        type: ApiExceptionType.network,
      );
    }
    return _state(session);
  }

  Future<SmartLearnStateModel> answer({
    required int sessionId,
    required int itemId,
    required String answer,
    required int answerMs,
  }) async {
    final session = await _cache.offlineSession();
    if (session == null || _integer(session['id']) != sessionId) {
      throw const ApiException(
        'Offline sessiya topilmadi.',
        type: ApiExceptionType.network,
      );
    }
    final items = _maps(session['items']);
    final currentIndex = _integer(session['current_index']);
    if (currentIndex >= items.length ||
        _integer(items[currentIndex]['item_id']) != itemId) {
      throw const ApiException('Savol allaqachon yangilangan.');
    }
    final item = items[currentIndex];
    final correctAnswer = item['correct_answer']?.toString() ?? '';
    final isCorrect = _same(answer, correctAnswer);
    final safeMs = answerMs.clamp(250, 120000).toInt();
    item['answered'] = true;
    item['given_answer'] = answer.trim();
    item['is_correct'] = isCorrect;
    item['answer_ms'] = safeMs;

    if (!isCorrect && _integer(item['attempt_no'], fallback: 1) == 1) {
      final wordId = _integer(item['word_id']);
      final scheduled = (session['retry_word_ids'] as List? ?? [])
          .map(_integer)
          .toSet();
      if (scheduled.add(wordId)) {
        final random = Random(DateTime.now().microsecondsSinceEpoch);
        var nextItemId = _integer(session['next_item_id']);
        final shortRetry = Map<String, dynamic>.from(item)
          ..['item_id'] = nextItemId--
          ..['attempt_no'] = 2
          ..['source_bucket'] = 'retry'
          ..remove('answered')
          ..remove('given_answer')
          ..remove('is_correct')
          ..remove('answer_ms');
        final finalRetry = Map<String, dynamic>.from(shortRetry)
          ..['item_id'] = nextItemId--
          ..['attempt_no'] = 3
          ..['source_bucket'] = 'final_retry';
        final insertAt = min(
          items.length,
          currentIndex + 3 + random.nextInt(3),
        );
        items.insert(insertAt, shortRetry);
        items.add(finalRetry);
        session['next_item_id'] = nextItemId;
        session['retry_word_ids'] = scheduled.toList();
      }
    }

    final events = await _cache.pendingReviewEvents();
    events.add({
      'client_event_id': _eventId(),
      'word_id': _integer(item['word_id']),
      'answer': answer.trim(),
      'direction': item['direction'],
      'answer_ms': safeMs,
      'answered_at': DateTime.now().toUtc().toIso8601String(),
    });
    await _cache.savePendingReviewEvents(events);

    session['answered_count'] = _integer(session['answered_count']) + 1;
    session['correct_count'] =
        _integer(session['correct_count']) + (isCorrect ? 1 : 0);
    session['wrong_count'] =
        _integer(session['wrong_count']) + (isCorrect ? 0 : 1);
    session['earned_xp'] =
        _integer(session['earned_xp']) +
        (isCorrect ? (safeMs <= 5000 ? 5 : 4) : 0);
    session['current_index'] = currentIndex + 1;
    session['last_activity_at'] = DateTime.now().toIso8601String();
    session['items'] = items;
    if (_integer(session['current_index']) >= items.length) {
      session['status'] = 'completed';
      session['completed_at'] = DateTime.now().toIso8601String();
    }
    await _cache.saveOfflineSession(session);
    return _state(
      session,
      feedback: SmartLearnFeedbackModel(
        isCorrect: isCorrect,
        correctAnswer: correctAnswer,
        givenAnswer: answer.trim(),
        answerMs: safeMs,
        code: isCorrect
            ? (safeMs > 10000 ? 'correct_slow' : 'correct')
            : 'wrong',
        explanation: isCorrect
            ? 'Correct. The next review interval will grow after sync.'
            : 'Correct answer: $correctAnswer',
        exampleSentence: item['example_sentence']?.toString() ?? '',
        duplicate: false,
      ),
    );
  }

  Future<UserModel?> syncPending() async {
    final all = await _cache.pendingReviewEvents();
    if (all.isEmpty) return null;
    UserModel? profile;
    var offset = 0;
    while (offset < all.length) {
      final batch = all.skip(offset).take(100).toList();
      final data = await _api.post('/smart_learn/sync.php', {'events': batch});
      if (data['profile'] is Map<String, dynamic>) {
        profile = UserModel.fromJson(data['profile'] as Map<String, dynamic>);
      }
      offset += batch.length;
    }
    await _cache.savePendingReviewEvents([]);
    await refreshPack();
    return profile;
  }

  Future<Map<String, dynamic>> _requiredPack() async {
    final pack = await _cache.smartPack();
    if (pack == null) {
      throw const ApiException(
        'Offline mashq hali yuklanmagan. Internetga ulanib bir marta yangilang.',
        type: ApiExceptionType.network,
      );
    }
    return pack;
  }

  SmartLearnStateModel _state(
    Map<String, dynamic> session, {
    SmartLearnFeedbackModel? feedback,
  }) {
    final items = _maps(session['items']);
    final current = _integer(session['current_index']);
    SmartLearnQuestionModel? question;
    if (session['status'] == 'active' && current < items.length) {
      question = _question(items[current], current);
    }
    return SmartLearnStateModel(
      session: _sessionModel(session),
      question: question,
      feedback: feedback,
      offline: true,
    );
  }

  SmartLearnSessionModel _sessionModel(Map<String, dynamic> session) {
    final items = _maps(session['items']);
    final answered = _integer(session['answered_count']);
    return SmartLearnSessionModel(
      id: _integer(session['id']),
      status: session['status']?.toString() ?? 'active',
      dailyGoalMinutes: _integer(session['daily_goal_minutes'], fallback: 10),
      direction: session['direction']?.toString() ?? 'mixed',
      plannedCount: items.length,
      answeredCount: answered,
      correctCount: _integer(session['correct_count']),
      wrongCount: _integer(session['wrong_count']),
      earnedXp: _integer(session['earned_xp']),
      progress: items.isEmpty
          ? 1
          : (answered / items.length).clamp(0, 1).toDouble(),
      startedAt: session['started_at']?.toString() ?? '',
      lastActivityAt: session['last_activity_at']?.toString() ?? '',
      completedAt: session['completed_at']?.toString(),
    );
  }

  SmartLearnQuestionModel _question(Map<String, dynamic> item, int index) {
    return SmartLearnQuestionModel(
      itemId: _integer(item['item_id']),
      wordId: _integer(item['word_id']),
      position: index + 1,
      sourceBucket: item['source_bucket']?.toString() ?? 'new',
      attemptNo: _integer(item['attempt_no'], fallback: 1),
      direction: item['direction']?.toString() ?? 'eng_to_uz',
      mode: item['mode']?.toString() ?? 'choice',
      prompt: item['prompt']?.toString() ?? '',
      options: (item['options'] as List? ?? [])
          .map((value) => value.toString())
          .toList(),
      pronunciation: item['pronunciation']?.toString() ?? '',
      exampleSentence: item['example_sentence']?.toString() ?? '',
      hint: item['hint']?.toString() ?? '',
    );
  }

  Map<String, dynamic> _item(
    Map<String, dynamic> word,
    List<Map<String, dynamic>> pool, {
    required int index,
    required int itemId,
    required String sessionDirection,
    required int attempt,
  }) {
    final direction = sessionDirection == 'mixed'
        ? (index % 3 == 2 ? 'uz_to_eng' : 'eng_to_uz')
        : sessionDirection;
    final prompt = direction == 'uz_to_eng'
        ? word['uzbek_translation']?.toString() ?? ''
        : word['english_word']?.toString() ?? '';
    final correct = direction == 'uz_to_eng'
        ? word['english_word']?.toString() ?? ''
        : word['uzbek_translation']?.toString() ?? '';
    final mode = index % 5 == 4 ? 'typing' : 'choice';
    final optionField = direction == 'uz_to_eng'
        ? 'english_word'
        : 'uzbek_translation';
    final options = <String>{correct};
    final shuffled = List<Map<String, dynamic>>.from(pool)
      ..shuffle(Random(itemId.abs()));
    for (final candidate in shuffled) {
      final value = candidate[optionField]?.toString().trim() ?? '';
      if (value.isNotEmpty) options.add(value);
      if (options.length >= 4) break;
    }
    final optionList = options.toList()..shuffle(Random(itemId.abs() + 17));
    return {
      'item_id': itemId,
      'word_id': _integer(word['id']),
      'source_bucket': word['bucket']?.toString() ?? 'new',
      'attempt_no': attempt,
      'direction': direction,
      'mode': mode,
      'prompt': prompt,
      'correct_answer': correct,
      'options': mode == 'typing' ? <String>[] : optionList,
      'pronunciation': word['pronunciation']?.toString() ?? '',
      'example_sentence': word['example_sentence']?.toString() ?? '',
      'hint': _hint(correct),
    };
  }

  List<Map<String, dynamic>> _balancedWords(
    List<Map<String, dynamic>> words,
    int target,
  ) {
    final groups = <String, List<Map<String, dynamic>>>{
      'due': [],
      'weak': [],
      'new': [],
      'mastered': [],
    };
    for (final word in words) {
      var bucket = word['bucket']?.toString() ?? 'new';
      if (word['is_starred'] == true) bucket = 'weak';
      if (!groups.containsKey(bucket)) bucket = 'mastered';
      groups[bucket]!.add(word);
    }
    for (final group in groups.values) {
      group.sort((a, b) {
        final aScore =
            _integer(a['lapse_count']) * 3 +
            _integer(a['wrong_count']) * 2 +
            (a['is_starred'] == true ? 5 : 0);
        final bScore =
            _integer(b['lapse_count']) * 3 +
            _integer(b['wrong_count']) * 2 +
            (b['is_starred'] == true ? 5 : 0);
        return bScore.compareTo(aScore);
      });
    }
    final result = <Map<String, dynamic>>[];
    const cycle = ['due', 'weak', 'new', 'weak', 'due', 'new', 'mastered'];
    var cursor = 0;
    while (result.length < target &&
        groups.values.any((list) => list.isNotEmpty)) {
      final key = cycle[cursor++ % cycle.length];
      final group = groups[key]!;
      if (group.isNotEmpty) result.add(group.removeAt(0));
    }
    return result;
  }
}

List<Map<String, dynamic>> _maps(Object? value) {
  return (value as List? ?? [])
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}

int _integer(Object? value, {int fallback = 0}) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

String _direction(String? value) {
  return const {'eng_to_uz', 'uz_to_eng', 'mixed'}.contains(value)
      ? value!
      : 'mixed';
}

String _hint(String answer) {
  final clean = answer.trim();
  if (clean.isEmpty) return '';
  return '${clean.substring(0, 1)}${List.filled(min(8, clean.length - 1), '_').join()}';
}

bool _same(String left, String right) {
  String normalize(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r"[’`ʻʼ]"), "'")
      .replaceAll(RegExp(r'\s+'), ' ');
  return normalize(left) == normalize(right);
}

String _eventId() {
  final now = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  final random = Random.secure().nextInt(1 << 32).toRadixString(36);
  return 'off$now$random'.substring(0, min(64, 3 + now.length + random.length));
}
