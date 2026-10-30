import 'package:flutter/material.dart';

enum UserRole {
  student,
  teacher,
  admin;

  String get label {
    return switch (this) {
      UserRole.student => 'Student',
      UserRole.teacher => 'Teacher',
      UserRole.admin => 'Admin',
    };
  }
}

enum QuizMode {
  flashcard,
  multipleChoice,
  reverse,
  typing,
  trueFalse,
  match,
  speed;

  String get label {
    return switch (this) {
      QuizMode.flashcard => 'Flashcard',
      QuizMode.multipleChoice => 'Viktorina',
      QuizMode.reverse => 'Reverse Quiz',
      QuizMode.typing => 'Typing Test',
      QuizMode.trueFalse => 'True / False',
      QuizMode.match => 'Match Words',
      QuizMode.speed => 'Speed Quiz',
    };
  }

  String get shortLabel {
    return switch (this) {
      QuizMode.multipleChoice => 'Quiz',
      QuizMode.trueFalse => 'T/F',
      QuizMode.speed => 'Speed',
      _ => label,
    };
  }

  int get baseXp {
    return switch (this) {
      QuizMode.flashcard => 5,
      QuizMode.multipleChoice => 10,
      QuizMode.reverse => 10,
      QuizMode.typing => 15,
      QuizMode.trueFalse => 8,
      QuizMode.match => 8,
      QuizMode.speed => 20,
    };
  }

  IconData get icon {
    return switch (this) {
      QuizMode.flashcard => Icons.style_rounded,
      QuizMode.multipleChoice => Icons.checklist_rounded,
      QuizMode.reverse => Icons.swap_horiz_rounded,
      QuizMode.typing => Icons.keyboard_alt_rounded,
      QuizMode.trueFalse => Icons.rule_rounded,
      QuizMode.match => Icons.hub_rounded,
      QuizMode.speed => Icons.bolt_rounded,
    };
  }
}

class AppUser {
  const AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    required this.totalXp,
    required this.todayXp,
    required this.weeklyXp,
    required this.correctAnswers,
    required this.wrongAnswers,
    required this.currentStreak,
    required this.longestStreak,
    required this.lastStudyDate,
    required this.unlockedBadgeIds,
  });

  final String uid;
  final String name;
  final String email;
  final UserRole role;
  final int totalXp;
  final int todayXp;
  final int weeklyXp;
  final int correctAnswers;
  final int wrongAnswers;
  final int currentStreak;
  final int longestStreak;
  final DateTime? lastStudyDate;
  final Set<String> unlockedBadgeIds;

  int get level => levelFromXp(totalXp);

  AppUser copyWith({
    String? name,
    String? email,
    UserRole? role,
    int? totalXp,
    int? todayXp,
    int? weeklyXp,
    int? correctAnswers,
    int? wrongAnswers,
    int? currentStreak,
    int? longestStreak,
    DateTime? lastStudyDate,
    Set<String>? unlockedBadgeIds,
  }) {
    return AppUser(
      uid: uid,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      totalXp: totalXp ?? this.totalXp,
      todayXp: todayXp ?? this.todayXp,
      weeklyXp: weeklyXp ?? this.weeklyXp,
      correctAnswers: correctAnswers ?? this.correctAnswers,
      wrongAnswers: wrongAnswers ?? this.wrongAnswers,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      lastStudyDate: lastStudyDate ?? this.lastStudyDate,
      unlockedBadgeIds: unlockedBadgeIds ?? this.unlockedBadgeIds,
    );
  }
}

class Lesson {
  Lesson({
    required this.id,
    required this.title,
    required this.topic,
    required this.description,
    required this.ownerId,
    required this.className,
    required this.accent,
    required List<VocabWord> words,
  }) : words = List<VocabWord>.of(words);

  final String id;
  final String title;
  final String topic;
  final String description;
  final String ownerId;
  final String className;
  final Color accent;
  final List<VocabWord> words;
}

class VocabWord {
  const VocabWord({
    required this.id,
    required this.lessonId,
    required this.word,
    required this.translation,
    required this.example,
    required this.pronunciation,
  });

  final String id;
  final String lessonId;
  final String word;
  final String translation;
  final String example;
  final String pronunciation;
}

class QuizQuestion {
  const QuizQuestion({
    required this.word,
    required this.prompt,
    required this.correctAnswer,
    required this.displayAnswer,
    required this.options,
    required this.eyebrow,
    required this.helper,
  });

  final VocabWord word;
  final String prompt;
  final String correctAnswer;
  final String displayAnswer;
  final List<String> options;
  final String eyebrow;
  final String helper;
}

class QuizResult {
  const QuizResult({
    required this.mode,
    required this.lessonTitle,
    required this.totalQuestions,
    required this.correctCount,
    required this.wrongCount,
    required this.earnedXp,
    required this.maxCorrectStreak,
    required this.perfectRound,
    required this.correctWords,
    required this.wrongWords,
  });

  final QuizMode mode;
  final String lessonTitle;
  final int totalQuestions;
  final int correctCount;
  final int wrongCount;
  final int earnedXp;
  final int maxCorrectStreak;
  final bool perfectRound;
  final List<VocabWord> correctWords;
  final List<VocabWord> wrongWords;

  int get accuracy {
    if (totalQuestions == 0) return 0;
    return (correctCount / totalQuestions * 100).round();
  }
}

class MistakeRecord {
  const MistakeRecord({
    required this.word,
    required this.wrongCount,
    required this.correctAfterMistake,
    required this.mastered,
    required this.lastWrongAt,
  });

  final VocabWord word;
  final int wrongCount;
  final int correctAfterMistake;
  final bool mastered;
  final DateTime lastWrongAt;

  MistakeRecord copyWith({
    int? wrongCount,
    int? correctAfterMistake,
    bool? mastered,
    DateTime? lastWrongAt,
  }) {
    return MistakeRecord(
      word: word,
      wrongCount: wrongCount ?? this.wrongCount,
      correctAfterMistake: correctAfterMistake ?? this.correctAfterMistake,
      mastered: mastered ?? this.mastered,
      lastWrongAt: lastWrongAt ?? this.lastWrongAt,
    );
  }
}

class BadgeModel {
  const BadgeModel({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.target,
    required this.xpReward,
  });

  final String id;
  final String title;
  final String description;
  final IconData icon;
  final int target;
  final int xpReward;
}

class LeaderboardEntry {
  const LeaderboardEntry({
    required this.uid,
    required this.name,
    required this.avatarLabel,
    required this.xp,
    required this.todayXp,
    required this.weeklyXp,
    required this.level,
    required this.correctAnswers,
    required this.streak,
    required this.rank,
    required this.color,
  });

  factory LeaderboardEntry.fromUser(AppUser user) {
    return LeaderboardEntry(
      uid: user.uid,
      name: user.name,
      avatarLabel: initials(user.name),
      xp: user.totalXp,
      todayXp: user.todayXp,
      weeklyXp: user.weeklyXp,
      level: user.level,
      correctAnswers: user.correctAnswers,
      streak: user.currentStreak,
      rank: 0,
      color: const Color(0xFF5B6CFF),
    );
  }

  final String uid;
  final String name;
  final String avatarLabel;
  final int xp;
  final int todayXp;
  final int weeklyXp;
  final int level;
  final int correctAnswers;
  final int streak;
  final int rank;
  final Color color;

  LeaderboardEntry copyWith({int? rank}) {
    return LeaderboardEntry(
      uid: uid,
      name: name,
      avatarLabel: avatarLabel,
      xp: xp,
      todayXp: todayXp,
      weeklyXp: weeklyXp,
      level: level,
      correctAnswers: correctAnswers,
      streak: streak,
      rank: rank ?? this.rank,
      color: color,
    );
  }
}

class SessionAward {
  const SessionAward({
    required this.levelUp,
    required this.oldLevel,
    required this.newLevel,
    required this.streakBonus,
    required this.newBadges,
  });

  final bool levelUp;
  final int oldLevel;
  final int newLevel;
  final int streakBonus;
  final List<BadgeModel> newBadges;
}

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
