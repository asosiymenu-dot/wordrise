import '../services/api_service.dart';
import '../services/app_notification_service.dart';
import '../services/app_update_service.dart';
import '../services/ai_service.dart';
import '../services/auth_service.dart';
import '../services/battle_service.dart';
import '../services/grammar_service.dart';
import '../services/leaderboard_service.dart';
import '../services/message_service.dart';
import '../services/offline_cache_service.dart';
import '../services/offline_learning_service.dart';
import '../services/presence_service.dart';
import '../services/lesson_service.dart';
import '../services/quiz_service.dart';
import '../services/speaking_service.dart';
import '../services/smart_learn_service.dart';
import '../services/word_service.dart';
import '../services/websocket_service.dart';

class AppServices {
  AppServices() {
    api = ApiService();
    appUpdate = AppUpdateService(api);
    offlineCache = OfflineCacheService();
    offlineLearning = OfflineLearningService(api, offlineCache);
    auth = AuthService(api);
    lessons = LessonService(api, offlineCache);
    words = WordService(api, offlineCache);
    quiz = QuizService(api);
    ai = AiService(api);
    grammar = GrammarService(api);
    leaderboard = LeaderboardService(api);
    messages = MessageService(api);
    presence = PresenceService(api);
    battle = BattleService(api);
    speaking = SpeakingService(api);
    smartLearn = SmartLearnService(api, offlineLearning);
    notifications = AppNotificationService(api);
    websocket = WebSocketService(api.baseUrl);
  }

  late final ApiService api;
  late final AppUpdateService appUpdate;
  late final OfflineCacheService offlineCache;
  late final OfflineLearningService offlineLearning;
  late final AuthService auth;
  late final LessonService lessons;
  late final WordService words;
  late final QuizService quiz;
  late final AiService ai;
  late final GrammarService grammar;
  late final LeaderboardService leaderboard;
  late final MessageService messages;
  late final PresenceService presence;
  late final BattleService battle;
  late final SpeakingService speaking;
  late final SmartLearnService smartLearn;
  late final AppNotificationService notifications;
  late final WebSocketService websocket;
}
