<?php

require_once __DIR__ . '/../../helpers/response.php';
require_once __DIR__ . '/../../middleware/auth_middleware.php';
require_once __DIR__ . '/../../models/SmartLearn.php';

require_method('POST');

try {
    $user = auth_user();
    $data = request_json();
    $events = $data['events'] ?? [];
    if (!is_array($events)) {
        error_response('events array is required.', 422);
    }
    success_response(SmartLearn::syncOfflineAnswers($user, $events));
} catch (InvalidArgumentException $error) {
    error_response($error->getMessage(), 422);
} catch (Throwable $error) {
    error_response($error->getMessage(), 500);
}
