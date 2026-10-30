<?php

require_once __DIR__ . '/../../helpers/response.php';
require_once __DIR__ . '/../../middleware/auth_middleware.php';
require_once __DIR__ . '/../../models/SmartLearn.php';

require_method('POST');

try {
    $user = auth_user();
    $data = request_json();
    $sessionId = (int)($data['session_id'] ?? 0);
    $itemId = (int)($data['item_id'] ?? 0);
    $answer = trim((string)($data['answer'] ?? ''));
    $answerMs = (int)($data['answer_ms'] ?? 0);
    if ($sessionId <= 0 || $itemId <= 0 || $answer === '') {
        error_response('session_id, item_id and answer are required.', 422);
    }
    success_response(SmartLearn::answer($user, $sessionId, $itemId, $answer, $answerMs), 'Answer processed.');
} catch (LogicException $error) {
    error_response($error->getMessage(), 409);
} catch (RuntimeException $error) {
    error_response($error->getMessage(), 404);
} catch (Throwable $error) {
    error_response($error->getMessage(), 500);
}
