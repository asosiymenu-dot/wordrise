<?php

require_once __DIR__ . '/../../helpers/response.php';
require_once __DIR__ . '/../../middleware/auth_middleware.php';
require_once __DIR__ . '/../../models/Grammar.php';

require_method('GET');

try {
    $user = auth_user();
    $limit = max(1, min((int)($_GET['limit'] ?? 20), 50));
    success_response(['exercises' => Grammar::reviewMistakes($user, $limit)]);
} catch (Throwable $error) {
    error_response($error->getMessage(), 500);
}
