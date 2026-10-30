<?php

require_once __DIR__ . '/../../helpers/response.php';
require_once __DIR__ . '/../../middleware/auth_middleware.php';
require_once __DIR__ . '/../../models/Lesson.php';

require_method('DELETE');

try {
    $user = auth_user();
    $data = request_json();
    $id = (int)($data['id'] ?? ($_GET['id'] ?? 0));
    if ($id <= 0) {
        error_response('id is required.', 422);
    }

    Lesson::delete($id, $user);
    success_response([], 'Lesson deleted.');
} catch (Throwable $error) {
    error_response($error->getMessage(), $error instanceof LogicException ? 403 : 500);
}
