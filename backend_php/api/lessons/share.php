<?php

require_once __DIR__ . '/../../helpers/response.php';
require_once __DIR__ . '/../../middleware/auth_middleware.php';
require_once __DIR__ . '/../../models/Lesson.php';

require_method('POST');

try {
    $user = auth_user();
    $data = request_json();
    $lessonId = (int)($data['lesson_id'] ?? ($data['id'] ?? 0));
    if ($lessonId <= 0) {
        error_response('lesson_id is required.', 422);
    }

    $lesson = Lesson::ensureShared($lessonId, $user);
    $code = (string)$lesson['share_code'];
    success_response([
        'share_code' => $code,
        'share_url' => public_origin() . '/share/' . rawurlencode($code),
        'app_link' => 'wordrise://lesson/' . rawurlencode($code),
        'lesson' => $lesson,
    ], 'Lesson shared.');
} catch (Throwable $error) {
    $status = $error instanceof LogicException ? 403 : 500;
    error_response($error->getMessage(), $status);
}

function public_origin(): string
{
    $scheme = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') ? 'https' : 'http';
    $host = $_SERVER['HTTP_HOST'] ?? 'localhost';
    return $scheme . '://' . $host;
}
