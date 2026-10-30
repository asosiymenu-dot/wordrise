<?php

require_once __DIR__ . '/../../helpers/response.php';
require_once __DIR__ . '/../../middleware/auth_middleware.php';
require_once __DIR__ . '/../../models/Grammar.php';

require_method('GET');

try {
    $user = auth_user();
    $level = trim((string)($_GET['level'] ?? ($_GET['level_code'] ?? 'A1')));
    success_response(['topics' => Grammar::topics($level, $user)]);
} catch (Throwable $error) {
    error_response($error->getMessage(), 500);
}
