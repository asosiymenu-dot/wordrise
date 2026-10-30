<?php

require_once __DIR__ . '/../../helpers/response.php';
require_once __DIR__ . '/../../middleware/auth_middleware.php';
require_once __DIR__ . '/../../models/Quiz.php';

require_method('GET');

try {
    $user = auth_user();
    $lessonId = (int)($_GET['lesson_id'] ?? 0);
    $mode = trim((string)($_GET['mode'] ?? 'multiple_choice'));
    $direction = trim((string)($_GET['direction'] ?? 'eng_to_uz'));
    $scope = trim((string)($_GET['scope'] ?? 'lesson'));
    $limit = (int)($_GET['limit'] ?? 20);

    $questions = [];
    if ($scope === 'all') {
        $questions = Quiz::generateReview($user, $mode, max(1, min($limit, 50000)), $direction);
    } elseif ($scope === 'difficult') {
        $questions = Quiz::generateMistakes($user, $mode, $direction, max(1, min($limit, 50000))); 
    } else {
        if ($lessonId <= 0) {
            error_response('lesson_id is required for lesson scope.', 422);
        }
        $questions = Quiz::generate($lessonId, $mode, $user, max(1, min($limit, 50000)), $direction);
    }

    success_response(['questions' => $questions]);
} catch (Throwable $error) {
    error_response($error->getMessage(), 500);
}
