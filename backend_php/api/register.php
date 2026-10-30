<?php

require_once __DIR__ . '/../helpers/response.php';
require_once __DIR__ . '/../helpers/auth.php';
require_once __DIR__ . '/../models/User.php';

require_method('POST');

try {
    $data = request_json();
    $name = required_string($data, 'name', 120);
    $username = User::normalizeUsername(required_string($data, 'username', 30));
    $email = strtolower(required_string($data, 'email', 160));
    $password = required_string($data, 'password', 128);
    $role = (string)($data['role'] ?? 'student');

    if (!User::isValidUsername($username)) {
        error_response('Username must be 3-30 chars and may contain letters, numbers, underscore or dot.', 422);
    }
    if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
        error_response('Invalid email.', 422);
    }
    if (strlen($password) < 6) {
        error_response('Password must be at least 6 characters.', 422);
    }
    if (User::findByEmail($email)) {
        error_response('Email already registered.', 409);
    }
    if (User::findByUsername($username)) {
        error_response('Username already registered.', 409);
    }

    $user = User::create($name, $username, $email, $password, $role);
    $deviceName = isset($data['device_name']) ? trim((string)$data['device_name']) : null;
    $ipAddress = $_SERVER['REMOTE_ADDR'] ?? null;
    $token = issue_token((int)$user['id'], $deviceName, $ipAddress);

    success_response([
        'user' => User::publicData($user),
        'token' => $token['token'],
        'expires_at' => $token['expires_at'],
    ], 'Registered.', 201);
} catch (Throwable $error) {
    error_response($error->getMessage(), 500);
}
