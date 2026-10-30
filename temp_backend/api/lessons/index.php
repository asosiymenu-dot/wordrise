<?php

require_once __DIR__ . '/../../helpers/response.php';
require_once __DIR__ . '/../../middleware/auth_middleware.php';
require_once __DIR__ . '/../../models/Lesson.php';

require_method('GET');

$user = auth_user();
$limit = max(1, min((int)($_GET['limit'] ?? 50), 200));
$afterId = max(0, (int)($_GET['after_id'] ?? 0));

success_response(Lesson::allForUser($user, $limit, $afterId));
