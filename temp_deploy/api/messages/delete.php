<?php

require_once __DIR__ . '/../../helpers/response.php';
require_once __DIR__ . '/../../helpers/message_rate_limit.php';
require_once __DIR__ . '/../../middleware/auth_middleware.php';
require_once __DIR__ . '/../../models/Message.php';

require_method('DELETE');

try {
    $user = auth_user();
    enforce_message_rate_limit((int)$user['id'], 'message_delete', 30, 60);
    $data = request_json();
    $messageId = max(0, (int)($data['message_id'] ?? 0));
    $mode = trim((string)($data['mode'] ?? 'for_me'));
    if ($messageId <= 0 || !in_array($mode, ['for_me', 'for_everyone'], true)) {
        error_response('message_id or mode is invalid.', 422);
    }

    if ($mode === 'for_everyone') {
        $message = Message::deleteForEveryone((int)$user['id'], $messageId);
        success_response([
            'mode' => $mode,
            'message' => Message::publicData($message, (int)$user['id']),
        ]);
    }

    Message::deleteForMe((int)$user['id'], $messageId);
    success_response(['mode' => $mode, 'message_id' => $messageId]);
} catch (OverflowException $error) {
    error_response($error->getMessage(), 429);
} catch (DomainException $error) {
    error_response($error->getMessage(), 403);
} catch (LogicException $error) {
    error_response($error->getMessage(), 422);
} catch (RuntimeException $error) {
    error_response($error->getMessage(), 404);
} catch (Throwable $error) {
    error_response($error->getMessage(), 500);
}
