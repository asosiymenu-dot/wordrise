import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/api_models.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _timezoneInitialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    await _plugin.initialize(settings: settings);
    _initialized = true;
    if (!kIsWeb) await requestPermissions();
  }

  Future<void> requestPermissions() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    await _plugin
        .resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    await _plugin
        .resolvePlatformSpecificImplementation<
          WebFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }

  Future<void> showMessage({
    required int messageId,
    required String senderName,
    required String body,
  }) async {
    await initialize();
    final notificationId = messageId.remainder(2147483647);

    const androidDetails = AndroidNotificationDetails(
      'wordrise_messages',
      'WordRise xabarlari',
      channelDescription: 'Yangi chat xabarlari uchun bildirishnomalar',
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.message,
    );
    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _plugin.show(
      id: notificationId,
      title: senderName,
      body: body,
      notificationDetails: const NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
        macOS: darwinDetails,
      ),
      payload: 'message:$messageId',
    );
  }

  Future<void> showEvent({
    required int notificationId,
    required String title,
    required String body,
    required String type,
  }) async {
    await initialize();
    final id = (1000000000 + notificationId).remainder(2147483647);
    const androidDetails = AndroidNotificationDetails(
      'wordrise_activity',
      'WordRise faoliyati',
      channelDescription: 'Battle takliflari va natijalari',
      importance: Importance.high,
      priority: Priority.high,
    );
    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
        macOS: darwinDetails,
      ),
      payload: '$type:$notificationId',
    );
  }

  Future<void> scheduleLearningReminders({
    required LearningPreferencesModel preferences,
    required String dailyTitle,
    required String dailyBody,
    required String riskTitle,
    required String riskBody,
  }) async {
    await initialize();
    if (kIsWeb) {
      // Web reminders are delivered by Firebase/backend push. Browsers cannot
      // reliably run a local scheduled task after the tab has been closed.
      await requestPermissions();
      return;
    }
    await _initializeTimezone(preferences.timezone);
    await _plugin.cancel(id: 2000001);
    await _plugin.cancel(id: 2000002);
    if (preferences.reminderEnabled) {
      await _scheduleDaily(
        id: 2000001,
        hour: preferences.reminderHour,
        minute: preferences.reminderMinute,
        title: dailyTitle,
        body: dailyBody,
        payload: 'daily_reminder',
      );
    }
    if (preferences.streakRiskEnabled) {
      await _scheduleDaily(
        id: 2000002,
        hour: preferences.streakRiskHour,
        minute: preferences.streakRiskMinute,
        title: riskTitle,
        body: riskBody,
        payload: 'streak_risk',
      );
    }
  }

  Future<void> showRemote({
    required int notificationId,
    required String title,
    required String body,
    required String type,
  }) {
    return showEvent(
      notificationId: notificationId,
      title: title,
      body: body,
      type: type,
    );
  }

  Future<void> _initializeTimezone(String fallback) async {
    if (_timezoneInitialized) return;
    tz.initializeTimeZones();
    var identifier = fallback;
    try {
      identifier = (await FlutterTimezone.getLocalTimezone()).identifier;
    } on Object {
      // The server-side timezone remains a safe fallback.
    }
    try {
      tz.setLocalLocation(tz.getLocation(identifier));
    } on Object {
      tz.setLocalLocation(tz.getLocation('UTC'));
    }
    _timezoneInitialized = true;
  }

  Future<void> _scheduleDaily({
    required int id,
    required int hour,
    required int minute,
    required String title,
    required String body,
    required String payload,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    const android = AndroidNotificationDetails(
      'wordrise_reminders',
      'WordRise reminders',
      channelDescription: 'Daily learning and streak reminders',
      importance: Importance.high,
      priority: Priority.high,
    );
    const darwin = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduled,
      notificationDetails: const NotificationDetails(
        android: android,
        iOS: darwin,
        macOS: darwin,
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: payload,
    );
  }
}
