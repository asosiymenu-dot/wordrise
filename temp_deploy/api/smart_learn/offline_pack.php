<?php

require_once __DIR__ . '/../../helpers/response.php';
require_once __DIR__ . '/../../middleware/auth_middleware.php';
require_once __DIR__ . '/../../models/SmartLearn.php';

require_method('GET');

try {
    $user = auth_user();
    $limit = max(20, min((int)($_GET['limit'] ?? 200), 200));
    success_response(['pack' => SmartLearn::offlinePack($user, $limit)]);
} catch (Throwable $error) {
    error_response($error->getMessage(), 500);
}
