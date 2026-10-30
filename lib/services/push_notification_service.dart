import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'app_notification_service.dart';
import 'notification_service.dart';

class WordRiseFirebaseOptions {
  static const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const appId = String.fromEnvironment('FIREBASE_APP_ID');
  static const messagingSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
  );
  static const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const storageBucket = String.fromEnvironment(
    'FIREBASE_STORAGE_BUCKET',
  );
  static const authDomain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN');
  static const measurementId = String.fromEnvironment(
    'FIREBASE_MEASUREMENT_ID',
  );
  static const webVapidKey = String.fromEnvironment(
    'FIREBASE_WEB_VAPID_KEY',
  );

  static bool get configured =>
      apiKey.isNotEmpty &&
      appId.isNotEmpty &&
      messagingSenderId.isNotEmpty &&
      projectId.isNotEmpty;

  static FirebaseOptions get current => FirebaseOptions(
    apiKey: apiKey,
    appId: appId,
    messagingSenderId: messagingSenderId,
    projectId: projectId,
    storageBucket: storageBucket.isEmpty ? null : storageBucket,
    authDomain: authDomain.isEmpty ? null : authDomain,
    measurementId: measurementId.isEmpty ? null : measurementId,
  );
}

@pragma('vm:entry-point')
Future<void> wordRiseFirebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  if (!WordRiseFirebaseOptions.configured) return;
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(options: WordRiseFirebaseOptions.current);
  }
}

class PushNotificationService {
  PushNotificationService._();

  static final instance = PushNotificationService._();

  AppNotificationService? _backend;
  String _locale = 'uz';
  String? _token;
  bool _bootstrapped = false;
  bool _listenersReady = false;
  ValueChanged<Map<String, dynamic>>? _onOpened;

  bool get available => _bootstrapped;

  Future<void> bootstrap() async {
    if (_bootstrapped || !WordRiseFirebaseOptions.configured) return;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: WordRiseFirebaseOptions.current);
      }
      if (!kIsWeb) {
        FirebaseMessaging.onBackgroundMessage(
          wordRiseFirebaseMessagingBackgroundHandler,
        );
      }
      _bootstrapped = true;
    } on Object {
      _bootstrapped = false;
    }
  }

  Future<void> activate({
    required AppNotificationService backend,
    required String locale,
    required ValueChanged<Map<String, dynamic>> onOpened,
  }) async {
    _backend = backend;
    _locale = locale;
    _onOpened = onOpened;
    await bootstrap();
    if (!_bootstrapped) return;
    try {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
            alert: false,
            badge: true,
            sound: false,
          );
      if (kIsWeb && WordRiseFirebaseOptions.webVapidKey.isEmpty) return;
      _token = await FirebaseMessaging.instance.getToken(
        vapidKey: kIsWeb ? WordRiseFirebaseOptions.webVapidKey : null,
      );
      if (_token != null) await _register(_token!);
      _attachListeners();
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) _emitOpened(initial);
    } on Object {
      // Push is additive; a device-specific setup error must not block the app.
    }
  }

  Future<void> updateLocale(String locale) async {
    _locale = locale;
    final token = _token;
    if (token != null) await _register(token);
  }

  Future<void> deactivate() async {
    final token = _token;
    final backend = _backend;
    if (token != null && backend != null) {
      try {
        await backend.unregisterDevice(token);
      } on Object {
        // The server expires stale tokens after an FCM rejection as well.
      }
    }
    _backend = null;
    _onOpened = null;
    _token = null;
  }

  void _attachListeners() {
    if (_listenersReady) return;
    _listenersReady = true;
    FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      _token = token;
      unawaited(_register(token));
    });
    FirebaseMessaging.onMessage.listen((message) {
      unawaited(_showForeground(message));
    });
    FirebaseMessaging.onMessageOpenedApp.listen(_emitOpened);
  }

  Future<void> _register(String token) async {
    final backend = _backend;
    if (backend == null) return;
    try {
      await backend.registerDevice(
        token: token,
        platform: _platform,
        locale: _locale,
      );
    } on Object {
      // It will be retried on the next token refresh or authenticated startup.
    }
  }

  Future<void> _showForeground(RemoteMessage message) async {
    final title = message.notification?.title ?? message.data['title'] ?? '';
    final body = message.notification?.body ?? message.data['body'] ?? '';
    if (title.toString().trim().isEmpty && body.toString().trim().isEmpty) {
      return;
    }
    final rawId = message.data['notification_id']?.toString();
    final id = int.tryParse(rawId ?? '') ?? message.messageId.hashCode.abs();
    await NotificationService.instance.showRemote(
      notificationId: id,
      title: title.toString(),
      body: body.toString(),
      type: message.data['type']?.toString() ?? 'activity',
    );
  }

  void _emitOpened(RemoteMessage message) {
    _onOpened?.call(Map<String, dynamic>.from(message.data));
  }

  String get _platform {
    if (kIsWeb) return 'web';
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      _ => 'unknown',
    };
  }
}
