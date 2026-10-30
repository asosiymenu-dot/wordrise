<?php

require_once __DIR__ . '/../../helpers/response.php';
require_once __DIR__ . '/../../middleware/auth_middleware.php';
require_once __DIR__ . '/../../models/Battle.php';

require_method('POST');

try {
    $user = auth_user();
    $data = request_json();
    $inviteId = (int)($data['invite_id'] ?? 0);
    $action = trim((string)($data['action'] ?? ''));
    if ($inviteId <= 0) {
        error_response('invite_id is required.', 422);
    }
    success_response(Battle::respondInvite($user, $inviteId, $action), 'Battle invite updated.');
} catch (InvalidArgumentException $error) {
    error_response($error->getMessage(), 422);
} catch (LogicException $error) {
    error_response($error->getMessage(), 403);
} catch (RuntimeException $error) {
    error_response($error->getMessage(), 409);
} catch (Throwable $error) {
    error_response($error->getMessage(), 500);
}
