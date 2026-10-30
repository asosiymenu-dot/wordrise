import 'json_helpers.dart';

class AppNotificationModel {
  const AppNotificationModel({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.data,
    required this.createdAt,
    this.readAt,
  });

  factory AppNotificationModel.fromJson(Map<String, dynamic> json) {
    return AppNotificationModel(
      id: asInt(json['id']),
      type: json['type']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      data: Map<String, dynamic>.from(json['data'] as Map? ?? {}),
      readAt: asNullableString(json['read_at']),
      createdAt: json['created_at']?.toString() ?? '',
    );
  }

  final int id;
  final String type;
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final String? readAt;
  final String createdAt;
}

class NotificationBatchModel {
  const NotificationBatchModel({
    required this.notifications,
    required this.unreadCount,
    required this.maxId,
  });

  factory NotificationBatchModel.fromJson(Map<String, dynamic> json) {
    return NotificationBatchModel(
      notifications: (json['notifications'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(AppNotificationModel.fromJson)
          .toList(),
      unreadCount: asInt(json['unread_count']),
      maxId: asInt(json['max_id']),
    );
  }

  final List<AppNotificationModel> notifications;
  final int unreadCount;
  final int maxId;
}

class LearningPreferencesModel {
  const LearningPreferencesModel({
    required this.reminderEnabled,
    required this.reminderHour,
    required this.reminderMinute,
    required this.streakRiskEnabled,
    required this.streakRiskHour,
    required this.streakRiskMinute,
    required this.timezone,
  });

  factory LearningPreferencesModel.fromJson(Map<String, dynamic> json) {
    return LearningPreferencesModel(
      reminderEnabled: asBool(json['reminder_enabled']),
      reminderHour: asInt(json['reminder_hour']),
      reminderMinute: asInt(json['reminder_minute']),
      streakRiskEnabled: asBool(json['streak_risk_enabled']),
      streakRiskHour: asInt(json['streak_risk_hour']),
      streakRiskMinute: asInt(json['streak_risk_minute']),
      timezone: json['timezone']?.toString() ?? 'Asia/Tashkent',
    );
  }

  final bool reminderEnabled;
  final int reminderHour;
  final int reminderMinute;
  final bool streakRiskEnabled;
  final int streakRiskHour;
  final int streakRiskMinute;
  final String timezone;

  Map<String, dynamic> toJson() {
    return {
      'reminder_enabled': reminderEnabled,
      'reminder_hour': reminderHour,
      'reminder_minute': reminderMinute,
      'streak_risk_enabled': streakRiskEnabled,
      'streak_risk_hour': streakRiskHour,
      'streak_risk_minute': streakRiskMinute,
      'timezone': timezone,
    };
  }
}
