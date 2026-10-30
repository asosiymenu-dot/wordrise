<?php

require_once __DIR__ . '/../../helpers/response.php';
require_once __DIR__ . '/../../middleware/auth_middleware.php';
require_once __DIR__ . '/../../models/Session.php';
require_once __DIR__ . '/../../helpers/websocket.php';

require_method('POST');

try {
    $user = auth_user();
    $data = request_json();
    $sessionId = isset($data['session_id']) ? (int)$data['session_id'] : 0;
    
    if ($sessionId <= 0) {
        error_response('session_id is required.', 422);
    }
    
    $success = Session::revokeSession((int)$user['id'], $sessionId);
    if ($success) {
        // Broadcast to WebSocket to kick the specific connection (if any logic depends on session id).
        // Since we broadcast to the user generally, the frontend should check if its own token is still valid
        // Actually, broadcast session_revoked to this user
        ws_broadcast('session_revoked', [
            'user_id' => (int)$user['id'],
            'session_id' => $sessionId
        ]);
        success_response([], 'Session revoked.');
    } else {
        error_response('Session not found or already revoked.', 404);
    }
} catch (Throwable $error) {
    error_response($error->getMessage(), 500);
}
