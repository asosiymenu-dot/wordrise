<?php

require_once __DIR__ . '/../../helpers/response.php';
require_once __DIR__ . '/../../middleware/auth_middleware.php';
require_once __DIR__ . '/../../models/SmartLearn.php';

require_method('POST');

try {
    $user = auth_user();
    $data = request_json();
    $goal = array_key_exists('daily_goal_minutes', $data) ? (int)$data['daily_goal_minutes'] : null;
    $direction = array_key_exists('direction', $data) ? trim((string)$data['direction']) : null;
    $resume = !array_key_exists('resume', $data) || (bool)$data['resume'];
    $state = SmartLearn::start($user, $goal, $direction, $resume);
    success_response($state, $state['session']['answered_count'] > 0 ? 'Session resumed.' : 'Session started.', 201);
} catch (InvalidArgumentException $error) {
    error_response($error->getMessage(), 422);
} catch (RuntimeException $error) {
    error_response($error->getMessage(), 409);
} catch (Throwable $error) {
    error_response($error->getMessage(), 500);
}
