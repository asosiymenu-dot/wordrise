<?php

require_once __DIR__ . '/../../helpers/response.php';
require_once __DIR__ . '/../../middleware/auth_middleware.php';
require_once __DIR__ . '/../../models/Battle.php';

require_method('GET');

try {
    $user = auth_user();
    $battleId = (int)($_GET['battle_id'] ?? 0);
    if ($battleId <= 0) {
        error_response('battle_id is required.', 422);
    }

    $battle = Battle::state($user, $battleId);
    success_response(['battle' => $battle]);
} catch (Throwable $error) {
    error_response($error->getMessage(), 500);
}
