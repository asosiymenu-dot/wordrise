<?php

require_once __DIR__ . '/../../helpers/response.php';
require_once __DIR__ . '/../../middleware/auth_middleware.php';
require_once __DIR__ . '/../../models/Leaderboard.php';

require_method('GET');

auth_user();
$limit = (int)($_GET['limit'] ?? 50);
success_response(['leaderboard' => Leaderboard::daily(max(1, min($limit, 100)))]);
