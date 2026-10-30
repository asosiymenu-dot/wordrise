<?php

require_once __DIR__ . '/../../helpers/response.php';
require_once __DIR__ . '/../../helpers/message_rate_limit.php';
require_once __DIR__ . '/../../middleware/auth_middleware.php';
require_once __DIR__ . '/../../models/Message.php';

require_method('POST');

try {
    $user = auth_user();
    enforce_message_rate_limit((int)$user['id'], 'message_broadcast', 3, 60);
    $data = request_json();
    $body = required_string($data, 'body', 1000);

    $result = Message::broadcastFromAdmin($user, $body);
    success_response($result, 'Broadcast sent.', 201);
} catch (OverflowException $error) {
    error_response($error->getMessage(), 429);
} catch (Throwable $error) {
    $status = $error instanceof LogicException ? 403 : 500;
    error_response($error->getMessage(), $status);
}
