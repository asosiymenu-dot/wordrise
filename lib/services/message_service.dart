import 'dart:typed_data';

import '../models/api_models.dart';
import 'api_service.dart';

class MessageThreadPage {
  const MessageThreadPage({
    required this.messages,
    required this.hasMore,
    this.syncToken,
  });

  final List<MessageModel> messages;
  final bool hasMore;
  final String? syncToken;
}

class MessageService {
  MessageService(this._api);

  final ApiService _api;

  Future<List<ConversationModel>> conversations() async {
    final data = await _api.get('/messages/conversations.php');
    return _parseModelList(data['conversations'], (json) {
      final conversation = ConversationModel.fromJson(json);
      return conversation.user.id > 0 ? conversation : null;
    });
  }

  Future<List<PublicUserModel>> searchUsers(String query) async {
    final data = await _api.get(
      '/users/search.php',
      query: {'q': query, 'limit': '20'},
    );
    return _parseModelList(data['users'], (json) {
      final user = PublicUserModel.fromJson(json);
      return user.id > 0 ? user : null;
    });
  }

  Future<List<MessageModel>> thread(
    int userId, {
    int afterId = 0,
    int beforeId = 0,
    int limit = 100,
    String? updatedSince,
  }) async {
    final page = await threadPage(
      userId,
      afterId: afterId,
      beforeId: beforeId,
      limit: limit,
      updatedSince: updatedSince,
    );
    return page.messages;
  }

  Future<MessageThreadPage> threadPage(
    int userId, {
    int afterId = 0,
    int beforeId = 0,
    int limit = 50,
    String? updatedSince,
  }) async {
    final data = await _api.get(
      '/messages/thread.php',
      query: {
        'user_id': userId.toString(),
        'limit': limit.clamp(1, 200).toString(),
        if (afterId > 0) 'after_id': afterId.toString(),
        if (beforeId > 0) 'before_id': beforeId.toString(),
        if (updatedSince != null && updatedSince.isNotEmpty)
          'updated_since': updatedSince,
      },
    );
    return MessageThreadPage(
      messages: _parseModelList(data['messages'], (json) {
        final message = MessageModel.fromJson(json);
        return message.id > 0 && message.senderId > 0 && message.receiverId > 0
            ? message
            : null;
      }),
      hasMore: data['has_more'] == true || data['has_more']?.toString() == '1',
      syncToken: data['sync_token']?.toString(),
    );
  }

  Future<MessageModel> send({
    required int receiverId,
    required String body,
    String? clientMessageId,
    int? replyToMessageId,
  }) async {
    final data = await _api.post('/messages/send.php', {
      'receiver_id': receiverId,
      'body': body,
      if (clientMessageId != null && clientMessageId.isNotEmpty)
        'client_message_id': clientMessageId,
      if (replyToMessageId != null && replyToMessageId > 0)
        'reply_to_message_id': replyToMessageId,
    });
    return _requiredMessage(data);
  }

  Future<MessageModel> sendImage({
    required int receiverId,
    required Uint8List bytes,
    required String filename,
    required String mimeType,
    required String clientMessageId,
    String body = '',
    int? replyToMessageId,
    void Function(double progress)? onProgress,
  }) async {
    final data = await _api.uploadMultipartBytes(
      '/messages/send_image.php',
      fields: {
        'receiver_id': receiverId.toString(),
        'client_message_id': clientMessageId,
        if (body.isNotEmpty) 'body': body,
        if (replyToMessageId != null && replyToMessageId > 0)
          'reply_to_message_id': replyToMessageId.toString(),
      },
      fileField: 'image',
      bytes: bytes,
      filename: filename,
      contentType: mimeType,
      onProgress: onProgress,
    );
    return _requiredMessage(data);
  }

  Future<MessageModel> update({
    required int messageId,
    required String body,
  }) async {
    final data = await _api.put('/messages/update.php', {
      'message_id': messageId,
      'body': body,
    });
    return _requiredMessage(data);
  }

  Future<MessageModel?> deleteMessage({
    required int messageId,
    required String mode,
  }) async {
    final data = await _api.delete(
      '/messages/delete.php',
      body: {'message_id': messageId, 'mode': mode},
    );
    final json = _asJsonMap(data['message']);
    return json == null ? null : MessageModel.fromJson(json);
  }

  Future<void> markDelivered({
    required int userId,
    required int upToMessageId,
  }) async {
    await _api.post('/messages/delivered.php', {
      'user_id': userId,
      'up_to_message_id': upToMessageId,
    });
  }

  Future<void> markRead({
    required int userId,
    required int upToMessageId,
  }) async {
    await _api.post('/messages/read.php', {
      'user_id': userId,
      'up_to_message_id': upToMessageId,
    });
  }

  Future<int> broadcast(String body) async {
    final data = await _api.post('/messages/broadcast.php', {'body': body});
    final value = data['sent_count'];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  MessageModel _requiredMessage(Map<String, dynamic> data) {
    final json = _asJsonMap(data['message']);
    if (json == null) {
      throw const ApiException(
        'Serverdan xabar maʼlumoti notoʻgʻri keldi.',
        type: ApiExceptionType.badResponse,
      );
    }
    final message = MessageModel.fromJson(json);
    if (message.id <= 0) {
      throw const ApiException(
        'Serverdan xabar maʼlumoti notoʻgʻri keldi.',
        type: ApiExceptionType.badResponse,
      );
    }
    return message;
  }
}

List<T> _parseModelList<T>(
  Object? value,
  T? Function(Map<String, dynamic> json) parse,
) {
  if (value is! List) return <T>[];
  final result = <T>[];
  for (final item in value) {
    final json = _asJsonMap(item);
    if (json == null) continue;
    try {
      final model = parse(json);
      if (model != null) result.add(model);
    } on Object {
      // A malformed legacy row must not block the rest of the inbox.
    }
  }
  return result;
}

Map<String, dynamic>? _asJsonMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return null;
}

List<MessageModel> mergeMessageLists(
  Iterable<MessageModel> current,
  Iterable<MessageModel> incoming,
) {
  final byId = <int, MessageModel>{
    for (final message in current) message.id: message,
  };
  for (final message in incoming) {
    final clientId = message.clientMessageId;
    if (clientId != null && clientId.isNotEmpty) {
      byId.removeWhere(
        (_, candidate) =>
            candidate.id < 0 && candidate.clientMessageId == clientId,
      );
    }
    byId[message.id] = message;
  }
  final merged = byId.values.toList()
    ..sort((left, right) {
      final leftDate = left.localCreatedAt;
      final rightDate = right.localCreatedAt;
      if (leftDate != null && rightDate != null) {
        final byDate = leftDate.compareTo(rightDate);
        if (byDate != 0) return byDate;
      }
      if (left.id < 0 && right.id >= 0) return 1;
      if (right.id < 0 && left.id >= 0) return -1;
      return left.id.compareTo(right.id);
    });
  return merged;
}

bool messageListsEquivalent(List<MessageModel> left, List<MessageModel> right) {
  if (identical(left, right)) return true;
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index].syncSignature != right[index].syncSignature) return false;
  }
  return true;
}
