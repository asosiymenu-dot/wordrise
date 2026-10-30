<?php

require_once __DIR__ . '/../../helpers/response.php';
require_once __DIR__ . '/../../middleware/auth_middleware.php';
require_once __DIR__ . '/../../models/Session.php';

require_method('GET');

try {
    $user = auth_user();
    $sessions = Session::getActiveSessions((int)$user['id']);
    
    success_response([
        'sessions' => $sessions
    ], 'Active sessions retrieved.');
} catch (Throwable $error) {
    error_response($error->getMessage(), 500);
}
