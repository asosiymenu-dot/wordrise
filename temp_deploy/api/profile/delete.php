<?php

require_once __DIR__ . '/../../helpers/response.php';
require_once __DIR__ . '/../../middleware/auth_middleware.php';
require_once __DIR__ . '/../../models/User.php';

require_method('POST');

try {
    $user = auth_user();
    $userId = (int)$user['id'];
    
    User::deleteAccount($userId);
    success_response(['deleted' => true], 'Account deleted successfully.');
} catch (Throwable $error) {
    error_response($error->getMessage(), 500);
}
