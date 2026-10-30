<?php

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/response.php';

function make_token(): string
{
    return bin2hex(random_bytes(32));
}

function token_hash(string $token): string
{
    return hash('sha256', $token);
}

function issue_token(int $userId): array
{
    $token = make_token();
    $hash = token_hash($token);
    $expiresAt = (new DateTimeImmutable('+30 days'))->format('Y-m-d H:i:s');
    $tokensTable = Database::table('api_tokens');
    $pdo = Database::connection();

    $pdo->exec("DELETE FROM {$tokensTable} WHERE expires_at <= NOW()");

    $stmt = $pdo->prepare(
        "INSERT INTO {$tokensTable} (user_id, token_hash, expires_at) VALUES (?, ?, ?)"
    );
    $stmt->execute([$userId, $hash, $expiresAt]);
    $prune = $pdo->prepare(
        "DELETE FROM {$tokensTable}
         WHERE user_id = ?
           AND id NOT IN (
             SELECT id FROM (
               SELECT id FROM {$tokensTable}
               WHERE user_id = ?
               ORDER BY created_at DESC, id DESC
               LIMIT 12
             ) recent_tokens
           )"
    );
    $prune->execute([$userId, $userId]);

    return [
        'token' => $token,
        'expires_at' => $expiresAt,
    ];
}

function enforce_login_rate_limit(string $identifier): void
{
    $table = Database::table('auth_rate_limits');
    $fingerprint = login_rate_fingerprint($identifier);
    $stmt = Database::connection()->prepare(
        "SELECT blocked_until FROM {$table}
         WHERE scope = 'login' AND fingerprint = ?
         LIMIT 1"
    );
    $stmt->execute([$fingerprint]);
    $blockedUntil = $stmt->fetchColumn();
    if (!$blockedUntil) {
        return;
    }
    $remaining = strtotime((string)$blockedUntil) - time();
    if ($remaining <= 0) {
        return;
    }
    header('Retry-After: ' . max(1, $remaining));
    error_response('Too many login attempts. Try again later.', 429);
}

function record_login_failure(
    string $identifier,
    int $maxAttempts = 8,
    int $windowSeconds = 900,
    int $blockSeconds = 900
): void {
    $maxAttempts = max(3, min($maxAttempts, 30));
    $windowSeconds = max(60, min($windowSeconds, 86400));
    $blockSeconds = max(60, min($blockSeconds, 86400));
    $table = Database::table('auth_rate_limits');
    $fingerprint = login_rate_fingerprint($identifier);
    $pdo = Database::connection();
    $pdo->beginTransaction();
    try {
        $select = $pdo->prepare(
            "SELECT attempts, window_started_at FROM {$table}
             WHERE scope = 'login' AND fingerprint = ?
             FOR UPDATE"
        );
        $select->execute([$fingerprint]);
        $row = $select->fetch();
        $now = new DateTimeImmutable();
        $windowExpired = !$row
            || strtotime((string)$row['window_started_at']) <= time() - $windowSeconds;
        $attempts = $windowExpired ? 1 : ((int)$row['attempts'] + 1);
        $windowStartedAt = $windowExpired
            ? $now->format('Y-m-d H:i:s')
            : (string)$row['window_started_at'];
        $blockedUntil = $attempts >= $maxAttempts
            ? $now->modify("+{$blockSeconds} seconds")->format('Y-m-d H:i:s')
            : null;

        $upsert = $pdo->prepare(
            "INSERT INTO {$table}
             (scope, fingerprint, attempts, window_started_at, blocked_until)
             VALUES ('login', ?, ?, ?, ?)
             ON DUPLICATE KEY UPDATE
               attempts = VALUES(attempts),
               window_started_at = VALUES(window_started_at),
               blocked_until = VALUES(blocked_until)"
        );
        $upsert->execute([
            $fingerprint,
            $attempts,
            $windowStartedAt,
            $blockedUntil,
        ]);
        $pdo->commit();
    } catch (Throwable $error) {
        if ($pdo->inTransaction()) {
            $pdo->rollBack();
        }
        throw $error;
    }
}

function clear_login_failures(string $identifier): void
{
    $table = Database::table('auth_rate_limits');
    $stmt = Database::connection()->prepare(
        "DELETE FROM {$table} WHERE scope = 'login' AND fingerprint = ?"
    );
    $stmt->execute([login_rate_fingerprint($identifier)]);
}

function login_rate_fingerprint(string $identifier): string
{
    $remoteAddress = trim((string)($_SERVER['REMOTE_ADDR'] ?? 'unknown'));
    return hash('sha256', $remoteAddress . '|' . strtolower(trim($identifier)));
}

function bearer_token(): ?string
{
    $header = $_SERVER['HTTP_AUTHORIZATION'] ?? $_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? '';
    if (!preg_match('/Bearer\s+(.+)/i', $header, $matches)) {
        return null;
    }
    return trim($matches[1]);
}

function revoke_current_token(): void
{
    $token = bearer_token();
    if ($token === null) {
        return;
    }

    $tokensTable = Database::table('api_tokens');
    $stmt = Database::connection()->prepare("DELETE FROM {$tokensTable} WHERE token_hash = ?");
    $stmt->execute([token_hash($token)]);
}
