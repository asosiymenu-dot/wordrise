<?php

require_once __DIR__ . '/../../helpers/response.php';
require_once __DIR__ . '/../../middleware/auth_middleware.php';
require_once __DIR__ . '/../../models/Lesson.php';
require_once __DIR__ . '/../../models/Word.php';

require_method('GET');

try {
    $user = auth_user();
    $lessonId = (int)($_GET['id'] ?? ($_GET['lesson_id'] ?? 0));
    if ($lessonId <= 0) {
        error_response('lesson_id is required.', 422);
    }

    $lesson = Lesson::findVisible($lessonId, $user);
    if (!$lesson) {
        error_response('Lesson not found.', 404);
    }

    success_response([
        'bundle' => [
            'version' => 1,
            'lesson' => [
                'title' => $lesson['title'],
                'description' => $lesson['description'],
                'category' => $lesson['category'],
            ],
            'words' => WordModel::allByLesson($lessonId, $user),
        ],
    ]);
} catch (Throwable $error) {
    error_response($error->getMessage(), 500);
}
