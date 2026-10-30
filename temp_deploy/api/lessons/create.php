<?php

require_once __DIR__ . '/../../helpers/response.php';
require_once __DIR__ . '/../../middleware/auth_middleware.php';
require_once __DIR__ . '/../../models/Lesson.php';

require_method('POST');

try {
    $user = auth_user();
    $data = request_json();
    $title = required_string($data, 'title', 160);
    $description = optional_string($data, 'description', 1000);
    $category = optional_string($data, 'category', 100) ?? 'General';

    $lesson = Lesson::create((int)$user['id'], $title, $description, $category);
    success_response(['lesson' => $lesson], 'Lesson created.', 201);
} catch (Throwable $error) {
    error_response($error->getMessage(), $error instanceof LogicException ? 403 : 500);
}
