<?php

require_once __DIR__ . '/../../helpers/response.php';
require_once __DIR__ . '/../../middleware/auth_middleware.php';
require_once __DIR__ . '/../../models/Word.php';
require_once __DIR__ . '/../../models/UserWordProgress.php';

require_method('POST');

try {
    $user = auth_user();
    $data = request_json();
    $wordId = (int)($data['word_id'] ?? 0);
    if ($wordId <= 0) {
        error_response('word_id is required.', 422);
    }
    if (!WordModel::findInVisibleLesson($wordId, $user)) {
        error_response('Word not found.', 404);
    }
    $isStarred = filter_var($data['is_starred'] ?? false, FILTER_VALIDATE_BOOLEAN);
    success_response([
        'progress' => UserWordProgress::setStarred((int)$user['id'], $wordId, $isStarred),
    ]);
} catch (Throwable $error) {
    error_response($error->getMessage(), 500);
}
