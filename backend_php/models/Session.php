<?php

require_once __DIR__ . '/../config/database.php';

class Session
{
    public static function getActiveSessions(int $userId): array
    {
        $table = Database::table('api_tokens');
        $stmt = Database::connection()->prepare(
            "SELECT id, device_name, ip_address, last_active_at, is_online, expires_at, created_at 
             FROM {$table} 
             WHERE user_id = ? AND expires_at > NOW()
             ORDER BY last_active_at DESC, id DESC"
        );
        $stmt->execute([$userId]);
        $sessions = $stmt->fetchAll();
        
        foreach ($sessions as &$session) {
            $session['id'] = (int)$session['id'];
            $session['is_online'] = (bool)$session['is_online'];
        }
        return $sessions;
    }

    public static function revokeSession(int $userId, int $sessionId): bool
    {
        $table = Database::table('api_tokens');
        $stmt = Database::connection()->prepare(
            "DELETE FROM {$table} WHERE id = ? AND user_id = ?"
        );
        $stmt->execute([$sessionId, $userId]);
        return $stmt->rowCount() > 0;
    }

    public static function updateActivityByTokenHash(string $tokenHash, bool $isOnline): void
    {
        $table = Database::table('api_tokens');
        $stmt = Database::connection()->prepare(
            "UPDATE {$table} 
             SET last_active_at = NOW(), is_online = ? 
             WHERE token_hash = ?"
        );
        $stmt->execute([(int)$isOnline, $tokenHash]);
    }
}
