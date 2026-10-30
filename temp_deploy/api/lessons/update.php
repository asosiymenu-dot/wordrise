<?php

require_once __DIR__ . '/../../helpers/response.php';
require_once __DIR__ . '/../../middleware/auth_middleware.php';
require_once __DIR__ . '/../../models/Lesson.php';

require_method('PUT');

try {
    $user = auth_user();
    $data = request_json();
    $id = (int)($data['id'] ?? 0);
    $title = required_string($data, 'title', 160);
    $description = optional_string($data, 'description', 1000);
    $category = optional_string($data, 'category', 100) ?? 'General';

    if ($id <= 0) {
        error_response('id is required.', 422);
    }

    $lesson = Lesson::update($id, $user, $title, $description, $category);
    success_response(['lesson' => $lesson], 'Lesson updated.');
} catch (Throwable $error) {
    error_response($error->getMessage(), $error instanceof LogicException ? 403 : 500);
}
