<?php

require_once __DIR__ . '/../../helpers/response.php';
require_once __DIR__ . '/../../middleware/auth_middleware.php';
require_once __DIR__ . '/../../models/Word.php';

require_method('GET');

try {
    $user = auth_user();
    $lessonId = (int)($_GET['lesson_id'] ?? 0);
    if ($lessonId <= 0) {
        error_response('lesson_id is required.', 422);
    }
    $limit = max(1, min((int)($_GET['limit'] ?? 100), 500));
    $afterId = max(0, (int)($_GET['after_id'] ?? 0));
    success_response(WordModel::allByLesson($lessonId, $user, $limit, $afterId));
} catch (Throwable $error) {
    error_response($error->getMessage(), 500);
}
