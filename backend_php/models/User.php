<?php

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../helpers/datetime.php';

final class User
{
    public static function publicData(array $user): array
    {
        return [
            'id' => (int)$user['id'],
            'name' => $user['name'],
            'username' => $user['username'] ?? null,
            'email' => $user['email'],
            'avatar' => $user['avatar'],
            'english_level' => $user['english_level'] ?? 'A1',
            'role' => $user['role'],
            'xp' => (int)$user['xp'],
            'level' => (int)$user['level'],
            'total_learned' => (int)($user['total_learned'] ?? 0),
            'progress_percent' => (float)($user['progress_percent'] ?? 0),
            'streak' => (int)$user['streak'],
            'streak_freezes' => (int)($user['streak_freezes'] ?? 0),
            'last_streak_freeze_at' => $user['last_streak_freeze_at'] ?? null,
            'last_active_date' => $user['last_active_date'],
            'last_seen_at' => api_iso_datetime($user['last_seen_at'] ?? null),
            'is_online' => api_is_online($user['last_seen_at'] ?? null),
            'created_at' => $user['created_at'],
        ];
    }

    public static function publicProfile(array $user): array
    {
        return [
            'id' => (int)$user['id'],
            'name' => $user['name'],
            'username' => $user['username'] ?? null,
            'avatar' => $user['avatar'] ?? null,
            'level' => (int)$user['level'],
            'streak' => (int)$user['streak'],
            'streak_freezes' => (int)($user['streak_freezes'] ?? 0),
            'last_seen_at' => api_iso_datetime($user['last_seen_at'] ?? null),
            'is_online' => api_is_online($user['last_seen_at'] ?? null),
        ];
    }

    public static function findByEmail(string $email): ?array
    {
        $usersTable = Database::table('users');
        $stmt = Database::connection()->prepare("SELECT * FROM {$usersTable} WHERE email = ? LIMIT 1");
        $stmt->execute([$email]);
        $user = $stmt->fetch();
        return $user ?: null;
    }

    public static function findByGoogleSub(string $googleSub): ?array
    {
        $usersTable = Database::table('users');
        $stmt = Database::connection()->prepare(
            "SELECT * FROM {$usersTable} WHERE google_sub = ? LIMIT 1"
        );
        $stmt->execute([$googleSub]);
        $user = $stmt->fetch();
        return $user ?: null;
    }

    public static function findByUsername(string $username): ?array
    {
        $usersTable = Database::table('users');
        $stmt = Database::connection()->prepare("SELECT * FROM {$usersTable} WHERE username = ? LIMIT 1");
        $stmt->execute([self::normalizeUsername($username)]);
        $user = $stmt->fetch();
        return $user ?: null;
    }

    public static function findByIdentifier(string $identifier): ?array
    {
        $identifier = trim($identifier);
        if (filter_var($identifier, FILTER_VALIDATE_EMAIL)) {
            return self::findByEmail(strtolower($identifier));
        }
        return self::findByUsername($identifier);
    }

    public static function findById(int $id): ?array
    {
        $usersTable = Database::table('users');
        $stmt = Database::connection()->prepare("SELECT * FROM {$usersTable} WHERE id = ? LIMIT 1");
        $stmt->execute([$id]);
        $user = $stmt->fetch();
        return $user ?: null;
    }

    public static function search(string $query, int $currentUserId, int $limit = 20): array
    {
        $usersTable = Database::table('users');
        $query = strtolower(trim($query));
        if (strpos($query, '@') === 0) {
            $query = substr($query, 1);
        }
        $needle = '%' . $query . '%';
        $stmt = Database::connection()->prepare(
            "SELECT id, name, username, avatar, level, streak, streak_freezes, last_seen_at
             FROM {$usersTable}
             WHERE id <> ?
               AND (LOWER(name) LIKE ? OR LOWER(username) LIKE ? OR LOWER(email) LIKE ?)
             ORDER BY xp DESC, name ASC
             LIMIT ?"
        );
        $stmt->bindValue(1, $currentUserId, PDO::PARAM_INT);
        $stmt->bindValue(2, $needle);
        $stmt->bindValue(3, $needle);
        $stmt->bindValue(4, $needle);
        $stmt->bindValue(5, $limit, PDO::PARAM_INT);
        $stmt->execute();

        return array_map([self::class, 'publicProfile'], $stmt->fetchAll());
    }

    public static function create(string $name, string $username, string $email, string $password, string $role): array
    {
        $allowedRoles = ['student', 'teacher'];
        if (!in_array($role, $allowedRoles, true)) {
            $role = 'student';
        }

        $usersTable = Database::table('users');
        $stmt = Database::connection()->prepare(
            "INSERT INTO {$usersTable} (name, username, email, password_hash, role) VALUES (?, ?, ?, ?, ?)"
        );
        $stmt->execute([
            $name,
            self::normalizeUsername($username),
            strtolower($email),
            password_hash($password, PASSWORD_DEFAULT),
            $role,
        ]);

        $user = self::findById((int)Database::connection()->lastInsertId());
        
        require_once __DIR__ . '/../helpers/websocket.php';
        ws_broadcast('user_registered', self::publicData($user));
        
        return $user;
    }

    public static function loginOrCreateGoogle(array $identity): array
    {
        $googleSub = trim((string)($identity['sub'] ?? ''));
        $email = strtolower(trim((string)($identity['email'] ?? '')));
        $name = trim((string)($identity['name'] ?? ''));
        $picture = isset($identity['picture']) ? trim((string)$identity['picture']) : null;
        $authoritativeEmail = ($identity['authoritative_email'] ?? false) === true;
        if ($googleSub === '' || strlen($googleSub) > 255
            || !filter_var($email, FILTER_VALIDATE_EMAIL)) {
            throw new InvalidArgumentException('Invalid Google account data.');
        }
        if ($name === '') {
            $name = strstr($email, '@', true) ?: 'WordRise User';
        }
        $name = self::limitText($name, 120);
        if ($picture !== null && (strlen($picture) > 500
            || !filter_var($picture, FILTER_VALIDATE_URL)
            || strtolower((string)parse_url($picture, PHP_URL_SCHEME)) !== 'https')) {
            $picture = null;
        }

        $pdo = Database::connection();
        $usersTable = Database::table('users');
        $ownsTransaction = !$pdo->inTransaction();
        if ($ownsTransaction) {
            $pdo->beginTransaction();
        }
        try {
            $bySub = $pdo->prepare(
                "SELECT * FROM {$usersTable} WHERE google_sub = ? LIMIT 1 FOR UPDATE"
            );
            $bySub->execute([$googleSub]);
            $user = $bySub->fetch();
            if ($user) {
                $verified = $pdo->prepare(
                    "UPDATE {$usersTable}
                     SET google_email_verified_at = COALESCE(google_email_verified_at, NOW()),
                         updated_at = NOW()
                     WHERE id = ?"
                );
                $verified->execute([(int)$user['id']]);
                $result = self::findById((int)$user['id']);
                if ($ownsTransaction) {
                    $pdo->commit();
                }
                return $result;
            }

            $byEmail = $pdo->prepare(
                "SELECT * FROM {$usersTable} WHERE email = ? LIMIT 1 FOR UPDATE"
            );
            $byEmail->execute([$email]);
            $user = $byEmail->fetch();
            if ($user) {
                $linkedSub = trim((string)($user['google_sub'] ?? ''));
                if ($linkedSub !== '' && !hash_equals($linkedSub, $googleSub)) {
                    throw new LogicException('This email is linked to another Google account.');
                }
                if (!$authoritativeEmail) {
                    throw new LogicException(
                        'This email is already registered. Sign in with your password first.'
                    );
                }
                $link = $pdo->prepare(
                    "UPDATE {$usersTable}
                     SET google_sub = ?, google_email_verified_at = NOW(),
                         avatar = COALESCE(NULLIF(avatar, ''), ?), updated_at = NOW()
                     WHERE id = ?"
                );
                $link->execute([$googleSub, $picture, (int)$user['id']]);
                $result = self::findById((int)$user['id']);
                if ($ownsTransaction) {
                    $pdo->commit();
                }
                return $result;
            }

            $username = self::googleUsername($email, $googleSub);
            $passwordHash = password_hash(bin2hex(random_bytes(32)), PASSWORD_DEFAULT);
            $create = $pdo->prepare(
                "INSERT INTO {$usersTable}
                 (name, username, email, password_hash, google_sub,
                  google_email_verified_at, avatar, role)
                 VALUES (?, ?, ?, ?, ?, NOW(), ?, 'student')"
            );
            $create->execute([
                $name,
                $username,
                $email,
                $passwordHash,
                $googleSub,
                $picture,
            ]);
            $user = self::findById((int)$pdo->lastInsertId());
        
            require_once __DIR__ . '/../helpers/websocket.php';
            ws_broadcast('user_registered', self::publicData($user));
        
            if ($ownsTransaction) {
                $pdo->commit();
            }
            return $user;
        } catch (Throwable $error) {
            if ($ownsTransaction && $pdo->inTransaction()) {
                $pdo->rollBack();
            }
            throw $error;
        }
    }

    private static function googleUsername(string $email, string $googleSub): string
    {
        $localPart = strstr($email, '@', true) ?: 'user';
        if (function_exists('iconv')) {
            $transliterated = @iconv('UTF-8', 'ASCII//TRANSLIT//IGNORE', $localPart);
            if (is_string($transliterated) && $transliterated !== '') {
                $localPart = $transliterated;
            }
        }
        $base = strtolower((string)preg_replace('/[^a-zA-Z0-9_.]+/', '_', $localPart));
        $base = trim($base, '._');
        if (strlen($base) < 3) {
            $base = 'user_' . $base;
        }
        $base = substr($base, 0, 30);
        if (!self::findByUsername($base)) {
            return $base;
        }

        $hash = hash('sha256', $googleSub);
        for ($offset = 0; $offset <= 48; $offset += 8) {
            $candidate = substr($base, 0, 21) . '_' . substr($hash, $offset, 8);
            if (!self::findByUsername($candidate)) {
                return $candidate;
            }
        }
        return substr($base, 0, 21) . '_' . bin2hex(random_bytes(4));
    }

    private static function limitText(string $value, int $length): string
    {
        if (function_exists('mb_substr')) {
            return mb_substr($value, 0, $length, 'UTF-8');
        }
        return substr($value, 0, $length);
    }

    public static function updateProfile(
        int $userId,
        string $name,
        string $username,
        string $email,
        ?string $avatar,
        ?string $password
    ): array {
        $usersTable = Database::table('users');
        $normalizedUsername = self::normalizeUsername($username);
        $normalizedEmail = strtolower($email);

        $stmt = Database::connection()->prepare(
            "SELECT id FROM {$usersTable}
             WHERE id <> ? AND (email = ? OR username = ?)
             LIMIT 1"
        );
        $stmt->execute([$userId, $normalizedEmail, $normalizedUsername]);
        if ($stmt->fetch()) {
            throw new LogicException('Email or username already exists.');
        }

        $params = [$name, $normalizedUsername, $normalizedEmail, $avatar, $userId];
        $passwordSql = '';
        if ($password !== null && trim($password) !== '') {
            $passwordSql = ', password_hash = ?';
            array_splice($params, 4, 0, [password_hash($password, PASSWORD_DEFAULT)]);
        }

        $stmt = Database::connection()->prepare(
            "UPDATE {$usersTable}
             SET name = ?, username = ?, email = ?, avatar = ?, updated_at = NOW() {$passwordSql}
             WHERE id = ?"
        );
        $stmt->execute($params);

        return self::findById($userId);
    }

    public static function updateAvatar(int $userId, string $avatar): array
    {
        $usersTable = Database::table('users');
        $stmt = Database::connection()->prepare(
            "UPDATE {$usersTable} SET avatar = ?, updated_at = NOW() WHERE id = ?"
        );
        $stmt->execute([$avatar, $userId]);
        return self::findById($userId);
    }

    public static function normalizeUsername(string $username): string
    {
        $username = strtolower(trim($username));
        if (strpos($username, '@') === 0) {
            $username = substr($username, 1);
        }
        return $username;
    }

    public static function isValidUsername(string $username): bool
    {
        return (bool)preg_match('/^[a-zA-Z0-9_\\.]{3,30}$/', trim($username));
    }

    public static function updateStatsAfterQuiz(int $userId, int $earnedXp, int $correctCount, int $wrongCount): array
    {
        $pdo = Database::connection();
        $ownsTransaction = !$pdo->inTransaction();
        if ($ownsTransaction) {
            $pdo->beginTransaction();
        }
        try {
            $usersTable = Database::table('users');
            $userStmt = $pdo->prepare("SELECT * FROM {$usersTable} WHERE id = ? LIMIT 1 FOR UPDATE");
            $userStmt->execute([$userId]);
            $user = $userStmt->fetch();
            if (!$user) {
                throw new RuntimeException('User not found.');
            }

            $today = (new DateTimeImmutable('today'))->format('Y-m-d');
            $lastActive = $user['last_active_date'];
            $streak = (int)$user['streak'];
            $freezes = (int)($user['streak_freezes'] ?? 0);
            $lastFreezeAt = $user['last_streak_freeze_at'] ?? null;

            if ($lastActive === $today) {
                $newStreak = $streak;
            } elseif ($lastActive === (new DateTimeImmutable('yesterday'))->format('Y-m-d')) {
                $newStreak = $streak + 1;
            } elseif (
                $lastActive === (new DateTimeImmutable('-2 days'))->format('Y-m-d')
                && $freezes > 0
            ) {
                $newStreak = $streak + 1;
                $freezes--;
                $lastFreezeAt = $today;
            } else {
                $newStreak = 1;
            }
            if ($lastActive !== $today && $newStreak > 0 && $newStreak % 7 === 0) {
                $freezes = min(2, $freezes + 1);
            }

            $newXp = (int)$user['xp'] + max(0, $earnedXp);
            $newLevel = intdiv($newXp, 500) + 1;

            $stmt = $pdo->prepare(
                "UPDATE {$usersTable}
                 SET xp = ?, level = ?, streak = ?, streak_freezes = ?,
                     last_active_date = ?, last_streak_freeze_at = ?, updated_at = NOW()
                 WHERE id = ?"
            );
            $stmt->execute([$newXp, $newLevel, $newStreak, $freezes, $today, $lastFreezeAt, $userId]);
            $updated = self::findById($userId);
            require_once __DIR__ . '/../helpers/websocket.php';
            ws_broadcast('user_updated', self::publicData($updated));

            if ($ownsTransaction) {
                $pdo->commit();
            }
            return $updated;
        } catch (Throwable $error) {
            if ($ownsTransaction && $pdo->inTransaction()) {
                $pdo->rollBack();
            }
            throw $error;
        }
    }

    public static function deleteAccount(int $userId): bool
    {
        $pdo = Database::connection();
        $ownsTransaction = !$pdo->inTransaction();
        if ($ownsTransaction) {
            $pdo->beginTransaction();
        }
        try {
            $tables = [
                'user_word_progress' => 'user_id',
                'quiz_attempts' => 'user_id',
                'user_badges' => 'user_id',
                'user_devices' => 'user_id',
                'user_notification_preferences' => 'user_id',
                'messages' => 'sender_id',
                'battles' => 'player1_id',
            ];
            foreach ($tables as $tbl => $col) {
                try {
                    $tableName = Database::table($tbl);
                    $stmt = $pdo->prepare("DELETE FROM {$tableName} WHERE {$col} = ?");
                    $stmt->execute([$userId]);
                } catch (Throwable $e) {
                    // Ignore table not found
                }
            }

            // Also delete lessons owned by user
            try {
                $lessonsTable = Database::table('lessons');
                $wordsTable = Database::table('words');
                $stmt = $pdo->prepare("DELETE FROM {$wordsTable} WHERE lesson_id IN (SELECT id FROM {$lessonsTable} WHERE user_id = ?)");
                $stmt->execute([$userId]);
                $stmt = $pdo->prepare("DELETE FROM {$lessonsTable} WHERE user_id = ?");
                $stmt->execute([$userId]);
            } catch (Throwable $e) {
                // Ignore
            }

            // Delete user record
            $usersTable = Database::table('users');
            $stmt = $pdo->prepare("DELETE FROM {$usersTable} WHERE id = ?");
            $stmt->execute([$userId]);

            if ($ownsTransaction) {
                $pdo->commit();
            }
            
            require_once __DIR__ . '/../helpers/websocket.php';
            ws_broadcast('user_deleted', ['user_id' => $userId]);
            
            return true;
        } catch (Throwable $error) {
            if ($ownsTransaction && $pdo->inTransaction()) {
                $pdo->rollBack();
            }
            throw $error;
        }
    }
}

