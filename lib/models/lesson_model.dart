import 'json_helpers.dart';

class LessonModel {
  const LessonModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.category,
    required this.wordCount,
    required this.createdAt,
    this.ownerName = '',
    this.shareCode,
    this.isPublic = false,
    this.importCount = 0,
  });

  factory LessonModel.fromJson(Map<String, dynamic> json) {
    return LessonModel(
      id: asInt(json['id']),
      userId: asInt(json['user_id']),
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      category: json['category']?.toString() ?? 'General',
      wordCount: asInt(json['word_count']),
      createdAt: json['created_at']?.toString() ?? '',
      ownerName: json['owner_name']?.toString() ?? '',
      shareCode: asNullableString(json['share_code']),
      isPublic: asBool(json['is_public']),
      importCount: asInt(json['import_count']),
    );
  }

  final int id;
  final int userId;
  final String title;
  final String description;
  final String category;
  final int wordCount;
  final String createdAt;
  final String ownerName;
  final String? shareCode;
  final bool isPublic;
  final int importCount;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'description': description,
      'category': category,
      'word_count': wordCount,
      'created_at': createdAt,
      'owner_name': ownerName,
      'share_code': shareCode,
      'is_public': isPublic,
      'import_count': importCount,
    };
  }
}
