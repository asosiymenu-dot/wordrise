<?php

require_once __DIR__ . '/../../helpers/response.php';
require_once __DIR__ . '/../../middleware/auth_middleware.php';
require_once __DIR__ . '/../../models/SmartLearn.php';

require_method('GET');

try {
    $user = auth_user();
    $sessionId = (int)($_GET['session_id'] ?? 0);
    if ($sessionId <= 0) {
        error_response('session_id is required.', 422);
    }
    success_response(SmartLearn::state($user, $sessionId));
} catch (RuntimeException $error) {
    error_response($error->getMessage(), 404);
} catch (Throwable $error) {
    error_response($error->getMessage(), 500);
}
