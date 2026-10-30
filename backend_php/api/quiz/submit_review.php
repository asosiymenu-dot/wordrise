<?php

require_once __DIR__ . '/../../helpers/response.php';
require_once __DIR__ . '/../../middleware/auth_middleware.php';
require_once __DIR__ . '/../../models/Quiz.php';

require_method('POST');

try {
    $user = auth_user();
    $data = request_json();
    $mode = trim((string)($data['mode'] ?? 'multiple_choice'));
    $direction = trim((string)($data['direction'] ?? 'eng_to_uz'));
    $answers = $data['answers'] ?? [];
    if (!is_array($answers)) {
        error_response('answers are required.', 422);
    }

    $result = Quiz::submitReview($mode, $answers, $user, $direction);
    success_response(['result' => $result], 'Review submitted.');
} catch (Throwable $error) {
    error_response($error->getMessage(), 500);
}
