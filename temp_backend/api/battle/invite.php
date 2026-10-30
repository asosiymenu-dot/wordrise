<?php

require_once __DIR__ . '/../../helpers/response.php';
require_once __DIR__ . '/../../middleware/auth_middleware.php';
require_once __DIR__ . '/../../models/Battle.php';

require_method('POST');

try {
    $user = auth_user();
    $data = request_json();
    $receiverId = (int)($data['receiver_id'] ?? 0);
    $lessonId = (int)($data['lesson_id'] ?? 0);
    $limit = (int)($data['limit'] ?? 10);
    $duration = (int)($data['duration_seconds'] ?? 90);
    $direction = trim((string)($data['direction'] ?? 'eng_to_uz'));
    $invite = Battle::invite(
        $user,
        $receiverId,
        $lessonId > 0 ? $lessonId : null,
        $limit,
        $duration,
        $direction
    );
    success_response(['invite' => $invite], 'Battle invite sent.', 201);
} catch (InvalidArgumentException $error) {
    error_response($error->getMessage(), 422);
} catch (LogicException $error) {
    error_response($error->getMessage(), 403);
} catch (RuntimeException $error) {
    error_response($error->getMessage(), 409);
} catch (Throwable $error) {
    error_response($error->getMessage(), 500);
}
