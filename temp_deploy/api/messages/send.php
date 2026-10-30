<?php

require_once __DIR__ . '/../../helpers/response.php';
require_once __DIR__ . '/../../helpers/message_rate_limit.php';
require_once __DIR__ . '/../../middleware/auth_middleware.php';
require_once __DIR__ . '/../../models/Message.php';
require_once __DIR__ . '/../../models/User.php';

require_method('POST');

try {
    $user = auth_user();
    enforce_message_rate_limit((int)$user['id'], 'message_send', 25, 60);
    $data = request_json();
    $receiverId = (int)($data['receiver_id'] ?? 0);
    $receiverUsername = trim((string)($data['receiver_username'] ?? ''));
    $clientMessageId = trim((string)($data['client_message_id'] ?? ''));
    $replyToMessageId = max(0, (int)($data['reply_to_message_id'] ?? 0));
    $body = required_string($data, 'body', 1000);

    if ($receiverId <= 0 && $receiverUsername !== '') {
        $receiver = User::findByUsername($receiverUsername);
        if (!$receiver) {
            error_response('User not found.', 404);
        }
        $receiverId = (int)$receiver['id'];
    }

    if ($receiverId <= 0) {
        error_response('receiver_id is required.', 422);
    }

    $message = Message::send(
        (int)$user['id'],
        $receiverId,
        $body,
        $clientMessageId === '' ? null : $clientMessageId,
        $replyToMessageId > 0 ? $replyToMessageId : null
    );
    success_response(['message' => Message::publicData($message, (int)$user['id'])], 'Message sent.', 201);
} catch (OverflowException $error) {
    error_response($error->getMessage(), 429);
} catch (Throwable $error) {
    $status = $error instanceof DomainException
        ? 403
        : (($error instanceof LogicException || $error instanceof InvalidArgumentException) ? 422 : 500);
    error_response($error->getMessage(), $status);
}
