<?php

require_once __DIR__ . '/../config/database.php';

final class Badge
{
    public static function all(): array
    {
        $badgesTable = Database::table('badges');
        $stmt = Database::connection()->query("SELECT * FROM {$badgesTable} ORDER BY id");
        return $stmt->fetchAll();
    }

    public static function userBadges(int $userId): array
    {
        $badgesTable = Database::table('badges');
        $userBadgesTable = Database::table('user_badges');
        $stmt = Database::connection()->prepare(
            "SELECT b.*, ub.earned_at
             FROM {$userBadgesTable} ub
             INNER JOIN {$badgesTable} b ON b.id = ub.badge_id
             WHERE ub.user_id = ?
             ORDER BY ub.earned_at DESC"
        );
        $stmt->execute([$userId]);
        return $stmt->fetchAll();
    }

    public static function award(int $userId, int $badgeId): void
    {
        try {
            $badgesTable = Database::table('badges');
            $exists = Database::connection()->prepare("SELECT id FROM {$badgesTable} WHERE id = ? LIMIT 1");
            $exists->execute([$badgeId]);
            if (!$exists->fetch()) {
                return;
            }
            $userBadgesTable = Database::table('user_badges');
            $stmt = Database::connection()->prepare(
                "INSERT IGNORE INTO {$userBadgesTable} (user_id, badge_id) VALUES (?, ?)"
            );
            $stmt->execute([$userId, $badgeId]);
        } catch (Throwable $e) {
            error_log('[Badge award error] ' . $e->getMessage());
        }
    }

    public static function evaluateAfterQuiz(array $user, string $mode, int $correctCount, bool $perfectRound): void
    {
        try {
            if ((int)$user['streak'] >= 7) {
                self::award((int)$user['id'], 3);
            }
            if ($mode === 'speed_quiz' && $correctCount >= 10) {
                self::award((int)$user['id'], 4);
            }
            if ($perfectRound) {
                self::award((int)$user['id'], 5);
            }
            if ((int)$user['xp'] >= 500) {
                self::award((int)$user['id'], 1);
            }
        } catch (Throwable $e) {
            error_log('[Badge evaluate error] ' . $e->getMessage());
        }
    }
}
