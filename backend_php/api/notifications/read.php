<?php

require_once __DIR__ . '/../../helpers/response.php';
require_once __DIR__ . '/../../middleware/auth_middleware.php';
require_once __DIR__ . '/../../models/AppNotification.php';

require_method('POST');

$user = auth_user();
$data = request_json();
$notificationId = (int)($data['notification_id'] ?? 0);
AppNotification::markRead((int)$user['id'], $notificationId > 0 ? $notificationId : null);
success_response(['unread_count' => AppNotification::unreadCount((int)$user['id'])], 'Notifications read.');
