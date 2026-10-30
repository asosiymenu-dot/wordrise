<?php

require_once __DIR__ . '/../../helpers/response.php';
require_once __DIR__ . '/../../helpers/message_rate_limit.php';
require_once __DIR__ . '/../../middleware/auth_middleware.php';
require_once __DIR__ . '/../../models/Presence.php';

require_method('GET');

try {
    $user = auth_user();
    enforce_message_rate_limit((int)$user['id'], 'presence_status', 120, 60);
    $targetUserId = max(0, (int)($_GET['user_id'] ?? 0));
    if ($targetUserId <= 0) {
        error_response('user_id is required.', 422);
    }
    success_response([
        'presence' => Presence::status($targetUserId, (int)$user['id']),
    ]);
} catch (OverflowException $error) {
    error_response($error->getMessage(), 429);
} catch (RuntimeException $error) {
    error_response($error->getMessage(), 404);
} catch (Throwable $error) {
    error_response($error->getMessage(), 500);
}
