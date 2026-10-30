<?php

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../helpers/datetime.php';
require_once __DIR__ . '/../helpers/websocket.php';
require_once __DIR__ . '/User.php';
require_once __DIR__ . '/Battle.php';
require_once __DIR__ . '/AppNotification.php';

final class Message
{
    public static function conversations(int $userId, int $limit = 50): array
    {
        $messages = Database::table('messages');
        $deletions = Database::table('message_user_deletions');
        $stmt = Database::connection()->prepare(
            "SELECT other_user_id, MAX(message_id) AS last_message_id
             FROM (
                 SELECT m.receiver_id AS other_user_id, m.id AS message_id
                 FROM {$messages} m
                 WHERE m.sender_id = ?
                   AND NOT EXISTS (
                     SELECT 1 FROM {$deletions} d
                     WHERE d.message_id = m.id AND d.user_id = ?
                   )
                 UNION ALL
                 SELECT m.sender_id AS other_user_id, m.id AS message_id
                 FROM {$messages} m
                 WHERE m.receiver_id = ?
                   AND NOT EXISTS (
                     SELECT 1 FROM {$deletions} d
                     WHERE d.message_id = m.id AND d.user_id = ?
                   )
             ) items
             GROUP BY other_user_id
             ORDER BY last_message_id DESC
             LIMIT ?"
        );
        $stmt->bindValue(1, $userId, PDO::PARAM_INT);
        $stmt->bindValue(2, $userId, PDO::PARAM_INT);
        $stmt->bindValue(3, $userId, PDO::PARAM_INT);
        $stmt->bindValue(4, $userId, PDO::PARAM_INT);
        $stmt->bindValue(5, $limit, PDO::PARAM_INT);
        $stmt->execute();

        $conversations = [];
        foreach ($stmt->fetchAll() as $row) {
            $otherUserId = (int)$row['other_user_id'];
            $otherUser = User::findById($otherUserId);
            if (!$otherUser) {
                continue;
            }
            $lastMessage = self::lastBetween($userId, $otherUserId);
            if (!$lastMessage) {
                continue;
            }
            $conversations[] = [
                'user' => User::publicProfile($otherUser),
                'last_message' => self::publicData($lastMessage, $userId),
                'unread_count' => self::unreadCount($userId, $otherUserId),
            ];
        }

        return $conversations;
    }

    public static function thread(
        int $userId,
        int $otherUserId,
        int $limit = 50,
        int $afterId = 0,
        int $beforeId = 0,
        ?string $updatedSince = null
    ): array {
        if (!User::findById($otherUserId)) {
            throw new RuntimeException('User not found.');
        }
        if ($userId === $otherUserId) {
            throw new LogicException('You cannot open a chat with yourself.');
        }

        $messages = Database::table('messages');
        $deletions = Database::table('message_user_deletions');
        $params = [$userId, $otherUserId, $otherUserId, $userId, $userId];
        $where = "((m.sender_id = ? AND m.receiver_id = ?)
                   OR (m.sender_id = ? AND m.receiver_id = ?))
                  AND NOT EXISTS (
                    SELECT 1 FROM {$deletions} d
                    WHERE d.message_id = m.id AND d.user_id = ?
                  )";

        if ($beforeId > 0) {
            $where .= ' AND m.id < ?';
            $params[] = $beforeId;
        }

        $normalizedUpdatedSince = self::normalizeSyncTime($updatedSince);
        $incremental = $beforeId === 0 && ($afterId > 0 || $normalizedUpdatedSince !== null);
        if ($incremental) {
            $changed = [];
            if ($afterId > 0) {
                $changed[] = 'm.id > ?';
                $params[] = $afterId;
            }
            if ($normalizedUpdatedSince !== null) {
                $changed[] = 'm.updated_at >= ?';
                $params[] = $normalizedUpdatedSince;
            }
            $where .= ' AND (' . implode(' OR ', $changed) . ')';
        }

        $fetchLimit = $incremental ? min(200, $limit) : min(201, $limit + 1);
        $order = $incremental ? 'ASC' : 'DESC';
        $sql = "SELECT m.* FROM {$messages} m WHERE {$where} ORDER BY m.id {$order} LIMIT ?";
        $stmt = Database::connection()->prepare($sql);
        foreach ($params as $index => $value) {
            $stmt->bindValue($index + 1, $value, PDO::PARAM_INT);
        }
        if ($incremental && $normalizedUpdatedSince !== null) {
            $syncIndex = count($params);
            $stmt->bindValue($syncIndex, $normalizedUpdatedSince, PDO::PARAM_STR);
        }
        $stmt->bindValue(count($params) + 1, $fetchLimit, PDO::PARAM_INT);
        $stmt->execute();
        $rows = $stmt->fetchAll();

        $hasMore = !$incremental && count($rows) > $limit;
        if ($hasMore) {
            array_pop($rows);
        }
        if (!$incremental) {
            $rows = array_reverse($rows);
        }

        return [
            'messages' => array_map(static function (array $message) use ($userId): array {
                return self::publicData($message, $userId);
            }, $rows),
            'has_more' => $hasMore,
        ];
    }

    public static function send(
        int $senderId,
        int $receiverId,
        string $body,
        ?string $clientMessageId = null,
        ?int $replyToMessageId = null
    ): array {
        self::validateReceiver($senderId, $receiverId);
        self::validateClientMessageId($clientMessageId);
        self::validateText($body);
        $replyToMessageId = self::validateReply($senderId, $receiverId, $replyToMessageId);

        $messages = Database::table('messages');
        $pdo = Database::connection();
        $created = true;
        if (trim((string)$clientMessageId) === '') {
            $stmt = $pdo->prepare(
                "INSERT INTO {$messages} (sender_id, receiver_id, body, reply_to_message_id)
                 VALUES (?, ?, ?, ?)"
            );
            $stmt->execute([$senderId, $receiverId, trim($body), $replyToMessageId]);
        } else {
            $stmt = $pdo->prepare(
                "INSERT INTO {$messages}
                   (sender_id, receiver_id, body, client_message_id, reply_to_message_id)
                 VALUES (?, ?, ?, ?, ?)
                 ON DUPLICATE KEY UPDATE id = LAST_INSERT_ID(id)"
            );
            $stmt->execute([
                $senderId,
                $receiverId,
                trim($body),
                trim((string)$clientMessageId),
                $replyToMessageId,
            ]);
            $created = $stmt->rowCount() === 1;
        }

        $messageId = (int)$pdo->lastInsertId();
        $message = self::findById($messageId);
        if (!$message) {
            throw new RuntimeException('Message could not be loaded.');
        }
        if ($created) {
            self::notifyReceiver($senderId, $receiverId, $messageId, trim($body));
            ws_broadcast('new_message', self::publicData($message), $receiverId);
            ws_broadcast('new_message', self::publicData($message), $senderId);
        }
        return $message;
    }

    public static function sendImage(
        int $senderId,
        int $receiverId,
        array $attachment,
        ?string $clientMessageId = null,
        ?int $replyToMessageId = null,
        string $body = ''
    ): array {
        self::validateReceiver($senderId, $receiverId);
        self::validateClientMessageId($clientMessageId);
        if (trim($body) !== '') {
            self::validateText($body);
        }
        $replyToMessageId = self::validateReply($senderId, $receiverId, $replyToMessageId);

        $messages = Database::table('messages');
        $attachments = Database::table('message_attachments');
        $pdo = Database::connection();
        $pdo->beginTransaction();
        try {
            $created = true;
            if (trim((string)$clientMessageId) === '') {
                $stmt = $pdo->prepare(
                    "INSERT INTO {$messages}
                       (sender_id, receiver_id, body, message_type, reply_to_message_id)
                     VALUES (?, ?, ?, 'image', ?)"
                );
                $stmt->execute([$senderId, $receiverId, trim($body), $replyToMessageId]);
            } else {
                $stmt = $pdo->prepare(
                    "INSERT INTO {$messages}
                       (sender_id, receiver_id, body, client_message_id, message_type, reply_to_message_id)
                     VALUES (?, ?, ?, ?, 'image', ?)
                     ON DUPLICATE KEY UPDATE id = LAST_INSERT_ID(id)"
                );
                $stmt->execute([
                    $senderId,
                    $receiverId,
                    trim($body),
                    trim((string)$clientMessageId),
                    $replyToMessageId,
                ]);
                $created = $stmt->rowCount() === 1;
            }

            $messageId = (int)$pdo->lastInsertId();
            if ($created) {
                $insert = $pdo->prepare(
                    "INSERT INTO {$attachments}
                       (message_id, type, storage_path, thumbnail_path, mime_type, width, height, size_bytes)
                     VALUES (?, 'image', ?, ?, ?, ?, ?, ?)"
                );
                $insert->execute([
                    $messageId,
                    $attachment['storage_path'],
                    $attachment['thumbnail_path'],
                    $attachment['mime_type'],
                    (int)$attachment['width'],
                    (int)$attachment['height'],
                    (int)$attachment['size_bytes'],
                ]);
            }
            $message = self::findById($messageId);
            $pdo->commit();
        } catch (Throwable $error) {
            if ($pdo->inTransaction()) {
                $pdo->rollBack();
            }
            throw $error;
        }

        if (!$message) {
            throw new RuntimeException('Message could not be loaded.');
        }
        if ($created) {
            self::notifyReceiver(
                $senderId,
                $receiverId,
                (int)$message['id'],
                trim($body) === '' ? '📷 Rasm' : trim($body)
            );
            ws_broadcast('new_message', self::publicData($message), $receiverId);
            ws_broadcast('new_message', self::publicData($message), $senderId);
        }
        return ['message' => $message, 'created' => $created];
    }

    public static function updateText(int $userId, int $messageId, string $body): array
    {
        self::validateText($body);
        $message = self::findById($messageId);
        if (!$message) {
            throw new RuntimeException('Message not found.');
        }
        if ((int)$message['sender_id'] !== $userId) {
            throw new DomainException('You can only edit your own message.');
        }
        if (($message['message_type'] ?? 'text') !== 'text') {
            throw new LogicException('This message cannot be edited.');
        }
        if (!empty($message['deleted_for_everyone_at'])) {
            throw new LogicException('Deleted message cannot be edited.');
        }

        $messages = Database::table('messages');
        $stmt = Database::connection()->prepare(
            "UPDATE {$messages} SET body = ?, edited_at = NOW() WHERE id = ?"
        );
        $stmt->execute([trim($body), $messageId]);
        $updated = self::findById($messageId);
        if ($updated) {
            ws_broadcast('message_updated', self::publicData($updated), (int)$updated['receiver_id']);
            ws_broadcast('message_updated', self::publicData($updated), (int)$updated['sender_id']);
        }
        return $updated;
    }

    public static function deleteForMe(int $userId, int $messageId): void
    {
        $message = self::findById($messageId);
        self::assertParticipant($userId, $message);
        $deletions = Database::table('message_user_deletions');
        $stmt = Database::connection()->prepare(
            "INSERT INTO {$deletions} (message_id, user_id)
             VALUES (?, ?) ON DUPLICATE KEY UPDATE deleted_at = deleted_at"
        );
        $stmt->execute([$messageId, $userId]);
    }

    public static function deleteForEveryone(int $userId, int $messageId): array
    {
        $message = self::findById($messageId);
        if (!$message) {
            throw new RuntimeException('Message not found.');
        }
        if ((int)$message['sender_id'] !== $userId) {
            throw new DomainException('You can only delete your own message for everyone.');
        }
        if (!in_array(($message['message_type'] ?? 'text'), ['text', 'image'], true)) {
            throw new LogicException('System and battle messages cannot be deleted.');
        }

        $messages = Database::table('messages');
        $stmt = Database::connection()->prepare(
            "UPDATE {$messages}
             SET body = '', deleted_for_everyone_at = COALESCE(deleted_for_everyone_at, NOW()),
                 deleted_for_everyone_by = COALESCE(deleted_for_everyone_by, ?)
             WHERE id = ?"
        );
        $stmt->execute([$userId, $messageId]);
        return self::findById($messageId);
    }

    public static function markDelivered(int $receiverId, int $senderId, int $upToMessageId): int
    {
        self::validateBatchUsers($receiverId, $senderId, $upToMessageId);
        $messages = Database::table('messages');
        $stmt = Database::connection()->prepare(
            "UPDATE {$messages}
             SET delivered_at = NOW()
             WHERE sender_id = ? AND receiver_id = ? AND id <= ?
               AND delivered_at IS NULL AND deleted_for_everyone_at IS NULL"
        );
        $stmt->execute([$senderId, $receiverId, $upToMessageId]);
        return $stmt->rowCount();
    }

    public static function markRead(int $receiverId, int $senderId, int $upToMessageId): int
    {
        self::validateBatchUsers($receiverId, $senderId, $upToMessageId);
        $messages = Database::table('messages');
        $stmt = Database::connection()->prepare(
            "UPDATE {$messages}
             SET delivered_at = COALESCE(delivered_at, NOW()), read_at = NOW()
             WHERE sender_id = ? AND receiver_id = ? AND id <= ?
               AND read_at IS NULL AND deleted_for_everyone_at IS NULL"
        );
        $stmt->execute([$senderId, $receiverId, $upToMessageId]);
        $count = $stmt->rowCount();
        if ($count > 0) {
            ws_broadcast('messages_read', [
                'sender_id' => $senderId,
                'receiver_id' => $receiverId,
                'up_to_message_id' => $upToMessageId
            ], $senderId); // Tell sender that receiver read it
        }
        return $count;
    }

    public static function broadcastFromAdmin(array $sender, string $body): array
    {
        if (($sender['role'] ?? '') !== 'admin') {
            throw new LogicException('Only admins can send broadcast messages.');
        }
        self::validateText($body);

        $pdo = Database::connection();
        $users = Database::table('users');
        $messages = Database::table('messages');
        $broadcastSender = User::findByUsername('admin') ?: $sender;
        if (($broadcastSender['role'] ?? '') !== 'admin') {
            $broadcastSender = $sender;
        }
        $senderId = (int)$broadcastSender['id'];

        $stmt = $pdo->prepare(
            "SELECT id FROM {$users}
             WHERE id <> ? AND role <> 'admin'
             ORDER BY id ASC"
        );
        $stmt->execute([$senderId]);
        $receivers = $stmt->fetchAll();

        $pdo->beginTransaction();
        try {
            $insert = $pdo->prepare(
                "INSERT INTO {$messages} (sender_id, receiver_id, body) VALUES (?, ?, ?)"
            );
            foreach ($receivers as $receiver) {
                $insert->execute([$senderId, (int)$receiver['id'], trim($body)]);
            }
            $pdo->commit();
        } catch (Throwable $error) {
            if ($pdo->inTransaction()) {
                $pdo->rollBack();
            }
            throw $error;
        }

        foreach ($receivers as $receiver) {
            AppNotification::create(
                (int)$receiver['id'],
                'admin_message',
                '@admin',
                self::notificationPreview($body),
                ['sender_id' => $senderId, 'sender_name' => '@admin']
            );
        }

        return [
            'sent_count' => count($receivers),
            'sender' => User::publicProfile($broadcastSender),
        ];
    }

    public static function publicData(array $message, ?int $viewerId = null): array
    {
        $type = (string)($message['message_type'] ?? 'text');
        $deletedAt = $message['deleted_for_everyone_at'] ?? null;
        $deleted = trim((string)$deletedAt) !== '';
        $metadata = json_decode((string)($message['metadata_json'] ?? ''), true);
        if (!is_array($metadata)) {
            $metadata = [];
        }
        if ($type === 'battle_invite' && $viewerId !== null) {
            $invite = Battle::inviteForMessage((int)$message['id'], $viewerId);
            if ($invite !== null) {
                $metadata['invite'] = $invite;
            }
        }

        $replyTo = null;
        $replyId = (int)($message['reply_to_message_id'] ?? 0);
        if ($replyId > 0 && $viewerId !== null) {
            $replyTo = self::replyPreview($replyId, $viewerId);
        }

        return [
            'id' => (int)$message['id'],
            'sender_id' => (int)$message['sender_id'],
            'receiver_id' => (int)$message['receiver_id'],
            'client_message_id' => $message['client_message_id'] ?? null,
            'body' => $deleted ? '' : (string)($message['body'] ?? ''),
            'type' => $type,
            'metadata' => (object)$metadata,
            'delivered_at' => api_iso_datetime($message['delivered_at'] ?? null),
            'read_at' => api_iso_datetime($message['read_at'] ?? null),
            'edited_at' => api_iso_datetime($message['edited_at'] ?? null),
            'deleted_for_everyone_at' => api_iso_datetime($deletedAt),
            'deleted_for_everyone_by' => isset($message['deleted_for_everyone_by'])
                ? (int)$message['deleted_for_everyone_by']
                : null,
            'reply_to_message_id' => $replyId > 0 ? $replyId : null,
            'reply_to' => $replyTo,
            'attachment' => $deleted || $type !== 'image'
                ? null
                : self::attachmentFor((int)$message['id']),
            'created_at' => api_iso_datetime($message['created_at'] ?? null),
            'updated_at' => api_iso_datetime($message['updated_at'] ?? ($message['created_at'] ?? null)),
        ];
    }

    private static function findById(int $id): ?array
    {
        if ($id <= 0) {
            return null;
        }
        $messages = Database::table('messages');
        $stmt = Database::connection()->prepare("SELECT * FROM {$messages} WHERE id = ? LIMIT 1");
        $stmt->execute([$id]);
        $message = $stmt->fetch();
        return $message ?: null;
    }

    private static function lastBetween(int $userId, int $otherUserId): ?array
    {
        $messages = Database::table('messages');
        $deletions = Database::table('message_user_deletions');
        $stmt = Database::connection()->prepare(
            "SELECT m.* FROM {$messages} m
             WHERE ((m.sender_id = ? AND m.receiver_id = ?)
                OR (m.sender_id = ? AND m.receiver_id = ?))
               AND NOT EXISTS (
                 SELECT 1 FROM {$deletions} d
                 WHERE d.message_id = m.id AND d.user_id = ?
               )
             ORDER BY m.id DESC LIMIT 1"
        );
        $stmt->execute([$userId, $otherUserId, $otherUserId, $userId, $userId]);
        $message = $stmt->fetch();
        return $message ?: null;
    }

    private static function unreadCount(int $userId, int $otherUserId): int
    {
        $messages = Database::table('messages');
        $deletions = Database::table('message_user_deletions');
        $stmt = Database::connection()->prepare(
            "SELECT COUNT(*) FROM {$messages} m
             WHERE m.sender_id = ? AND m.receiver_id = ? AND m.read_at IS NULL
               AND m.deleted_for_everyone_at IS NULL
               AND NOT EXISTS (
                 SELECT 1 FROM {$deletions} d
                 WHERE d.message_id = m.id AND d.user_id = ?
               )"
        );
        $stmt->execute([$otherUserId, $userId, $userId]);
        return (int)$stmt->fetchColumn();
    }

    private static function replyPreview(int $messageId, int $viewerId): array
    {
        $message = self::findById($messageId);
        if (!$message || self::isHiddenFor($messageId, $viewerId)) {
            return ['id' => $messageId, 'deleted' => true];
        }
        self::assertParticipant($viewerId, $message);
        $deleted = !empty($message['deleted_for_everyone_at']);
        $sender = User::findById((int)$message['sender_id']);
        $type = (string)($message['message_type'] ?? 'text');
        return [
            'id' => (int)$message['id'],
            'sender_id' => (int)$message['sender_id'],
            'sender_name' => $sender ? (string)$sender['name'] : '',
            'type' => $type,
            'body' => $deleted ? '' : self::shortText((string)($message['body'] ?? ''), 160),
            'deleted' => $deleted,
            'attachment' => $deleted || $type !== 'image'
                ? null
                : self::attachmentFor((int)$message['id']),
        ];
    }

    private static function attachmentFor(int $messageId): ?array
    {
        $attachments = Database::table('message_attachments');
        $stmt = Database::connection()->prepare(
            "SELECT * FROM {$attachments} WHERE message_id = ? ORDER BY id ASC LIMIT 1"
        );
        $stmt->execute([$messageId]);
        $attachment = $stmt->fetch();
        if (!$attachment) {
            return null;
        }
        return [
            'id' => (int)$attachment['id'],
            'type' => (string)$attachment['type'],
            'url' => self::publicUrl((string)$attachment['storage_path']),
            'thumbnail_url' => self::publicUrl((string)$attachment['thumbnail_path']),
            'mime_type' => (string)$attachment['mime_type'],
            'width' => (int)$attachment['width'],
            'height' => (int)$attachment['height'],
            'size_bytes' => (int)$attachment['size_bytes'],
        ];
    }

    private static function validateReceiver(int $senderId, int $receiverId): void
    {
        if ($senderId === $receiverId) {
            throw new LogicException('You cannot message yourself.');
        }
        if ($receiverId <= 0 || !User::findById($receiverId)) {
            throw new RuntimeException('User not found.');
        }
    }

    private static function validateText(string $body): void
    {
        $body = trim($body);
        $length = function_exists('mb_strlen') ? mb_strlen($body, 'UTF-8') : strlen($body);
        if ($body === '') {
            throw new InvalidArgumentException('Message cannot be empty.');
        }
        if ($length > 1000) {
            throw new InvalidArgumentException('Message is too long.');
        }
    }

    private static function validateClientMessageId(?string $clientMessageId): void
    {
        $clientMessageId = trim((string)$clientMessageId);
        if ($clientMessageId !== '' && !preg_match('/^[A-Za-z0-9_-]{12,64}$/', $clientMessageId)) {
            throw new InvalidArgumentException('Invalid client_message_id.');
        }
    }

    private static function validateReply(int $senderId, int $receiverId, ?int $replyId): ?int
    {
        $replyId = (int)$replyId;
        if ($replyId <= 0) {
            return null;
        }
        $reply = self::findById($replyId);
        if (!$reply) {
            throw new RuntimeException('Reply message not found.');
        }
        $participants = [(int)$reply['sender_id'], (int)$reply['receiver_id']];
        sort($participants);
        $expected = [$senderId, $receiverId];
        sort($expected);
        if ($participants !== $expected) {
            throw new DomainException('Reply message belongs to another chat.');
        }
        if (!empty($reply['deleted_for_everyone_at'])) {
            throw new LogicException('Deleted message cannot be replied to.');
        }
        return $replyId;
    }

    private static function validateBatchUsers(int $receiverId, int $senderId, int $upToMessageId): void
    {
        if ($senderId <= 0 || $upToMessageId <= 0 || $receiverId === $senderId) {
            throw new InvalidArgumentException('Invalid delivery batch.');
        }
        if (!User::findById($senderId)) {
            throw new RuntimeException('User not found.');
        }
    }

    private static function assertParticipant(int $userId, ?array $message): void
    {
        if (!$message) {
            throw new RuntimeException('Message not found.');
        }
        if ((int)$message['sender_id'] !== $userId && (int)$message['receiver_id'] !== $userId) {
            throw new DomainException('Message belongs to another chat.');
        }
    }

    private static function isHiddenFor(int $messageId, int $viewerId): bool
    {
        $deletions = Database::table('message_user_deletions');
        $stmt = Database::connection()->prepare(
            "SELECT 1 FROM {$deletions} WHERE message_id = ? AND user_id = ? LIMIT 1"
        );
        $stmt->execute([$messageId, $viewerId]);
        return (bool)$stmt->fetchColumn();
    }

    private static function normalizeSyncTime(?string $value): ?string
    {
        $value = trim((string)$value);
        if ($value === '') {
            return null;
        }
        try {
            return (new DateTimeImmutable($value))
                ->setTimezone(new DateTimeZone(date_default_timezone_get()))
                ->format('Y-m-d H:i:s');
        } catch (Throwable $error) {
            throw new InvalidArgumentException('Invalid updated_since value.');
        }
    }

    private static function notifyReceiver(
        int $senderId,
        int $receiverId,
        int $messageId,
        string $preview
    ): void {
        $sender = User::findById($senderId);
        try {
            AppNotification::create(
                $receiverId,
                'message',
                $sender ? (string)$sender['name'] : 'WordRise',
                self::notificationPreview($preview),
                [
                    'message_id' => $messageId,
                    'sender_id' => $senderId,
                    'sender_name' => $sender ? (string)$sender['name'] : '',
                ]
            );
        } catch (Throwable $error) {
            error_log('[WordRise message notification] ' . $error->getMessage());
        }
    }

    private static function notificationPreview(string $body): string
    {
        return self::shortText(trim(preg_replace('/\s+/u', ' ', $body) ?: $body), 140);
    }

    private static function shortText(string $text, int $length): string
    {
        if (function_exists('mb_substr')) {
            return mb_substr($text, 0, $length, 'UTF-8');
        }
        return substr($text, 0, $length);
    }

    private static function publicUrl(string $path): string
    {
        if (preg_match('#^https?://#i', $path)) {
            return $path;
        }
        $forwardedProto = trim(explode(',', (string)($_SERVER['HTTP_X_FORWARDED_PROTO'] ?? ''))[0]);
        $scheme = $forwardedProto !== ''
            ? $forwardedProto
            : ((!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') ? 'https' : 'http');
        $host = $_SERVER['HTTP_HOST'] ?? 'localhost';
        $scriptName = $_SERVER['SCRIPT_NAME'] ?? '';
        $basePath = rtrim((string)preg_replace('#/api/.*$#', '', $scriptName), '/');
        return $scheme . '://' . $host . $basePath . '/' . ltrim($path, '/');
    }
}
