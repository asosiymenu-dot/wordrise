<?php

require_once __DIR__ . '/../../helpers/response.php';
require_once __DIR__ . '/../../helpers/message_rate_limit.php';
require_once __DIR__ . '/../../middleware/auth_middleware.php';
require_once __DIR__ . '/../../models/Message.php';

require_method('PUT');

try {
    $user = auth_user();
    enforce_message_rate_limit((int)$user['id'], 'message_update', 30, 60);
    $data = request_json();
    $messageId = max(0, (int)($data['message_id'] ?? 0));
    if ($messageId <= 0) {
        error_response('message_id is required.', 422);
    }
    $body = trim((string)($data['body'] ?? ''));
    $message = Message::updateText((int)$user['id'], $messageId, $body);
    success_response(['message' => Message::publicData($message, (int)$user['id'])]);
} catch (OverflowException $error) {
    error_response($error->getMessage(), 429);
} catch (DomainException $error) {
    error_response($error->getMessage(), 403);
} catch (LogicException $error) {
    error_response($error->getMessage(), 422);
} catch (RuntimeException $error) {
    error_response($error->getMessage(), 404);
} catch (Throwable $error) {
    error_response($error->getMessage(), 500);
}
