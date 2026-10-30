<?php

require_once __DIR__ . '/../../helpers/response.php';
require_once __DIR__ . '/../../middleware/auth_middleware.php';
require_once __DIR__ . '/../../models/Quiz.php';

require_method('GET');

try {
    $user = auth_user();
    $mode = trim((string)($_GET['mode'] ?? 'multiple_choice'));
    $direction = trim((string)($_GET['direction'] ?? 'eng_to_uz'));
    $limit = (int)($_GET['limit'] ?? 10);

    $questions = Quiz::generateReview($user, $mode, max(1, min($limit, 50000)), $direction);
    success_response(['questions' => $questions]);
} catch (Throwable $error) {
    error_response($error->getMessage(), 500);
}
