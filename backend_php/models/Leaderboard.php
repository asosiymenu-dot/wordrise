<?php

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../helpers/datetime.php';

final class Leaderboard
{
    public static function global(int $limit = 50): array
    {
        $usersTable = Database::table('users');
        $userBadgesTable = Database::table('user_badges');
        $badgesTable = Database::table('badges');
        $stmt = Database::connection()->prepare(
            "SELECT u.id, u.name, u.username, u.avatar, u.xp, u.level, u.streak, u.last_seen_at,
                    (
                        SELECT b.title
                        FROM {$userBadgesTable} ub
                        INNER JOIN {$badgesTable} b ON b.id = ub.badge_id
                        WHERE ub.user_id = u.id
                        ORDER BY ub.earned_at DESC, b.id DESC
                        LIMIT 1
                    ) AS badge_title,
                    (
                        SELECT b.icon
                        FROM {$userBadgesTable} ub
                        INNER JOIN {$badgesTable} b ON b.id = ub.badge_id
                        WHERE ub.user_id = u.id
                        ORDER BY ub.earned_at DESC, b.id DESC
                        LIMIT 1
                    ) AS badge_icon
             FROM {$usersTable} u
             ORDER BY xp DESC, streak DESC, id ASC
             LIMIT ?"
        );
        $stmt->bindValue(1, $limit, PDO::PARAM_INT);
        $stmt->execute();
        return self::withRanks($stmt->fetchAll(), 'xp');
    }

    public static function daily(int $limit = 50): array
    {
        $usersTable = Database::table('users');
        $resultsTable = Database::table('quiz_results');
        $userBadgesTable = Database::table('user_badges');
        $badgesTable = Database::table('badges');
        $stmt = Database::connection()->prepare(
            "SELECT u.id, u.name, u.username, u.avatar, u.level, u.streak, u.last_seen_at,
                    COALESCE(SUM(q.earned_xp), 0) AS xp,
                    (
                        SELECT b.title
                        FROM {$userBadgesTable} ub
                        INNER JOIN {$badgesTable} b ON b.id = ub.badge_id
                        WHERE ub.user_id = u.id
                        ORDER BY ub.earned_at DESC, b.id DESC
                        LIMIT 1
                    ) AS badge_title,
                    (
                        SELECT b.icon
                        FROM {$userBadgesTable} ub
                        INNER JOIN {$badgesTable} b ON b.id = ub.badge_id
                        WHERE ub.user_id = u.id
                        ORDER BY ub.earned_at DESC, b.id DESC
                        LIMIT 1
                    ) AS badge_icon
             FROM {$usersTable} u
             LEFT JOIN {$resultsTable} q ON q.user_id = u.id AND DATE(q.created_at) = CURDATE()
             GROUP BY u.id
             ORDER BY xp DESC, u.streak DESC, u.id ASC
             LIMIT ?"
        );
        $stmt->bindValue(1, $limit, PDO::PARAM_INT);
        $stmt->execute();
        return self::withRanks($stmt->fetchAll(), 'xp');
    }

    public static function weekly(int $limit = 50): array
    {
        $usersTable = Database::table('users');
        $resultsTable = Database::table('quiz_results');
        $userBadgesTable = Database::table('user_badges');
        $badgesTable = Database::table('badges');
        $stmt = Database::connection()->prepare(
            "SELECT u.id, u.name, u.username, u.avatar, u.level, u.streak, u.last_seen_at,
                    COALESCE(SUM(q.earned_xp), 0) AS xp,
                    (
                        SELECT b.title
                        FROM {$userBadgesTable} ub
                        INNER JOIN {$badgesTable} b ON b.id = ub.badge_id
                        WHERE ub.user_id = u.id
                        ORDER BY ub.earned_at DESC, b.id DESC
                        LIMIT 1
                    ) AS badge_title,
                    (
                        SELECT b.icon
                        FROM {$userBadgesTable} ub
                        INNER JOIN {$badgesTable} b ON b.id = ub.badge_id
                        WHERE ub.user_id = u.id
                        ORDER BY ub.earned_at DESC, b.id DESC
                        LIMIT 1
                    ) AS badge_icon
             FROM {$usersTable} u
             LEFT JOIN {$resultsTable} q
               ON q.user_id = u.id
              AND YEARWEEK(q.created_at, 1) = YEARWEEK(CURDATE(), 1)
             GROUP BY u.id
             ORDER BY xp DESC, u.streak DESC, u.id ASC
             LIMIT ?"
        );
        $stmt->bindValue(1, $limit, PDO::PARAM_INT);
        $stmt->execute();
        return self::withRanks($stmt->fetchAll(), 'xp');
    }

    public static function friends(int $userId, string $scope = 'global', int $limit = 50): array
    {
        if (!in_array($scope, ['global', 'daily', 'weekly'], true)) {
            $scope = 'global';
        }
        $usersTable = Database::table('users');
        $messagesTable = Database::table('messages');
        $resultsTable = Database::table('quiz_results');
        $userBadgesTable = Database::table('user_badges');
        $badgesTable = Database::table('badges');
        $xpSelect = 'u.xp';
        $resultJoin = '';
        if ($scope === 'daily') {
            $xpSelect = 'COALESCE(SUM(q.earned_xp), 0)';
            $resultJoin = "LEFT JOIN {$resultsTable} q ON q.user_id = u.id AND DATE(q.created_at) = CURDATE()";
        } elseif ($scope === 'weekly') {
            $xpSelect = 'COALESCE(SUM(q.earned_xp), 0)';
            $resultJoin = "LEFT JOIN {$resultsTable} q ON q.user_id = u.id
                           AND YEARWEEK(q.created_at, 1) = YEARWEEK(CURDATE(), 1)";
        }
        $stmt = Database::connection()->prepare(
            "SELECT u.id, u.name, u.username, u.avatar, u.level, u.streak, u.last_seen_at,
                    {$xpSelect} AS xp,
                    (
                        SELECT b.title FROM {$userBadgesTable} ub
                        INNER JOIN {$badgesTable} b ON b.id = ub.badge_id
                        WHERE ub.user_id = u.id
                        ORDER BY ub.earned_at DESC, b.id DESC LIMIT 1
                    ) AS badge_title,
                    (
                        SELECT b.icon FROM {$userBadgesTable} ub
                        INNER JOIN {$badgesTable} b ON b.id = ub.badge_id
                        WHERE ub.user_id = u.id
                        ORDER BY ub.earned_at DESC, b.id DESC LIMIT 1
                    ) AS badge_icon
             FROM {$usersTable} u
             INNER JOIN (
                 SELECT receiver_id AS friend_id FROM {$messagesTable} WHERE sender_id = ?
                 UNION
                 SELECT sender_id AS friend_id FROM {$messagesTable} WHERE receiver_id = ?
                 UNION
                 SELECT ? AS friend_id
             ) contacts ON contacts.friend_id = u.id
             {$resultJoin}
             GROUP BY u.id
             ORDER BY xp DESC, u.streak DESC, u.id ASC
             LIMIT ?"
        );
        $stmt->bindValue(1, $userId, PDO::PARAM_INT);
        $stmt->bindValue(2, $userId, PDO::PARAM_INT);
        $stmt->bindValue(3, $userId, PDO::PARAM_INT);
        $stmt->bindValue(4, $limit, PDO::PARAM_INT);
        $stmt->execute();
        return self::withRanks($stmt->fetchAll(), 'xp');
    }

    private static function withRanks(array $rows, string $xpKey): array
    {
        $rank = 1;
        return array_map(static function (array $row) use (&$rank, $xpKey): array {
            return [
                'rank' => $rank++,
                'id' => (int)$row['id'],
                'name' => $row['name'],
                'username' => $row['username'] ?? null,
                'avatar' => $row['avatar'],
                'xp' => (int)$row[$xpKey],
                'level' => (int)$row['level'],
                'streak' => (int)$row['streak'],
                'last_seen_at' => api_iso_datetime($row['last_seen_at'] ?? null),
                'is_online' => api_is_online($row['last_seen_at'] ?? null),
                'top_badge' => !empty($row['badge_title']) ? [
                    'title' => $row['badge_title'],
                    'icon' => $row['badge_icon'] ?? 'stars',
                ] : null,
            ];
        }, $rows);
    }
}
