<?php

require_once __DIR__ . '/../../helpers/response.php';
require_once __DIR__ . '/../../helpers/message_rate_limit.php';
require_once __DIR__ . '/../../middleware/auth_middleware.php';
require_once __DIR__ . '/../../models/Message.php';

require_method('POST');

try {
    $user = auth_user();
    enforce_message_rate_limit((int)$user['id'], 'message_read', 60, 60);
    $data = request_json();
    $senderId = max(0, (int)($data['user_id'] ?? 0));
    $upToMessageId = max(0, (int)($data['up_to_message_id'] ?? 0));
    if ($senderId <= 0 || $upToMessageId <= 0) {
        error_response('user_id and up_to_message_id are required.', 422);
    }
    $updated = Message::markRead((int)$user['id'], $senderId, $upToMessageId);
    success_response(['updated_count' => $updated, 'up_to_message_id' => $upToMessageId]);
} catch (OverflowException $error) {
    error_response($error->getMessage(), 429);
} catch (InvalidArgumentException $error) {
    error_response($error->getMessage(), 422);
} catch (RuntimeException $error) {
    error_response($error->getMessage(), 404);
} catch (Throwable $error) {
    error_response($error->getMessage(), 500);
}

