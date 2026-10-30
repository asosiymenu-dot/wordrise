<?php

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../helpers/datetime.php';
require_once __DIR__ . '/../helpers/websocket.php';
require_once __DIR__ . '/User.php';

final class Presence
{
    public static function heartbeat(int $userId): array
    {
        $users = Database::table('users');
        $stmt = Database::connection()->prepare(
            "UPDATE {$users} SET last_seen_at = NOW() WHERE id = ?"
        );
        $stmt->execute([$userId]);
        $status = self::status($userId, $userId);
        ws_broadcast('user_status_changed', $status);
        return $status;
    }

    public static function status(int $userId, ?int $viewerUserId = null): array
    {
        $user = User::findById($userId);
        if (!$user) {
            throw new RuntimeException('User not found.');
        }

        $lastSeenAt = $user['last_seen_at'] ?? null;
        $typingToUserId = (int)($user['typing_to_user_id'] ?? 0);
        $typingExpiresAt = $user['typing_expires_at'] ?? null;
        $isTyping = $viewerUserId !== null
            && $typingToUserId === $viewerUserId
            && $typingExpiresAt !== null
            && strtotime((string)$typingExpiresAt) >= time();
        return [
            'user_id' => (int)$user['id'],
            'is_online' => api_is_online($lastSeenAt),
            'is_typing' => $isTyping,
            'last_seen_at' => api_iso_datetime($lastSeenAt),
            'server_time' => (new DateTimeImmutable())->format(DateTimeInterface::ATOM),
        ];
    }

    public static function setTyping(int $userId, int $receiverId, bool $isTyping): array
    {
        if ($userId === $receiverId) {
            throw new InvalidArgumentException('You cannot type to yourself.');
        }
        if (!User::findById($receiverId)) {
            throw new RuntimeException('Receiver not found.');
        }

        $users = Database::table('users');
        $pdo = Database::connection();
        if ($isTyping) {
            $stmt = $pdo->prepare(
                "UPDATE {$users}
                 SET last_seen_at = NOW(), typing_to_user_id = ?,
                     typing_expires_at = DATE_ADD(NOW(), INTERVAL 7 SECOND)
                 WHERE id = ?"
            );
            $stmt->execute([$receiverId, $userId]);
        } else {
            $stmt = $pdo->prepare(
                "UPDATE {$users}
                 SET typing_to_user_id = NULL, typing_expires_at = NULL
                 WHERE id = ? AND typing_to_user_id = ?"
            );
            $stmt->execute([$userId, $receiverId]);
        }

        $status = self::status($userId, $receiverId);
        ws_broadcast('typing_status', $status, $receiverId);
        return $status;
    }
}
