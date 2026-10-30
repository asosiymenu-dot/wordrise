<?php

require_once __DIR__ . '/../config/database.php';

function enforce_message_rate_limit(
    int $userId,
    string $scope,
    int $maxRequests,
    int $windowSeconds = 60
): void {
    if ($userId <= 0 || !preg_match('/^[a-z0-9_]{2,32}$/', $scope)) {
        throw new InvalidArgumentException('Invalid rate-limit scope.');
    }

    $maxRequests = max(1, $maxRequests);
    $windowSeconds = max(1, $windowSeconds);
    $table = Database::table('message_rate_limits');
    $pdo = Database::connection();
    $sql = "INSERT INTO {$table} (user_id, scope, attempts, window_started_at)
            VALUES (?, ?, 1, NOW())
            ON DUPLICATE KEY UPDATE
              attempts = IF(
                window_started_at <= DATE_SUB(NOW(), INTERVAL {$windowSeconds} SECOND),
                1,
                attempts + 1
              ),
              window_started_at = IF(
                window_started_at <= DATE_SUB(NOW(), INTERVAL {$windowSeconds} SECOND),
                NOW(),
                window_started_at
              )";
    $stmt = $pdo->prepare($sql);
    $stmt->execute([$userId, $scope]);

    $check = $pdo->prepare(
        "SELECT attempts FROM {$table} WHERE user_id = ? AND scope = ? LIMIT 1"
    );
    $check->execute([$userId, $scope]);
    if ((int)$check->fetchColumn() > $maxRequests) {
        throw new OverflowException('Juda ko‘p so‘rov yuborildi. Birozdan keyin qayta urinib ko‘ring.');
    }
}

