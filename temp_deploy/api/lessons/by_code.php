<?php

require_once __DIR__ . '/../../helpers/response.php';
require_once __DIR__ . '/../../models/Lesson.php';

require_method('GET');

try {
    $code = trim((string)($_GET['code'] ?? ''));
    if ($code === '') {
        error_response('code is required.', 422);
    }

    $lesson = Lesson::findByShareCode($code);
    if (!$lesson) {
        error_response('Ulashilgan dars topilmadi.', 404);
    }

    $includeWords = (int)($_GET['include_words'] ?? 0) === 1;
    success_response(['lesson' => Lesson::publicPreview($lesson, $includeWords)]);
} catch (Throwable $error) {
    error_response($error->getMessage(), 500);
}
