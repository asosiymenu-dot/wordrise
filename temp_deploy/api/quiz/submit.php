<?php

require_once __DIR__ . '/../../helpers/response.php';
require_once __DIR__ . '/../../middleware/auth_middleware.php';
require_once __DIR__ . '/../../models/Quiz.php';

require_method('POST');

try {
    $user = auth_user();
    $data = request_json();
    $lessonId = (int)($data['lesson_id'] ?? 0);
    $mode = trim((string)($data['mode'] ?? 'multiple_choice'));
    $direction = trim((string)($data['direction'] ?? 'eng_to_uz'));
    $answers = $data['answers'] ?? [];
    if (!is_array($answers) || empty($answers)) {
        error_response('answers are required.', 422);
    }

    if ($lessonId <= 0) {
        $result = Quiz::submitReview($mode, $answers, $user, $direction);
        success_response(['result' => $result], 'Review submitted.');
    }

    $result = Quiz::submit($lessonId, $mode, $answers, $user, $direction);
    success_response(['result' => $result], 'Quiz submitted.');
} catch (Throwable $error) {
    error_response($error->getMessage(), 500);
}
