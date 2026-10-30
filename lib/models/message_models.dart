import 'battle_models.dart';
import 'dart:typed_data';

import 'json_helpers.dart';
import 'leaderboard_models.dart';

enum MessageSendState { sending, sent, delivered, read, failed }

class MessageAttachmentModel {
  const MessageAttachmentModel({
    required this.url,
    required this.thumbnailUrl,
    required this.width,
    required this.height,
    required this.sizeBytes,
    required this.mimeType,
    this.localBytes,
  });

  factory MessageAttachmentModel.fromJson(Map<String, dynamic> json) {
    return MessageAttachmentModel(
      url: json['url']?.toString() ?? '',
      thumbnailUrl:
          json['thumbnail_url']?.toString() ?? json['url']?.toString() ?? '',
      width: asInt(json['width']),
      height: asInt(json['height']),
      sizeBytes: asInt(json['size_bytes']),
      mimeType: json['mime_type']?.toString() ?? 'image/jpeg',
    );
  }

  final String url;
  final String thumbnailUrl;
  final int width;
  final int height;
  final int sizeBytes;
  final String mimeType;
  final Uint8List? localBytes;

  double get aspectRatio => width > 0 && height > 0 ? width / height : 4 / 3;
}

class MessageReplyModel {
  const MessageReplyModel({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.type,
    required this.body,
    required this.deleted,
    this.attachment,
  });

  factory MessageReplyModel.fromJson(Map<String, dynamic> json) {
    final attachment = asStringMap(json['attachment']);
    return MessageReplyModel(
      id: asInt(json['id']),
      senderId: asInt(json['sender_id']),
      senderName: json['sender_name']?.toString() ?? '',
      type: json['type']?.toString() ?? 'text',
      body: json['body']?.toString() ?? '',
      deleted: json['deleted'] == true || json['deleted']?.toString() == '1',
      attachment: attachment.isEmpty
          ? null
          : MessageAttachmentModel.fromJson(attachment),
    );
  }

  final int id;
  final int senderId;
  final String senderName;
  final String type;
  final String body;
  final bool deleted;
  final MessageAttachmentModel? attachment;
}

class MessageModel {
  const MessageModel({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.body,
    required this.createdAt,
    this.clientMessageId,
    this.type = 'text',
    this.metadata = const {},
    this.battleInvite,
    this.deliveredAt,
    this.readAt,
    this.editedAt,
    this.deletedForEveryoneAt,
    this.deletedForEveryoneBy,
    this.replyToMessageId,
    this.replyTo,
    this.attachment,
    this.updatedAt,
    this.localState,
    this.uploadProgress = 0,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    final metadata = asStringMap(json['metadata']);
    final invite = asStringMap(metadata['invite']);
    final reply = asStringMap(json['reply_to']);
    final attachment = asStringMap(json['attachment']);
    return MessageModel(
      id: asInt(json['id']),
      senderId: asInt(json['sender_id']),
      receiverId: asInt(json['receiver_id']),
      clientMessageId: asNullableString(json['client_message_id']),
      body: json['body']?.toString() ?? '',
      type:
          json['type']?.toString() ??
          json['message_type']?.toString() ??
          'text',
      metadata: metadata,
      battleInvite: invite.isEmpty ? null : BattleInviteModel.fromJson(invite),
      deliveredAt: asNullableString(json['delivered_at']),
      readAt: asNullableString(json['read_at']),
      editedAt: asNullableString(json['edited_at']),
      deletedForEveryoneAt: asNullableString(json['deleted_for_everyone_at']),
      deletedForEveryoneBy: json['deleted_for_everyone_by'] == null
          ? null
          : asInt(json['deleted_for_everyone_by']),
      replyToMessageId: json['reply_to_message_id'] == null
          ? null
          : asInt(json['reply_to_message_id']),
      replyTo: reply.isEmpty ? null : MessageReplyModel.fromJson(reply),
      attachment: attachment.isEmpty
          ? null
          : MessageAttachmentModel.fromJson(attachment),
      createdAt: json['created_at']?.toString() ?? '',
      updatedAt: asNullableString(json['updated_at']),
    );
  }

  final int id;
  final int senderId;
  final int receiverId;
  final String? clientMessageId;
  final String body;
  final String type;
  final Map<String, dynamic> metadata;
  final BattleInviteModel? battleInvite;
  final String? deliveredAt;
  final String? readAt;
  final String? editedAt;
  final String? deletedForEveryoneAt;
  final int? deletedForEveryoneBy;
  final int? replyToMessageId;
  final MessageReplyModel? replyTo;
  final MessageAttachmentModel? attachment;
  final String createdAt;
  final String? updatedAt;
  final MessageSendState? localState;
  final double uploadProgress;

  bool get deletedForEveryone => deletedForEveryoneAt != null;
  bool get isSystem => type.startsWith('battle_') || type == 'system';
  bool get canEdit => type == 'text' && !deletedForEveryone && id > 0;
  bool get canDeleteForEveryone =>
      (type == 'text' || type == 'image') && !deletedForEveryone && id > 0;

  MessageSendState get sendState {
    if (localState != null) return localState!;
    if (readAt != null) return MessageSendState.read;
    if (deliveredAt != null) return MessageSendState.delivered;
    return MessageSendState.sent;
  }

  DateTime? get localCreatedAt => _parseApiDate(createdAt);

  MessageModel copyWith({
    String? body,
    MessageSendState? localState,
    double? uploadProgress,
    String? editedAt,
  }) {
    return MessageModel(
      id: id,
      senderId: senderId,
      receiverId: receiverId,
      clientMessageId: clientMessageId,
      body: body ?? this.body,
      createdAt: createdAt,
      type: type,
      metadata: metadata,
      battleInvite: battleInvite,
      deliveredAt: deliveredAt,
      readAt: readAt,
      editedAt: editedAt ?? this.editedAt,
      deletedForEveryoneAt: deletedForEveryoneAt,
      deletedForEveryoneBy: deletedForEveryoneBy,
      replyToMessageId: replyToMessageId,
      replyTo: replyTo,
      attachment: attachment,
      updatedAt: updatedAt,
      localState: localState ?? this.localState,
      uploadProgress: uploadProgress ?? this.uploadProgress,
    );
  }

  String get syncSignature => <Object?>[
    id,
    clientMessageId,
    body,
    type,
    deliveredAt,
    readAt,
    editedAt,
    deletedForEveryoneAt,
    updatedAt,
    replyToMessageId,
    attachment?.url,
    battleInvite?.status,
    localState,
    uploadProgress.toStringAsFixed(3),
  ].join('|');
}

class ConversationModel {
  const ConversationModel({
    required this.user,
    required this.unreadCount,
    this.lastMessage,
  });

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    final user = asStringMap(json['user']);
    final lastMessage = asStringMap(json['last_message']);
    return ConversationModel(
      user: PublicUserModel.fromJson(user),
      lastMessage: lastMessage.isEmpty
          ? null
          : MessageModel.fromJson(lastMessage),
      unreadCount: asInt(json['unread_count']),
    );
  }

  final PublicUserModel user;
  final MessageModel? lastMessage;
  final int unreadCount;
}

DateTime? _parseApiDate(String? value) {
  final normalized = value?.trim() ?? '';
  if (normalized.isEmpty) return null;
  final parsed = DateTime.tryParse(normalized);
  return parsed?.toLocal();
}
