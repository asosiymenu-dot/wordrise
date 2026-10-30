<?php

require_once __DIR__ . '/../../helpers/response.php';
require_once __DIR__ . '/../../middleware/auth_middleware.php';
require_once __DIR__ . '/../../models/Grammar.php';

require_method('GET');

try {
    auth_user();
    $level = trim((string)($_GET['level'] ?? ''));
    success_response(['lessons' => Grammar::all($level === '' ? null : $level)]);
} catch (Throwable $error) {
    error_response($error->getMessage(), 500);
}
