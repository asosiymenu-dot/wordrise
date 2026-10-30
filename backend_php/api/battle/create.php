<?php

require_once __DIR__ . '/../../helpers/response.php';
require_once __DIR__ . '/../../middleware/auth_middleware.php';
require_once __DIR__ . '/../../models/Battle.php';

require_method('POST');

try {
    $user = auth_user();
    $data = request_json();
    $lessonId = (int)($data['lesson_id'] ?? 0);
    $limit = (int)($data['limit'] ?? 10);
    $duration = (int)($data['duration_seconds'] ?? 90);
    $direction = trim((string)($data['direction'] ?? 'eng_to_uz'));

    $battle = Battle::create($user, $lessonId > 0 ? $lessonId : null, $limit, $duration, $direction);
    success_response(['battle' => $battle], 'Battle yaratildi.', 201);
} catch (Throwable $error) {
    error_response($error->getMessage(), 500);
}
