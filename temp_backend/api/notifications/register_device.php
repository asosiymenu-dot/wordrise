<?php

require_once __DIR__ . '/../../helpers/response.php';
require_once __DIR__ . '/../../middleware/auth_middleware.php';
require_once __DIR__ . '/../../models/PushNotification.php';

require_method('POST');

try {
    $user = auth_user();
    $data = request_json();
    $result = PushNotification::registerDevice(
        (int)$user['id'],
        trim((string)($data['token'] ?? '')),
        trim((string)($data['platform'] ?? 'unknown')),
        trim((string)($data['locale'] ?? 'uz'))
    );
    success_response($result);
} catch (InvalidArgumentException $error) {
    error_response($error->getMessage(), 422);
} catch (Throwable $error) {
    error_response($error->getMessage(), 500);
}
