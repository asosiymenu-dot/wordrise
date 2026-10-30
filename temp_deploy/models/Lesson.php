<?php

require_once __DIR__ . '/../config/database.php';

final class Lesson
{
    public static function allForUser(array $user): array
    {
        $lessonsTable = Database::table('lessons');
        $usersTable = Database::table('users');
        $wordsTable = Database::table('words');

        if ($user['role'] === 'admin') {
            $stmt = Database::connection()->query(
                "SELECT l.*, u.name AS owner_name
                 FROM {$lessonsTable} l
                 INNER JOIN {$usersTable} u ON u.id = l.user_id
                 ORDER BY l.created_at DESC"
            );
            return $stmt->fetchAll();
        }

        $stmt = Database::connection()->prepare(
            "SELECT l.*, u.name AS owner_name,
                    (SELECT COUNT(*) FROM {$wordsTable} w WHERE w.lesson_id = l.id) AS word_count
             FROM {$lessonsTable} l
             INNER JOIN {$usersTable} u ON u.id = l.user_id
             WHERE l.user_id = ? OR u.role IN ('teacher', 'admin')
             ORDER BY l.created_at DESC"
        );
        $stmt->execute([(int)$user['id']]);
        return $stmt->fetchAll();
    }

    public static function findVisible(int $lessonId, array $user): ?array
    {
        $lessonsTable = Database::table('lessons');
        $usersTable = Database::table('users');
        $stmt = Database::connection()->prepare(
            "SELECT l.*, u.role AS owner_role
             FROM {$lessonsTable} l
             INNER JOIN {$usersTable} u ON u.id = l.user_id
             WHERE l.id = ?
             LIMIT 1"
        );
        $stmt->execute([$lessonId]);
        $lesson = $stmt->fetch();

        if (!$lesson) {
            return null;
        }

        if (
            (int)$lesson['user_id'] === (int)$user['id']
            || $user['role'] === 'admin'
            || (int)($lesson['is_public'] ?? 0) === 1
            || in_array($lesson['owner_role'], ['teacher', 'admin'], true)
        ) {
            return $lesson;
        }

        return null;
    }

    public static function create(
        int $userId,
        string $title,
        ?string $description,
        string $category,
        ?int $sourceLessonId = null
    ): array
    {
        $lessonsTable = Database::table('lessons');
        $stmt = Database::connection()->prepare(
            "INSERT INTO {$lessonsTable} (user_id, title, description, category, source_lesson_id) VALUES (?, ?, ?, ?, ?)"
        );
        $stmt->execute([$userId, $title, $description, $category, $sourceLessonId]);
        return self::findById((int)Database::connection()->lastInsertId());
    }

    public static function findImportedSource(int $userId, int $sourceLessonId): ?array
    {
        $lessonsTable = Database::table('lessons');
        $wordsTable = Database::table('words');
        $stmt = Database::connection()->prepare(
            "SELECT l.*,
                    (SELECT COUNT(*) FROM {$wordsTable} w WHERE w.lesson_id = l.id) AS word_count
             FROM {$lessonsTable} l
             WHERE l.user_id = ? AND l.source_lesson_id = ?
             LIMIT 1"
        );
        $stmt->execute([$userId, $sourceLessonId]);
        $lesson = $stmt->fetch();
        return $lesson ?: null;
    }

    public static function update(int $lessonId, array $user, string $title, ?string $description, string $category): array
    {
        $lesson = self::findVisible($lessonId, $user);
        if (!$lesson) {
            throw new RuntimeException('Lesson not found.');
        }
        if ((int)$lesson['user_id'] !== (int)$user['id'] && $user['role'] !== 'admin') {
            throw new LogicException('Forbidden.');
        }

        $lessonsTable = Database::table('lessons');
        $stmt = Database::connection()->prepare(
            "UPDATE {$lessonsTable} SET title = ?, description = ?, category = ?, updated_at = NOW() WHERE id = ?"
        );
        $stmt->execute([$title, $description, $category, $lessonId]);
        return self::findById($lessonId);
    }

    public static function delete(int $lessonId, array $user): void
    {
        $lesson = self::findVisible($lessonId, $user);
        if (!$lesson) {
            throw new RuntimeException('Lesson not found.');
        }
        if ((int)$lesson['user_id'] !== (int)$user['id'] && $user['role'] !== 'admin') {
            throw new LogicException('Forbidden.');
        }

        $lessonsTable = Database::table('lessons');
        $stmt = Database::connection()->prepare("DELETE FROM {$lessonsTable} WHERE id = ?");
        $stmt->execute([$lessonId]);
    }

    public static function findById(int $lessonId): ?array
    {
        $lessonsTable = Database::table('lessons');
        $wordsTable = Database::table('words');
        $stmt = Database::connection()->prepare(
            "SELECT l.*,
                    (SELECT COUNT(*) FROM {$wordsTable} w WHERE w.lesson_id = l.id) AS word_count
             FROM {$lessonsTable} l
             WHERE l.id = ?
             LIMIT 1"
        );
        $stmt->execute([$lessonId]);
        $lesson = $stmt->fetch();
        return $lesson ?: null;
    }

    public static function ensureShared(int $lessonId, array $user): array
    {
        $lesson = self::findVisible($lessonId, $user);
        if (!$lesson) {
            throw new RuntimeException('Lesson not found.');
        }
        if ((int)$lesson['user_id'] !== (int)$user['id'] && $user['role'] !== 'admin') {
            throw new LogicException('Forbidden.');
        }

        $code = trim((string)($lesson['share_code'] ?? ''));
        if ($code === '') {
            $code = self::generateShareCode();
        }

        $lessonsTable = Database::table('lessons');
        $stmt = Database::connection()->prepare(
            "UPDATE {$lessonsTable} SET share_code = ?, is_public = 1, updated_at = NOW() WHERE id = ?"
        );
        $stmt->execute([$code, $lessonId]);

        return self::findById($lessonId);
    }

    public static function togglePublic(int $lessonId, array $user, bool $isPublic): array
    {
        $lesson = self::findVisible($lessonId, $user);
        if (!$lesson) {
            throw new RuntimeException('Lesson not found.');
        }
        if ((int)$lesson['user_id'] !== (int)$user['id'] && $user['role'] !== 'admin') {
            throw new LogicException('Forbidden.');
        }

        $code = trim((string)($lesson['share_code'] ?? ''));
        if ($isPublic && $code === '') {
            $code = self::generateShareCode();
        }

        $lessonsTable = Database::table('lessons');
        $stmt = Database::connection()->prepare(
            "UPDATE {$lessonsTable} SET share_code = ?, is_public = ?, updated_at = NOW() WHERE id = ?"
        );
        $stmt->execute([$code === '' ? null : $code, $isPublic ? 1 : 0, $lessonId]);

        return self::findById($lessonId);
    }

    public static function findByShareCode(string $code): ?array
    {
        $lessonsTable = Database::table('lessons');
        $usersTable = Database::table('users');
        $wordsTable = Database::table('words');
        $stmt = Database::connection()->prepare(
            "SELECT l.*, u.name AS owner_name, u.avatar AS owner_avatar,
                    (SELECT COUNT(*) FROM {$wordsTable} w WHERE w.lesson_id = l.id) AS word_count
             FROM {$lessonsTable} l
             INNER JOIN {$usersTable} u ON u.id = l.user_id
             WHERE l.share_code = ? AND l.is_public = 1
             LIMIT 1"
        );
        $stmt->execute([trim($code)]);
        $lesson = $stmt->fetch();
        return $lesson ?: null;
    }

    public static function wordsForSharedLesson(int $lessonId): array
    {
        $wordsTable = Database::table('words');
        $stmt = Database::connection()->prepare(
            "SELECT id, english_word, uzbek_translation, example_sentence, pronunciation
             FROM {$wordsTable}
             WHERE lesson_id = ?
             ORDER BY id ASC"
        );
        $stmt->execute([$lessonId]);
        return $stmt->fetchAll();
    }

    public static function discover(array $filters): array
    {
        $lessonsTable = Database::table('lessons');
        $usersTable = Database::table('users');
        $wordsTable = Database::table('words');

        $page = max(1, (int)($filters['page'] ?? 1));
        $perPage = max(1, min((int)($filters['per_page'] ?? 20), 50));
        $offset = ($page - 1) * $perPage;
        $query = trim((string)($filters['q'] ?? ''));
        $category = trim((string)($filters['category'] ?? ''));
        $sort = (string)($filters['sort'] ?? 'popular');

        $where = ['l.is_public = 1'];
        $params = [];
        if ($query !== '') {
            $where[] = '(LOWER(l.title) LIKE ? OR LOWER(l.description) LIKE ? OR LOWER(l.category) LIKE ? OR LOWER(u.name) LIKE ?)';
            $needle = '%' . strtolower($query) . '%';
            array_push($params, $needle, $needle, $needle, $needle);
        }
        if ($category !== '') {
            $where[] = 'LOWER(l.category) = ?';
            $params[] = strtolower($category);
        }

        $orderBy = $sort === 'newest'
            ? 'l.created_at DESC, l.id DESC'
            : 'l.import_count DESC, l.created_at DESC, l.id DESC';

        $sql = "SELECT l.*, u.name AS owner_name, u.avatar AS owner_avatar,
                       (SELECT COUNT(*) FROM {$wordsTable} w WHERE w.lesson_id = l.id) AS word_count
                FROM {$lessonsTable} l
                INNER JOIN {$usersTable} u ON u.id = l.user_id
                WHERE " . implode(' AND ', $where) . "
                ORDER BY {$orderBy}
                LIMIT ? OFFSET ?";
        $stmt = Database::connection()->prepare($sql);
        $index = 1;
        foreach ($params as $param) {
            $stmt->bindValue($index++, $param);
        }
        $stmt->bindValue($index++, $perPage, PDO::PARAM_INT);
        $stmt->bindValue($index, $offset, PDO::PARAM_INT);
        $stmt->execute();
        $rows = $stmt->fetchAll();

        return [
            'lessons' => array_map([self::class, 'publicCard'], $rows),
            'page' => $page,
            'per_page' => $perPage,
            'has_more' => count($rows) === $perPage,
        ];
    }

    public static function incrementImportCount(int $lessonId): void
    {
        $lessonsTable = Database::table('lessons');
        $stmt = Database::connection()->prepare(
            "UPDATE {$lessonsTable} SET import_count = import_count + 1 WHERE id = ?"
        );
        $stmt->execute([$lessonId]);
    }

    public static function publicPreview(array $lesson, bool $includeWords = false): array
    {
        $data = [
            'id' => (int)$lesson['id'],
            'title' => $lesson['title'],
            'description' => $lesson['description'] ?? '',
            'category' => $lesson['category'] ?? 'General',
            'share_code' => $lesson['share_code'] ?? null,
            'word_count' => (int)($lesson['word_count'] ?? 0),
            'import_count' => (int)($lesson['import_count'] ?? 0),
            'author_name' => $lesson['owner_name'] ?? '',
            'author_avatar' => $lesson['owner_avatar'] ?? null,
        ];
        if ($includeWords) {
            $data['words'] = self::wordsForSharedLesson((int)$lesson['id']);
        }
        return $data;
    }

    public static function publicCard(array $lesson): array
    {
        return self::publicPreview($lesson, false);
    }

    private static function generateShareCode(): string
    {
        $alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789';
        $lessonsTable = Database::table('lessons');
        do {
            $code = '';
            for ($i = 0; $i < 8; $i++) {
                $code .= $alphabet[random_int(0, strlen($alphabet) - 1)];
            }
            $stmt = Database::connection()->prepare(
                "SELECT id FROM {$lessonsTable} WHERE share_code = ? LIMIT 1"
            );
            $stmt->execute([$code]);
        } while ($stmt->fetch());

        return $code;
    }
}
