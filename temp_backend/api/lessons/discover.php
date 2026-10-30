<?php

require_once __DIR__ . '/../../helpers/response.php';
require_once __DIR__ . '/../../middleware/auth_middleware.php';
require_once __DIR__ . '/../../models/Lesson.php';

require_method('GET');

try {
    auth_user();
    success_response(Lesson::discover([
        'q' => $_GET['q'] ?? '',
        'category' => $_GET['category'] ?? '',
        'sort' => $_GET['sort'] ?? 'popular',
        'page' => $_GET['page'] ?? 1,
        'per_page' => $_GET['per_page'] ?? 20,
    ]));
} catch (Throwable $error) {
    error_response($error->getMessage(), 500);
}
