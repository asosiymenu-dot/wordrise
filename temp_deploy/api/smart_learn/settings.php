<?php

require_once __DIR__ . '/../../helpers/response.php';
require_once __DIR__ . '/../../middleware/auth_middleware.php';
require_once __DIR__ . '/../../models/SmartLearn.php';

require_method('POST');

try {
    $user = auth_user();
    $data = request_json();
    $goal = (int)($data['daily_goal_minutes'] ?? 0);
    $direction = trim((string)($data['preferred_direction'] ?? 'mixed'));
    $settings = SmartLearn::updateSettings((int)$user['id'], $goal, $direction);
    success_response(['settings' => $settings], 'Learning settings updated.');
} catch (InvalidArgumentException $error) {
    error_response($error->getMessage(), 422);
} catch (Throwable $error) {
    error_response($error->getMessage(), 500);
}
