<?php

require_once __DIR__ . '/../helpers/response.php';
require_once __DIR__ . '/../helpers/auth.php';
require_once __DIR__ . '/../models/User.php';

require_method('POST');

try {
    $data = request_json();
    $identifier = trim((string)($data['identifier'] ?? ($data['email'] ?? '')));
    if ($identifier === '') {
        error_response('identifier is required.', 422);
    }
    if (strlen($identifier) > 160) {
        error_response('identifier is too long.', 422);
    }
    $password = required_string($data, 'password', 128);
    enforce_login_rate_limit($identifier);

    $user = User::findByIdentifier($identifier);
    if (!$user || !password_verify($password, $user['password_hash'])) {
        record_login_failure($identifier);
        error_response('Username/email or password is incorrect.', 401);
    }

    clear_login_failures($identifier);
    $deviceName = isset($data['device_name']) ? trim((string)$data['device_name']) : null;
    $ipAddress = $_SERVER['REMOTE_ADDR'] ?? null;
    $token = issue_token((int)$user['id'], $deviceName, $ipAddress);

    success_response([
        'user' => User::publicData($user),
        'token' => $token['token'],
        'expires_at' => $token['expires_at'],
    ], 'Logged in.');
} catch (Throwable $error) {
    error_response($error->getMessage(), 500);
}
