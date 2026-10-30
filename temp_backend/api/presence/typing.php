<?php

require_once __DIR__ . '/../../helpers/response.php';
require_once __DIR__ . '/../../helpers/message_rate_limit.php';
require_once __DIR__ . '/../../middleware/auth_middleware.php';
require_once __DIR__ . '/../../models/Presence.php';

require_method('POST');

try {
    $user = auth_user();
    enforce_message_rate_limit((int)$user['id'], 'presence_typing', 90, 60);
    $data = request_json();
    $receiverId = max(0, (int)($data['receiver_id'] ?? 0));
    if ($receiverId <= 0) {
        error_response('receiver_id is required.', 422);
    }
    if (!array_key_exists('is_typing', $data)) {
        error_response('is_typing is required.', 422);
    }
    $isTyping = filter_var(
        $data['is_typing'],
        FILTER_VALIDATE_BOOLEAN,
        FILTER_NULL_ON_FAILURE
    );
    if ($isTyping === null) {
        error_response('is_typing must be a boolean.', 422);
    }

    success_response([
        'presence' => Presence::setTyping(
            (int)$user['id'],
            $receiverId,
            $isTyping
        ),
    ]);
} catch (OverflowException $error) {
    error_response($error->getMessage(), 429);
} catch (InvalidArgumentException $error) {
    error_response($error->getMessage(), 422);
} catch (RuntimeException $error) {
    error_response($error->getMessage(), 404);
} catch (Throwable $error) {
    error_response($error->getMessage(), 500);
}
