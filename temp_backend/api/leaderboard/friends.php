<?php

require_once __DIR__ . '/../../helpers/response.php';
require_once __DIR__ . '/../../middleware/auth_middleware.php';
require_once __DIR__ . '/../../models/Leaderboard.php';

require_method('GET');

try {
    $user = auth_user();
    $scope = trim((string)($_GET['scope'] ?? 'global'));
    if (!in_array($scope, ['global', 'daily', 'weekly'], true)) {
        error_response('Invalid leaderboard scope.', 422);
    }
    success_response([
        'leaderboard' => Leaderboard::friends((int)$user['id'], $scope, 50),
    ]);
} catch (Throwable $error) {
    error_response($error->getMessage(), 500);
}
