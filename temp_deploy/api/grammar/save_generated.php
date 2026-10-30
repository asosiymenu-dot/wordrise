<?php

require_once __DIR__ . '/../../helpers/response.php';
require_once __DIR__ . '/../../middleware/auth_middleware.php';
require_once __DIR__ . '/../../models/Grammar.php';

require_method('POST');

try {
    $user = auth_user();
    $data = request_json();
    success_response(Grammar::saveGenerated($user, $data), 'Grammar lesson saved.', 201);
} catch (Throwable $error) {
    error_response($error->getMessage(), $error instanceof LogicException ? 403 : 500);
}
