<?php

require_once __DIR__ . '/../../helpers/response.php';
require_once __DIR__ . '/../../helpers/message_rate_limit.php';
require_once __DIR__ . '/../../middleware/auth_middleware.php';
require_once __DIR__ . '/../../models/Message.php';

require_method('GET');

try {
    $user = auth_user();
    enforce_message_rate_limit((int)$user['id'], 'message_conversations', 20, 60);
    $limit = max(1, min((int)($_GET['limit'] ?? 50), 100));
    success_response([
        'conversations' => Message::conversations((int)$user['id'], $limit),
    ]);
} catch (OverflowException $error) {
    error_response($error->getMessage(), 429);
} catch (Throwable $error) {
    error_response($error->getMessage(), 500);
}
