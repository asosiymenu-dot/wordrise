<?php

require_once __DIR__ . '/../../helpers/response.php';
require_once __DIR__ . '/../../middleware/auth_middleware.php';
require_once __DIR__ . '/../../models/User.php';

require_method('PUT');

try {
    $user = auth_user();
    $data = request_json();
    $name = required_string($data, 'name', 120);
    $username = User::normalizeUsername(required_string($data, 'username', 30));
    $email = strtolower(required_string($data, 'email', 160));
    $avatar = optional_string($data, 'avatar', 255);
    $password = optional_string($data, 'password', 128);

    if (!User::isValidUsername($username)) {
        error_response('Username must be 3-30 chars and may contain letters, numbers, underscore or dot.', 422);
    }
    if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
        error_response('Invalid email.', 422);
    }
    if ($password !== null && strlen($password) < 6) {
        error_response('Password must be at least 6 characters.', 422);
    }

    $updated = User::updateProfile((int)$user['id'], $name, $username, $email, $avatar, $password);
    success_response(['user' => User::publicData($updated)], 'Profile updated.');
} catch (Throwable $error) {
    $status = $error instanceof LogicException ? 409 : 500;
    error_response($error->getMessage(), $status);
}
