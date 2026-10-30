<?php

require_once __DIR__ . '/../../helpers/response.php';
require_once __DIR__ . '/../../middleware/auth_middleware.php';
require_once __DIR__ . '/../../models/Grammar.php';

require_method('POST');

try {
    $user = auth_user();
    $data = request_json();
    $topicId = (int)($data['topic_id'] ?? 0);
    $answers = is_array($data['answers'] ?? null) ? $data['answers'] : [];
    if ($topicId <= 0 || count($answers) === 0) {
        error_response('topic_id and answers are required.', 422);
    }

    success_response(Grammar::submit($user, $topicId, $answers), 'Grammar progress saved.');
} catch (Throwable $error) {
    error_response($error->getMessage(), $error instanceof LogicException ? 403 : 500);
}
