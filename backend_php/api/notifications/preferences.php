<?php

require_once __DIR__ . '/../../helpers/response.php';
require_once __DIR__ . '/../../middleware/auth_middleware.php';
require_once __DIR__ . '/../../models/LearningPreferences.php';

try {
    $user = auth_user();
    $method = strtoupper((string)($_SERVER['REQUEST_METHOD'] ?? 'GET'));
    if ($method === 'GET') {
        success_response(['preferences' => LearningPreferences::get((int)$user['id'])]);
    }
    if ($method === 'POST' || $method === 'PUT') {
        success_response([
            'preferences' => LearningPreferences::update((int)$user['id'], request_json()),
        ]);
    }
    error_response('Method not allowed.', 405);
} catch (InvalidArgumentException $error) {
    error_response($error->getMessage(), 422);
} catch (Throwable $error) {
    error_response($error->getMessage(), 500);
}
