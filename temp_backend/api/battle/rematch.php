<?php

require_once __DIR__ . '/../../helpers/response.php';
require_once __DIR__ . '/../../middleware/auth_middleware.php';
require_once __DIR__ . '/../../models/Battle.php';

require_method('POST');

try {
    $user = auth_user();
    $data = request_json();
    $battleId = (int)($data['battle_id'] ?? 0);
    if ($battleId <= 0) {
        error_response('battle_id is required.', 422);
    }
    success_response(['invite' => Battle::rematch($user, $battleId)], 'Rematch invite sent.', 201);
} catch (LogicException $error) {
    error_response($error->getMessage(), 403);
} catch (RuntimeException $error) {
    error_response($error->getMessage(), 409);
} catch (Throwable $error) {
    error_response($error->getMessage(), 500);
}
