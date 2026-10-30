<?php

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../helpers/websocket.php';
require_once __DIR__ . '/PushNotification.php';

final class AppNotification
{
    public static function create(int $userId, string $type, string $title, string $body, array $data = []): int
    {
        $table = Database::table('notifications');
        $pdo = Database::connection();
        $stmt = $pdo->prepare(
            "INSERT INTO {$table} (user_id, type, title, body, data_json) VALUES (?, ?, ?, ?, ?)"
        );
        $stmt->execute([
            $userId,
            substr(trim($type), 0, 40),
            substr(trim($title), 0, 160),
            substr(trim($body), 0, 500),
            count($data) > 0 ? json_encode($data, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES) : null,
        ]);
        $notificationId = (int)$pdo->lastInsertId();
        if ($pdo->inTransaction()) {
            self::deferPush($notificationId);
        } else {
            self::deliverPush($notificationId);
        }
        
        $newNotif = [
            'id' => $notificationId,
            'type' => $type,
            'title' => $title,
            'body' => $body,
            'data' => $data,
        ];
        ws_broadcast('notification', $newNotif, $userId);
        
        return $notificationId;
    }

    private static function deferPush(int $notificationId): void
    {
        register_shutdown_function(static function () use ($notificationId): void {
            self::deliverPush($notificationId);
        });
    }

    private static function deliverPush(int $notificationId): void
    {
        try {
            $table = Database::table('notifications');
            $stmt = Database::connection()->prepare("SELECT * FROM {$table} WHERE id = ? LIMIT 1");
            $stmt->execute([$notificationId]);
            $row = $stmt->fetch();
            if (!$row) {
                return;
            }
            $data = json_decode((string)($row['data_json'] ?? ''), true);
            PushNotification::sendToUser(
                (int)$row['user_id'],
                (string)$row['type'],
                (string)$row['title'],
                (string)$row['body'],
                array_merge(is_array($data) ? $data : [], ['notification_id' => $notificationId])
            );
        } catch (Throwable $error) {
            error_log('[WordRise push] ' . $error->getMessage());
        }
    }

    public static function all(int $userId, int $afterId = 0, int $limit = 50): array
    {
        $table = Database::table('notifications');
        $stmt = Database::connection()->prepare(
            "SELECT * FROM {$table}
             WHERE user_id = ? AND id > ?
             ORDER BY id ASC LIMIT ?"
        );
        $stmt->bindValue(1, $userId, PDO::PARAM_INT);
        $stmt->bindValue(2, max(0, $afterId), PDO::PARAM_INT);
        $stmt->bindValue(3, max(1, min($limit, 100)), PDO::PARAM_INT);
        $stmt->execute();
        return array_map([self::class, 'publicData'], $stmt->fetchAll());
    }

    public static function unreadCount(int $userId): int
    {
        $table = Database::table('notifications');
        $stmt = Database::connection()->prepare(
            "SELECT COUNT(*) FROM {$table} WHERE user_id = ? AND read_at IS NULL"
        );
        $stmt->execute([$userId]);
        return (int)$stmt->fetchColumn();
    }

    public static function maxId(int $userId): int
    {
        $table = Database::table('notifications');
        $stmt = Database::connection()->prepare(
            "SELECT MAX(id) FROM {$table} WHERE user_id = ?"
        );
        $stmt->execute([$userId]);
        return (int)$stmt->fetchColumn();
    }

    public static function markRead(int $userId, ?int $notificationId = null): void
    {
        $table = Database::table('notifications');
        if ($notificationId === null) {
            $stmt = Database::connection()->prepare(
                "UPDATE {$table} SET read_at = NOW() WHERE user_id = ? AND read_at IS NULL"
            );
            $stmt->execute([$userId]);
            ws_broadcast('notifications_read', ['user_id' => $userId, 'notification_id' => null], $userId);
            return;
        }
        $stmt = Database::connection()->prepare(
            "UPDATE {$table} SET read_at = NOW() WHERE id = ? AND user_id = ? AND read_at IS NULL"
        );
        $stmt->execute([$notificationId, $userId]);
        ws_broadcast('notifications_read', ['user_id' => $userId, 'notification_id' => $notificationId], $userId);
    }

    public static function publicData(array $row): array
    {
        $data = json_decode((string)($row['data_json'] ?? ''), true);
        return [
            'id' => (int)$row['id'],
            'type' => (string)$row['type'],
            'title' => (string)$row['title'],
            'body' => (string)$row['body'],
            'data' => is_array($data) ? $data : [],
            'read_at' => $row['read_at'],
            'created_at' => $row['created_at'],
        ];
    }
}
