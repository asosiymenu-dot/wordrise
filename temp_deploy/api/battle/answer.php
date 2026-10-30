<?php

require_once __DIR__ . '/../../helpers/response.php';
require_once __DIR__ . '/../../middleware/auth_middleware.php';
require_once __DIR__ . '/../../models/Battle.php';

require_method('POST');

try {
    $user = auth_user();
    $data = request_json();
    $battleId = (int)($data['battle_id'] ?? 0);
    $questionId = (int)($data['question_id'] ?? 0);
    $answer = trim((string)($data['answer'] ?? ''));
    $answeredMs = (int)($data['answered_ms'] ?? 0);
    if ($battleId <= 0 || $questionId <= 0) {
        error_response('battle_id and question_id are required.', 422);
    }

    $battle = Battle::answer($user, $battleId, $questionId, $answer, $answeredMs);
    success_response(['battle' => $battle], 'Javob qabul qilindi.');
} catch (LogicException $error) {
    error_response($error->getMessage(), 409);
} catch (RuntimeException $error) {
    error_response($error->getMessage(), 404);
} catch (Throwable $error) {
    error_response($error->getMessage(), 500);
}
