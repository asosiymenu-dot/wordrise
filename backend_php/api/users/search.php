<?php

require_once __DIR__ . '/../../helpers/response.php';
require_once __DIR__ . '/../../middleware/auth_middleware.php';
require_once __DIR__ . '/../../models/User.php';

require_method('GET');

$user = auth_user();
$query = trim((string)($_GET['q'] ?? ''));
if (strlen($query) < 2) {
    success_response(['users' => []]);
}

$limit = max(1, min((int)($_GET['limit'] ?? 20), 50));
success_response([
    'users' => User::search($query, (int)$user['id'], $limit),
]);
