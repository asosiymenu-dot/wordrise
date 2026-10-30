<?php

require_once __DIR__ . '/../../helpers/response.php';
require_once __DIR__ . '/../../helpers/message_rate_limit.php';
require_once __DIR__ . '/../../middleware/auth_middleware.php';
require_once __DIR__ . '/../../models/Message.php';
require_once __DIR__ . '/../../models/User.php';

require_method('GET');

try {
    $user = auth_user();
    enforce_message_rate_limit((int)$user['id'], 'message_thread', 45, 60);
    $otherUserId = (int)($_GET['user_id'] ?? 0);
    if ($otherUserId <= 0) {
        error_response('user_id is required.', 422);
    }

    $otherUser = User::findById($otherUserId);
    if (!$otherUser) {
        error_response('User not found.', 404);
    }

    $limit = max(1, min((int)($_GET['limit'] ?? 50), 200));
    $afterId = max(0, (int)($_GET['after_id'] ?? 0));
    $beforeId = max(0, (int)($_GET['before_id'] ?? 0));
    $updatedSince = trim((string)($_GET['updated_since'] ?? ''));
    if (strlen($updatedSince) > 64) {
        error_response('updated_since is invalid.', 422);
    }
    $result = Message::thread(
        (int)$user['id'],
        $otherUserId,
        $limit,
        $afterId,
        $beforeId,
        $updatedSince === '' ? null : $updatedSince
    );
    success_response([
        'user' => User::publicProfile($otherUser),
        'messages' => $result['messages'],
        'has_more' => $result['has_more'],
        'sync_token' => (new DateTimeImmutable())->format(DateTimeInterface::ATOM),
    ]);
} catch (OverflowException $error) {
    error_response($error->getMessage(), 429);
} catch (InvalidArgumentException $error) {
    error_response($error->getMessage(), 422);
} catch (LogicException $error) {
    error_response($error->getMessage(), 403);
} catch (Throwable $error) {
    error_response($error->getMessage(), 500);
}
