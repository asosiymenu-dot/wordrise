import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';

import '../core/localization/app_localizations.dart';
import '../features/auth/login_register_screen.dart';
import '../features/auth/onboarding_screen.dart';
import '../features/auth/splash_screen.dart';
import '../features/battle/battle_screen.dart';
import '../features/battle/battle_lobby_screen.dart';
import '../features/home/home_screen.dart';
import '../features/leaderboard/leaderboard_screen.dart';
import '../features/lessons/lesson_list_screen.dart';
import '../features/lessons/lesson_share_import_sheet.dart';
import '../features/lessons/starred_words_screen.dart';
import '../features/messages/messages_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/quiz/quiz_mode_selection_screen.dart';
import '../features/quiz/quiz_screen.dart';
import '../features/smart_learn/smart_learn_screen.dart';
import '../features/update/forced_update_screen.dart';
import '../models/api_models.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../services/push_notification_service.dart';
import 'app_services.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    required this.themeMode,
    required this.locale,
    required this.onThemeModeChanged,
    required this.onLocaleChanged,
    super.key,
  });

  final ThemeMode themeMode;
  final Locale locale;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final ValueChanged<Locale> onLocaleChanged;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  final _services = AppServices();
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSub;
  Timer? _heartbeatTimer;
  bool _messageNotificationsPrimed = false;
  bool _appNotificationsPrimed = false;
  final Set<int> _notifiedMessageIds = {};
  int _lastAppNotificationId = 0;
  int _messageUnreadCount = 0;
  bool _pollingNotifications = false;
  UserModel? _user;
  ProfileStatsModel? _stats;
  bool _booting = true;
  bool _showOnboarding = true;
  bool _offlineMode = false;
  bool _showingImportPreview = false;
  String? _pendingShareCode;
  bool _appForeground = true;
  AppReleaseModel? _requiredUpdate;
  bool _checkingUpdate = false;
  StreamSubscription? _wsAppSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadProfile();
    _initDeepLinks();
  }

  @override
  void didUpdateWidget(covariant AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.locale.languageCode != widget.locale.languageCode) {
      if (_user != null) {
        unawaited(
          PushNotificationService.instance.updateLocale(
            widget.locale.languageCode,
          ),
        );
      }
      unawaited(_checkForRequiredUpdate());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _linkSub?.cancel();
    _heartbeatTimer?.cancel();
    _wsAppSubscription?.cancel();
    _services.websocket.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground = state == AppLifecycleState.resumed;
    if (_appForeground == foreground) return;
    _appForeground = foreground;
    if (foreground) {
      unawaited(_checkForRequiredUpdate(showProgress: _requiredUpdate != null));
    }
    if (foreground && _user != null && _requiredUpdate == null) {
      _startHeartbeat();
      _startMessageNotifications();
    } else {
      _heartbeatTimer?.cancel();
      _heartbeatTimer = null;
      _pauseMessageNotifications();
    }
  }

  void _startMessageNotifications() {
    if (!_appForeground || _user == null) return;
    _messageNotificationsPrimed = false;
    _appNotificationsPrimed = false;
    _notifiedMessageIds.clear();
    _lastAppNotificationId = 0;
    unawaited(NotificationService.instance.initialize());
    unawaited(_pollMessageNotifications(seed: true));
  }

  void _stopMessageNotifications() {
    _messageNotificationsPrimed = false;
    _appNotificationsPrimed = false;
    _notifiedMessageIds.clear();
    _lastAppNotificationId = 0;
    if (mounted && _messageUnreadCount != 0) {
      setState(() => _messageUnreadCount = 0);
    }
  }

  void _pauseMessageNotifications() {
    // No-op now since we removed polling
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    if (!_appForeground || _user == null) return;
    unawaited(_sendHeartbeat());
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      unawaited(_sendHeartbeat());
    });
  }

  Future<void> _sendHeartbeat() async {
    if (!_appForeground || _user == null) return;
    try {
      await _services.presence.heartbeat();
    } on Object {
      // Presence is best effort and must never disturb the active screen.
    }
  }

  Future<void> _pollMessageNotifications({bool seed = false}) async {
    final user = _user;
    if (user == null || !_appForeground || _pollingNotifications) return;
    final photoMessageLabel = context.l10n.t('messages.photo');
    _pollingNotifications = true;
    try {
      final conversations = await _services.messages.conversations();
      final unreadCount = conversations.fold<int>(
        0,
        (total, item) => total + item.unreadCount,
      );
      if (mounted && unreadCount != _messageUnreadCount) {
        setState(() => _messageUnreadCount = unreadCount);
      }
      final incoming = conversations
          .where(
            (item) =>
                item.lastMessage != null &&
                item.lastMessage!.senderId != user.id &&
                item.unreadCount > 0,
          )
          .toList();

      for (final item in incoming) {
        final lastMessage = item.lastMessage;
        if (lastMessage == null || lastMessage.deliveredAt != null) continue;
        unawaited(
          _services.messages
              .markDelivered(
                userId: item.user.id,
                upToMessageId: lastMessage.id,
              )
              .catchError((Object _) {}),
        );
      }

      if (seed || !_messageNotificationsPrimed) {
        for (final item in incoming) {
          _notifiedMessageIds.add(item.lastMessage!.id);
        }
        _messageNotificationsPrimed = true;
      } else {
        incoming.sort((a, b) => a.lastMessage!.id.compareTo(b.lastMessage!.id));
        for (final item in incoming) {
          final message = item.lastMessage!;
          if (!_notifiedMessageIds.add(message.id)) continue;
          if (message.type.startsWith('battle_')) continue;
          await NotificationService.instance.showMessage(
            messageId: message.id,
            senderName: item.user.name,
            body: message.type == 'image' ? photoMessageLabel : message.body,
          );
        }
      }

      final batch = await _services.notifications.list(
        afterId: _appNotificationsPrimed ? _lastAppNotificationId : 0,
      );
      if (batch.notifications.isNotEmpty) {
        if (batch.notifications.last.id > _lastAppNotificationId) {
          _lastAppNotificationId = batch.notifications.last.id;
        }
      }
      if (seed || !_appNotificationsPrimed) {
        if (batch.maxId > _lastAppNotificationId) {
          _lastAppNotificationId = batch.maxId;
        }
        _appNotificationsPrimed = true;
      } else {
        for (final event in batch.notifications) {
          if (event.type == 'message' || event.type == 'admin_message') {
            continue;
          }
          final content = _localizedNotification(event);
          await NotificationService.instance.showEvent(
            notificationId: event.id,
            title: content.$1,
            body: content.$2,
            type: event.type,
          );
        }
      }
    } on ApiException {
      // Network hiccups should not disturb the current screen.
    } on Object {
      // Notifications are best effort; chat data itself remains the source.
    } finally {
      _pollingNotifications = false;
    }
  }

  (String, String) _localizedNotification(AppNotificationModel event) {
    final l10n = context.l10n;
    switch (event.type) {
      case 'battle_invite':
        final name = event.data['sender_name']?.toString().trim() ?? '';
        return name.isEmpty
            ? (event.title, event.body)
            : (
                l10n.t('battle.notification.inviteTitle'),
                l10n.f('battle.notification.inviteBody', {'name': name}),
              );
      case 'battle_accepted':
        final name = event.data['responder_name']?.toString().trim() ?? '';
        return name.isEmpty
            ? (event.title, event.body)
            : (
                l10n.t('battle.notification.acceptedTitle'),
                l10n.f('battle.notification.acceptedBody', {'name': name}),
              );
      case 'battle_declined':
        return (
          l10n.t('battle.notification.declinedTitle'),
          l10n.t('battle.notification.declinedBody'),
        );
      case 'battle_cancelled':
        return (
          l10n.t('battle.notification.cancelledTitle'),
          l10n.t('battle.notification.cancelledBody'),
        );
      case 'battle_result':
        final draw = event.data['draw'];
        final winnerName = event.data['winner_name']?.toString().trim() ?? '';
        final String body;
        if (draw == true || draw?.toString() == '1') {
          body = l10n.t('battle.draw');
        } else if (winnerName.isNotEmpty) {
          body = l10n.f('battle.winner', {'name': winnerName});
        } else {
          body = event.body;
        }
        return (l10n.t('battle.notification.resultTitle'), body);
      case 'daily_reminder':
        return (
          l10n.t('notifications.dailyTitle'),
          l10n.t('notifications.dailyBody'),
        );
      case 'streak_risk':
        return (
          l10n.t('notifications.riskTitle'),
          l10n.t('notifications.riskBody'),
        );
      default:
        return (event.title, event.body);
    }
  }

  Future<void> _initDeepLinks() async {
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) _handleIncomingLink(initial);
    } on Object {
      // Deep links should never block normal startup.
    }
    _linkSub = _appLinks.uriLinkStream.listen(
      _handleIncomingLink,
      onError: (_) {},
    );
  }

  void _handleIncomingLink(Uri uri) {
    final code = extractLessonShareCode(uri.toString());
    if (code == null) {
      _handleDeepLink(uri);
      return;
    }
    _pendingShareCode = code;
    _tryShowPendingImport();
  }

  void _handleDeepLink(Uri uri) {
    if (!mounted) return;
    if (uri.path.contains('/lessons/')) {
      final id = uri.pathSegments.last;
      if (id.isNotEmpty) {
        // We will just show a snackbar or push
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Deep link received for lesson: $id')),
        );
      }
    } else if (uri.path.contains('/quiz/')) {
      if (_user == null) {
        // Just show a snackbar or ignore, we can't open quiz without a user
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.t('common.sessionExpired'))),
        );
        return;
      }
      
      // Just push quiz mode selection
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => QuizModeSelectionScreen(
            lessonService: _services.lessons,
            wordService: _services.words,
            quizService: _services.quiz,
            battleService: _services.battle,
            currentUser: _user!,
            onProfileChanged: _setUser,
          ),
        ),
      );
    }
  }

  Future<void> _tryShowPendingImport() async {
    if (!mounted ||
        _booting ||
        _user == null ||
        _showingImportPreview ||
        _pendingShareCode == null) {
      return;
    }
    final code = _pendingShareCode!;
    _pendingShareCode = null;
    _showingImportPreview = true;
    await showLessonImportPreviewSheet(
      context: context,
      lessonService: _services.lessons,
      code: code,
    );
    _showingImportPreview = false;
  }

  Future<void> _loadProfile() async {
    final updateFuture = _checkForRequiredUpdate();
    try {
      final token = await _services.api.token;
      if (token != null) {
        try {
          _user = await _services.auth.profile();
          _stats = await _services.auth.stats();
          _services.offlineCache.useUser(_user!.id);
          _offlineMode = false;
        } on ApiException catch (error) {
          if (error.isUnauthorized) {
            await _services.api.clearToken();
            _user = null;
            _stats = null;
            _offlineMode = false;
          } else if (error.isNetwork) {
            _user = await _services.auth.cachedProfile();
            if (_user != null) _services.offlineCache.useUser(_user!.id);
            _showOnboarding = _user == null;
            _offlineMode = _user != null;
          } else {
            rethrow;
          }
        }
        _showOnboarding = false;
      }
    } on ApiException catch (error) {
      if (error.isUnauthorized) {
        await _services.api.clearToken();
      }
      _user = null;
    } finally {
      await updateFuture;
      if (mounted) {
        setState(() => _booting = false);
        if (_user == null) {
          _stopMessageNotifications();
        } else {
          _activateUserServices();
          _startMessageNotifications();
        }
        _tryShowPendingImport();
      }
    }
  }

  Future<void> _checkForRequiredUpdate({bool showProgress = false}) async {
    if (_checkingUpdate) return;
    _checkingUpdate = true;
    if (showProgress && mounted) setState(() {});
    try {
      final decision = await _services.appUpdate.check(
        locale: widget.locale.languageCode,
      );
      if (!mounted) return;
      final release = decision.forceUpdate ? decision.release : null;
      final wasRequired = _requiredUpdate != null;
      setState(() => _requiredUpdate = release);
      if (release != null) {
        _heartbeatTimer?.cancel();
        _heartbeatTimer = null;
        _pauseMessageNotifications();
      } else if (wasRequired && _user != null) {
        _activateUserServices();
        _startMessageNotifications();
      }
    } on Object {
      // A version check must not break offline startup.
    } finally {
      _checkingUpdate = false;
      if (showProgress && mounted) setState(() {});
    }
  }

  void _setUser(UserModel user) {
    final accountChanged = _user?.id != user.id;
    _services.offlineCache.useUser(user.id);
    setState(() {
      _user = user;
      _showOnboarding = false;
      _offlineMode = false;
    });
    if (accountChanged) {
      _activateUserServices();
      _startMessageNotifications();
    }
    _tryShowPendingImport();
    unawaited(_refreshStats());
  }

  Future<void> _refreshStats() async {
    if (_user == null) return;
    try {
      final stats = await _services.auth.stats();
      if (mounted) setState(() => _stats = stats);
    } on Object {
      // Ignore network errors
    }
  }

  Future<void> _logout() async {
    await PushNotificationService.instance.deactivate();
    await _services.auth.logout();
    if (!mounted) return;
    _stopMessageNotifications();
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _services.websocket.disconnect();
    _services.offlineCache.useUser(0);
    Navigator.of(context).popUntil((route) => route.isFirst);
    setState(() {
      _user = null;
      _showOnboarding = false;
      _offlineMode = false;
    });
  }

  void _activateUserServices() {
    final user = _user;
    if (user == null) return;
    _services.offlineCache.useUser(user.id);
    _startHeartbeat();
    unawaited(
      PushNotificationService.instance.activate(
        backend: _services.notifications,
        locale: widget.locale.languageCode,
        onOpened: _handlePushOpened,
      ),
    );
    unawaited(_prepareOfflineLearning());
    unawaited(_services.api.token.then((token) {
      if (token != null) {
        _services.websocket.connect(token);
        _wsAppSubscription?.cancel();
        _wsAppSubscription = _services.websocket.events.listen((event) {
          if (!mounted) return;
          final type = event['type'] as String?;
          if (type == 'xp_updated' || type == 'level_updated' || type == 'user_updated') {
            unawaited(_refreshStats());
          } else if (type == 'new_message' && !_pollingNotifications) {
            unawaited(_pollMessageNotifications(seed: false));
          } else if (type == 'reconnected') {
            unawaited(_refreshStats());
          } else if (type == 'session_revoked') {
            unawaited(_logout());
          }
        });
      }
    }));
  }

  Future<void> _prepareOfflineLearning() async {
    try {
      final profile = await _services.smartLearn.syncPending();
      if (profile != null && mounted) _setUserWithoutRestart(profile);
    } on Object {
      // Pending answers remain queued until a later successful connection.
    }
    try {
      await _services.smartLearn.refreshOfflinePack();
    } on Object {
      // The previous pack remains available offline.
    }
  }

  void _setUserWithoutRestart(UserModel user) {
    if (!mounted) return;
    setState(() => _user = user);
    unawaited(_refreshStats());
  }

  void _setMessageUnreadCount(int value) {
    if (!mounted || value == _messageUnreadCount) return;
    setState(() => _messageUnreadCount = value);
  }

  Future<void> _handlePushOpened(Map<String, dynamic> data) async {
    if (!mounted || _user == null) return;
    final type = data['type']?.toString() ?? '';
    final battleId = int.tryParse(data['battle_id']?.toString() ?? '');
    if (battleId != null &&
        (type == 'battle_accepted' || type == 'battle_result')) {
      try {
        final battle = await _services.battle.state(battleId);
        if (!mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                BattleScreen(service: _services.battle, initialBattle: battle),
          ),
        );
        return;
      } on Object {
        // Fall back to the chat where the invite/result card is available.
      }
    }
    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MessagesScreen(
            active: true,
            currentUser: _user!,
            service: _services.messages,
            battleService: _services.battle,
            lessonService: _services.lessons,
            presenceService: _services.presence,
            websocketService: _services.websocket,
            onUnreadChanged: _setMessageUnreadCount,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_booting) return const SplashScreen();

    final requiredUpdate = _requiredUpdate;
    if (requiredUpdate != null) {
      return ForcedUpdateScreen(
        release: requiredUpdate,
        checking: _checkingUpdate,
        onDownload: () => _services.appUpdate.openDownload(requiredUpdate),
        onCheckAgain: () => _checkForRequiredUpdate(showProgress: true),
      );
    }

    final user = _user;
    if (user == null) {
      if (_showOnboarding) {
        return OnboardingScreen(
          onStart: () => setState(() => _showOnboarding = false),
        );
      }
      return LoginRegisterScreen(
        authService: _services.auth,
        onAuthenticated: _setUser,
      );
    }

    final homeScreen = HomeScreen(
        user: user,
        stats: _stats,
        smartLearnService: _services.smartLearn,
        onStartSmartLearn: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => SmartLearnScreen(
                service: _services.smartLearn,
                onProfileChanged: _setUser,
              ),
            ),
          );
        },
        onStartQuiz: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => QuizModeSelectionScreen(
              lessonService: _services.lessons,
              wordService: _services.words,
              quizService: _services.quiz,
              battleService: _services.battle,
              currentUser: _user!,
              onProfileChanged: _setUser,
            ),
          ),
        ),
        onStartDueReviews: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => MultipleChoiceQuizScreen.dueReviews(
              mode: 'multiple_choice',
              reviewLimit: 20,
              quizService: _services.quiz,
              onProfileChanged: _setUser,
            ),
          ),
        ),
        onStartMistakes: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => MultipleChoiceQuizScreen.mistakes(
              mode: 'multiple_choice',
              quizService: _services.quiz,
              onProfileChanged: _setUser,
            ),
          ),
        ),
        onOpenBadges: () {},
        onOpenStarred: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => StarredWordsScreen(service: _services.words),
          ),
        ),
        onOpenBattle: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => BattleLobbyScreen(
              lessonService: _services.lessons,
              battleService: _services.battle,
            ),
          ),
        ),
        onOpenLeaderboard: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => LeaderboardScreen(
              service: _services.leaderboard,
              messageService: _services.messages,
              battleService: _services.battle,
              lessonService: _services.lessons,
              presenceService: _services.presence,
              websocketService: _services.websocket,
              currentUser: user,
            ),
          ),
        ),
        onOpenLessons: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => LessonListScreen(
              lessonService: _services.lessons,
              wordService: _services.words,
              aiService: _services.ai,
              websocketService: _services.websocket,
              currentUser: user,
            ),
          ),
        ),
        onOpenProfile: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ProfileScreen(
              user: user,
              stats: _stats,
              authService: _services.auth,
              notificationService: _services.notifications,
              offlineCacheService: _services.offlineCache,
              themeMode: widget.themeMode,
              locale: widget.locale,
              onThemeModeChanged: widget.onThemeModeChanged,
              onLocaleChanged: widget.onLocaleChanged,
              onProfileChanged: _setUser,
              onLogout: _logout,
            ),
          ),
        ),
        onOpenMessages: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => MessagesScreen(
              active: true,
              currentUser: user,
              service: _services.messages,
              battleService: _services.battle,
              lessonService: _services.lessons,
              presenceService: _services.presence,
              websocketService: _services.websocket,
              onUnreadChanged: _setMessageUnreadCount,
            ),
          ),
        ),
      );

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          homeScreen,
          if (_offlineMode)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 8,
              left: 18,
              right: 18,
              child: _OfflinePill(
                onRetry: () {
                  setState(() => _booting = true);
                  _loadProfile();
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _OfflinePill extends StatelessWidget {
  const _OfflinePill({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: .72),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          children: [
            const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                context.l10n.t('offline.banner'),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
            TextButton(
              onPressed: onRetry,
              child: Text(context.l10n.t('common.retry')),
            ),
          ],
        ),
      ),
    );
  }
}
