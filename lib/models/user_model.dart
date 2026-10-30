import 'json_helpers.dart';

class UserModel {
  const UserModel({
    required this.id,
    required this.name,
    required this.username,
    required this.email,
    required this.role,
    required this.englishLevel,
    required this.xp,
    required this.level,
    required this.streak,
    this.streakFreezes = 0,
    this.lastStreakFreezeAt,
    this.avatar,
    this.lastActiveDate,
    this.totalLearned = 0,
    this.progressPercent = 0.0,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: asInt(json['id']),
      name: json['name']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      englishLevel: json['english_level']?.toString() ?? 'A1',
      role: json['role']?.toString() ?? 'student',
      xp: asInt(json['xp']),
      level: asInt(json['level']),
      streak: asInt(json['streak']),
      streakFreezes: asInt(json['streak_freezes']),
      lastStreakFreezeAt: asNullableString(json['last_streak_freeze_at']),
      avatar: asNullableString(json['avatar']),
      lastActiveDate: json['last_active_date']?.toString(),
      totalLearned: asInt(json['total_learned']),
      progressPercent: asDouble(json['progress_percent'], 0),
    );
  }

  final int id;
  final String name;
  final String username;
  final String email;
  final String role;
  final String englishLevel;
  final int xp;
  final int level;
  final int streak;
  final int streakFreezes;
  final String? lastStreakFreezeAt;
  final String? avatar;
  final String? lastActiveDate;
  final int totalLearned;
  final double progressPercent;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'username': username,
      'email': email,
      'english_level': englishLevel,
      'role': role,
      'xp': xp,
      'level': level,
      'streak': streak,
      'streak_freezes': streakFreezes,
      'last_streak_freeze_at': lastStreakFreezeAt,
      'avatar': avatar,
      'last_active_date': lastActiveDate,
      'total_learned': totalLearned,
      'progress_percent': progressPercent,
    };
  }
}

/// Helpers that belong with the user domain.

int levelFromXp(int xp) {
  if (xp < 100) return 1;
  if (xp < 300) return 2;
  if (xp < 700) return 3;
  if (xp < 1200) return 4;
  if (xp < 2000) return 5;
  return 6 + ((xp - 2000) ~/ 1000);
}

String levelTitle(int level) {
  if (level <= 1) return 'Beginner';
  if (level == 2) return 'Learner';
  if (level == 3) return 'Smart Student';
  if (level == 4) return 'Word Master';
  if (level == 5) return 'English Fighter';
  if (level >= 10) return 'Legend';
  return 'Rising Star';
}

double levelProgress(int xp) {
  const ranges = [(0, 100), (100, 300), (300, 700), (700, 1200), (1200, 2000)];
  for (final range in ranges) {
    if (xp >= range.$1 && xp < range.$2) {
      return (xp - range.$1) / (range.$2 - range.$1);
    }
  }
  return ((xp - 2000) % 1000) / 1000;
}

String initials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return 'WR';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
}
