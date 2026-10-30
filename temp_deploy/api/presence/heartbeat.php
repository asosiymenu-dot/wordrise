<?php

require_once __DIR__ . '/../../helpers/response.php';
require_once __DIR__ . '/../../helpers/message_rate_limit.php';
require_once __DIR__ . '/../../middleware/auth_middleware.php';
require_once __DIR__ . '/../../models/Presence.php';

require_method('POST');

try {
    $user = auth_user();
    enforce_message_rate_limit((int)$user['id'], 'presence_heartbeat', 6, 60);
    success_response(['presence' => Presence::heartbeat((int)$user['id'])]);
} catch (OverflowException $error) {
    error_response($error->getMessage(), 429);
} catch (Throwable $error) {
    error_response($error->getMessage(), 500);
}

