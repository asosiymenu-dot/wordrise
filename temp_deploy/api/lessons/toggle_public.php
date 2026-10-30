<?php

require_once __DIR__ . '/../../helpers/response.php';
require_once __DIR__ . '/../../middleware/auth_middleware.php';
require_once __DIR__ . '/../../models/Lesson.php';

require_method('POST');

try {
    $user = auth_user();
    $data = request_json();
    $lessonId = (int)($data['lesson_id'] ?? ($data['id'] ?? 0));
    if ($lessonId <= 0) {
        error_response('lesson_id is required.', 422);
    }
    $isPublic = filter_var($data['is_public'] ?? false, FILTER_VALIDATE_BOOL);

    $lesson = Lesson::togglePublic($lessonId, $user, $isPublic);
    success_response(['lesson' => $lesson], $isPublic ? 'Lesson is public.' : 'Lesson is private.');
} catch (Throwable $error) {
    $status = $error instanceof LogicException ? 403 : 500;
    error_response($error->getMessage(), $status);
}
