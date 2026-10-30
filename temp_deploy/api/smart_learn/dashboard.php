<?php

require_once __DIR__ . '/../../helpers/response.php';
require_once __DIR__ . '/../../middleware/auth_middleware.php';
require_once __DIR__ . '/../../models/SmartLearn.php';

require_method('GET');

try {
    $user = auth_user();
    success_response(['dashboard' => SmartLearn::dashboard($user)]);
} catch (Throwable $error) {
    error_response($error->getMessage(), 500);
}
