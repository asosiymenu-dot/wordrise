import 'json_helpers.dart';

class LeaderboardUserModel {
  const LeaderboardUserModel({
    required this.rank,
    required this.id,
    required this.name,
    required this.username,
    required this.xp,
    required this.level,
    required this.streak,
    this.avatar,
    this.topBadge,
    this.lastSeenAt,
    this.isOnline = false,
  });

  factory LeaderboardUserModel.fromJson(Map<String, dynamic> json) {
    return LeaderboardUserModel(
      rank: asInt(json['rank']),
      id: asInt(json['id']),
      name: json['name']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      avatar: asNullableString(json['avatar']),
      xp: asInt(json['xp']),
      level: asInt(json['level']),
      streak: asInt(json['streak']),
      lastSeenAt: asNullableString(json['last_seen_at']),
      isOnline:
          json['is_online'] == true || json['is_online']?.toString() == '1',
      topBadge: json['top_badge'] is Map<String, dynamic>
          ? LeaderboardBadgeModel.fromJson(
              json['top_badge'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  final int rank;
  final int id;
  final String name;
  final String username;
  final String? avatar;
  final int xp;
  final int level;
  final int streak;
  final LeaderboardBadgeModel? topBadge;
  final String? lastSeenAt;
  final bool isOnline;

  PublicUserModel toPublicUser() {
    return PublicUserModel(
      id: id,
      name: name,
      username: username,
      level: level,
      streak: streak,
      avatar: avatar,
      lastSeenAt: lastSeenAt,
      isOnline: isOnline,
    );
  }
}

class LeaderboardBadgeModel {
  const LeaderboardBadgeModel({required this.title, required this.icon});

  factory LeaderboardBadgeModel.fromJson(Map<String, dynamic> json) {
    return LeaderboardBadgeModel(
      title: json['title']?.toString() ?? '',
      icon: json['icon']?.toString() ?? '',
    );
  }

  final String title;
  final String icon;
}

class PublicUserModel {
  const PublicUserModel({
    required this.id,
    required this.name,
    required this.username,
    required this.level,
    required this.streak,
    this.avatar,
    this.lastSeenAt,
    this.isOnline = false,
  });

  factory PublicUserModel.fromJson(Map<String, dynamic> json) {
    return PublicUserModel(
      id: asInt(json['id']),
      name: json['name']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      avatar: asNullableString(json['avatar']),
      level: asInt(json['level']),
      streak: asInt(json['streak']),
      lastSeenAt: asNullableString(json['last_seen_at']),
      isOnline:
          json['is_online'] == true || json['is_online']?.toString() == '1',
    );
  }

  final int id;
  final String name;
  final String username;
  final int level;
  final int streak;
  final String? avatar;
  final String? lastSeenAt;
  final bool isOnline;

  DateTime? get localLastSeenAt {
    final value = lastSeenAt?.trim() ?? '';
    return value.isEmpty ? null : DateTime.tryParse(value)?.toLocal();
  }
}

class ProfileStatsModel {
  const ProfileStatsModel({
    required this.englishLevel,
    required this.totalWords,
    required this.masteredWords,
    required this.grammarCompleted,
    required this.grammarTotal,
    required this.weeklyXp,
    required this.progressPercentage,
  });

  factory ProfileStatsModel.fromJson(Map<String, dynamic> json) {
    return ProfileStatsModel(
      englishLevel: json['english_level']?.toString() ?? 'A1',
      totalWords: asInt(json['total_words']),
      masteredWords: asInt(json['mastered_words']),
      grammarCompleted: asInt(json['grammar_completed']),
      grammarTotal: asInt(json['grammar_total']),
      weeklyXp: (json['weekly_xp'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(WeeklyXpModel.fromJson)
          .toList(),
      progressPercentage: asInt(json['progress_percentage']),
    );
  }

  final String englishLevel;
  final int totalWords;
  final int masteredWords;
  final int grammarCompleted;
  final int grammarTotal;
  final List<WeeklyXpModel> weeklyXp;
  final int progressPercentage;
}

class WeeklyXpModel {
  const WeeklyXpModel({required this.day, required this.xp});

  factory WeeklyXpModel.fromJson(Map<String, dynamic> json) {
    return WeeklyXpModel(
      day: json['day']?.toString() ?? '',
      xp: asInt(json['xp']),
    );
  }

  final String day;
  final int xp;
}
