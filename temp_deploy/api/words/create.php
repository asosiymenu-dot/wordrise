<?php

require_once __DIR__ . '/../../helpers/response.php';
require_once __DIR__ . '/../../middleware/auth_middleware.php';
require_once __DIR__ . '/../../models/Word.php';

require_method('POST');

try {
    $user = auth_user();
    $data = request_json();
    $lessonId = (int)($data['lesson_id'] ?? 0);
    if ($lessonId <= 0) {
        error_response('lesson_id is required.', 422);
    }

    $word = WordModel::create(
        $lessonId,
        $user,
        required_string($data, 'english_word', 120),
        required_string($data, 'uzbek_translation', 160),
        optional_string($data, 'example_sentence', 255),
        optional_string($data, 'pronunciation', 120)
    );

    success_response(['word' => $word], 'Word created.', 201);
} catch (Throwable $error) {
    $status = $error instanceof LogicException ? 403 : 500;
    error_response($error->getMessage(), $status);
}
