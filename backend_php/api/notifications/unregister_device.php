<?php

require_once __DIR__ . '/../../helpers/response.php';
require_once __DIR__ . '/../../middleware/auth_middleware.php';
require_once __DIR__ . '/../../models/PushNotification.php';

require_method('POST');

try {
    $user = auth_user();
    $data = request_json();
    PushNotification::unregisterDevice(
        (int)$user['id'],
        trim((string)($data['token'] ?? ''))
    );
    success_response(['unregistered' => true]);
} catch (Throwable $error) {
    error_response($error->getMessage(), 500);
}
