<?php

require_once __DIR__ . '/../../helpers/response.php';
require_once __DIR__ . '/../../middleware/auth_middleware.php';
require_once __DIR__ . '/../../models/AppNotification.php';

require_method('GET');

$user = auth_user();
$afterId = max(0, (int)($_GET['after_id'] ?? 0));
$limit = max(1, min((int)($_GET['limit'] ?? 50), 100));
success_response([
    'notifications' => AppNotification::all((int)$user['id'], $afterId, $limit),
    'unread_count' => AppNotification::unreadCount((int)$user['id']),
    'max_id' => AppNotification::maxId((int)$user['id']),
]);
