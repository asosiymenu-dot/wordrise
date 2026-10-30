<?php

require_once __DIR__ . '/../../helpers/response.php';
require_once __DIR__ . '/../../middleware/auth_middleware.php';
require_once __DIR__ . '/../../models/Quiz.php';

require_method('GET');

try {
    $user = auth_user();
    $mode = trim((string)($_GET['mode'] ?? 'multiple_choice'));
    $direction = trim((string)($_GET['direction'] ?? 'eng_to_uz'));
    $limit = max(1, min((int)($_GET['limit'] ?? 20), 50));
    $questions = Quiz::dueReviews($user, $mode, $limit, $direction);
    success_response([
        'due_count' => Quiz::dueReviewCount($user),
        'questions' => $questions,
    ]);
} catch (Throwable $error) {
    error_response($error->getMessage(), 500);
}
