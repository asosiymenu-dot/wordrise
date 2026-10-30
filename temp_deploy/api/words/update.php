<?php

require_once __DIR__ . '/../../helpers/response.php';
require_once __DIR__ . '/../../middleware/auth_middleware.php';
require_once __DIR__ . '/../../models/Word.php';

require_method('PUT');

try {
    $user = auth_user();
    $data = request_json();
    $id = (int)($data['id'] ?? 0);
    if ($id <= 0) {
        error_response('id is required.', 422);
    }

    $word = WordModel::update(
        $id,
        $user,
        required_string($data, 'english_word', 120),
        required_string($data, 'uzbek_translation', 160),
        optional_string($data, 'example_sentence', 255),
        optional_string($data, 'pronunciation', 120)
    );

    success_response(['word' => $word], 'Word updated.');
} catch (Throwable $error) {
    $status = $error instanceof LogicException ? 403 : 500;
    error_response($error->getMessage(), $status);
}
