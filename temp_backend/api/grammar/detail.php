<?php

require_once __DIR__ . '/../../helpers/response.php';
require_once __DIR__ . '/../../middleware/auth_middleware.php';
require_once __DIR__ . '/../../models/Grammar.php';

require_method('GET');

try {
    auth_user();
    $lessonId = (int)($_GET['id'] ?? ($_GET['lesson_id'] ?? 0));
    $topicId = (int)($_GET['topic_id'] ?? 0);
    if ($lessonId <= 0 && $topicId <= 0) {
        error_response('lesson_id or topic_id is required.', 422);
    }

    $detail = Grammar::detail($lessonId, $topicId);
    if (!$detail) {
        error_response('Grammar lesson not found.', 404);
    }
    success_response($detail);
} catch (Throwable $error) {
    error_response($error->getMessage(), 500);
}
