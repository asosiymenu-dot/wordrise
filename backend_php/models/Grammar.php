<?php

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/User.php';
require_once __DIR__ . '/Badge.php';

final class Grammar
{
    public static function levels(array $user): array
    {
        $levelsTable = Database::table('grammar_levels');
        $topicsTable = Database::table('grammar_topics');
        $progressTable = Database::table('user_grammar_progress');
        $userId = (int)$user['id'];

        $stmt = Database::connection()->prepare(
            "SELECT gl.*,
                    COUNT(gt.id) AS topic_count,
                    SUM(CASE WHEN ugp.progress_percent >= 100 THEN 1 ELSE 0 END) AS completed_count,
                    AVG(COALESCE(ugp.progress_percent, 0)) AS progress_percent
             FROM {$levelsTable} gl
             LEFT JOIN {$topicsTable} gt ON gt.level_id = gl.id
             LEFT JOIN {$progressTable} ugp ON ugp.topic_id = gt.id AND ugp.user_id = ?
             GROUP BY gl.id
             ORDER BY gl.order_index ASC, gl.id ASC"
        );
        $stmt->execute([$userId]);
        return array_map([self::class, 'publicLevel'], $stmt->fetchAll());
    }

    public static function topics(string $levelCode, array $user): array
    {
        $levelsTable = Database::table('grammar_levels');
        $topicsTable = Database::table('grammar_topics');
        $lessonsTable = Database::table('grammar_lessons');
        $exercisesTable = Database::table('grammar_exercises');
        $progressTable = Database::table('user_grammar_progress');
        $userId = (int)$user['id'];

        $stmt = Database::connection()->prepare(
            "SELECT gt.*, gl.code AS level_code, gl.title_uz AS level_title,
                    COALESCE(ugp.progress_percent, 0) AS progress_percent,
                    ugp.completed_at,
                    ls.id AS lesson_id,
                    COALESCE(ls.title, gt.title) AS lesson_title,
                    (SELECT COUNT(*) FROM {$exercisesTable} ge WHERE ge.lesson_id = ls.id) AS exercise_count
             FROM {$topicsTable} gt
             INNER JOIN {$levelsTable} gl ON gl.id = gt.level_id
             LEFT JOIN {$progressTable} ugp ON ugp.topic_id = gt.id AND ugp.user_id = ?
             LEFT JOIN {$lessonsTable} ls ON ls.topic_id = gt.id AND ls.status = 'published'
             WHERE gl.code = ?
             ORDER BY gt.order_index ASC, gt.id ASC"
        );
        $stmt->execute([$userId, strtoupper(trim($levelCode))]);
        return array_map([self::class, 'publicTopic'], $stmt->fetchAll());
    }

    public static function all(?string $level = null): array
    {
        $lessonsTable = Database::table('grammar_lessons');
        $exercisesTable = Database::table('grammar_exercises');
        $topicsTable = Database::table('grammar_topics');
        $levelsTable = Database::table('grammar_levels');

        $sql =
            "SELECT gls.*, gt.id AS topic_id, gt.icon, lvl.code AS level_code,
                    (SELECT COUNT(*) FROM {$exercisesTable} ge WHERE ge.lesson_id = gls.id) AS exercise_count
             FROM {$lessonsTable} gls
             LEFT JOIN {$topicsTable} gt ON gt.id = gls.topic_id
             LEFT JOIN {$levelsTable} lvl ON lvl.id = gt.level_id
             WHERE gls.status = 'published'";
        $params = [];
        if ($level !== null && trim($level) !== '') {
            $sql .= " AND gls.level = ?";
            $params[] = strtoupper(trim($level));
        }
        $sql .= " ORDER BY gls.sort_order ASC, gls.id ASC";

        $stmt = Database::connection()->prepare($sql);
        $stmt->execute($params);
        return array_map([self::class, 'publicLesson'], $stmt->fetchAll());
    }

    public static function detail(int $lessonId = 0, int $topicId = 0): ?array
    {
        $lessonsTable = Database::table('grammar_lessons');
        $exercisesTable = Database::table('grammar_exercises');
        $topicsTable = Database::table('grammar_topics');
        $levelsTable = Database::table('grammar_levels');

        if ($topicId > 0) {
            $stmt = Database::connection()->prepare(
                "SELECT gls.*, gt.icon, gt.duration_minutes, lvl.code AS level_code, lvl.title_uz AS level_title
                 FROM {$lessonsTable} gls
                 LEFT JOIN {$topicsTable} gt ON gt.id = gls.topic_id
                 LEFT JOIN {$levelsTable} lvl ON lvl.id = gt.level_id
                 WHERE gls.topic_id = ? AND gls.status = 'published'
                 ORDER BY gls.id ASC
                 LIMIT 1"
            );
            $stmt->execute([$topicId]);
        } else {
            $stmt = Database::connection()->prepare(
                "SELECT gls.*, gt.icon, gt.duration_minutes, lvl.code AS level_code, lvl.title_uz AS level_title
                 FROM {$lessonsTable} gls
                 LEFT JOIN {$topicsTable} gt ON gt.id = gls.topic_id
                 LEFT JOIN {$levelsTable} lvl ON lvl.id = gt.level_id
                 WHERE gls.id = ? AND gls.status = 'published'
                 LIMIT 1"
            );
            $stmt->execute([$lessonId]);
        }
        $lesson = $stmt->fetch();
        if (!$lesson) {
            return null;
        }

        $exerciseStmt = Database::connection()->prepare(
            "SELECT * FROM {$exercisesTable} WHERE lesson_id = ? ORDER BY id ASC"
        );
        $exerciseStmt->execute([(int)$lesson['id']]);

        return [
            'lesson' => self::publicLesson($lesson),
            'exercises' => array_map([self::class, 'publicExercise'], $exerciseStmt->fetchAll()),
        ];
    }

    public static function nextTopic(array $user): ?array
    {
        $levelsTable = Database::table('grammar_levels');
        $topicsTable = Database::table('grammar_topics');
        $lessonsTable = Database::table('grammar_lessons');
        $progressTable = Database::table('user_grammar_progress');
        $level = strtoupper(trim((string)($user['english_level'] ?? 'A1')));

        $stmt = Database::connection()->prepare(
            "SELECT gt.*, gl.code AS level_code, gl.title_uz AS level_title,
                    COALESCE(ugp.progress_percent, 0) AS progress_percent,
                    ls.id AS lesson_id,
                    COALESCE(ls.title, gt.title) AS lesson_title
             FROM {$topicsTable} gt
             INNER JOIN {$levelsTable} gl ON gl.id = gt.level_id
             LEFT JOIN {$progressTable} ugp ON ugp.topic_id = gt.id AND ugp.user_id = ?
             LEFT JOIN {$lessonsTable} ls ON ls.topic_id = gt.id AND ls.status = 'published'
             WHERE gl.code = ? AND COALESCE(ugp.progress_percent, 0) < 100
             ORDER BY gt.order_index ASC, gt.id ASC
             LIMIT 1"
        );
        $stmt->execute([(int)$user['id'], $level]);
        $topic = $stmt->fetch();
        if (!$topic) {
            $stmt = Database::connection()->prepare(
                "SELECT gt.*, gl.code AS level_code, gl.title_uz AS level_title,
                        COALESCE(ugp.progress_percent, 0) AS progress_percent,
                        ls.id AS lesson_id,
                        COALESCE(ls.title, gt.title) AS lesson_title
                 FROM {$topicsTable} gt
                 INNER JOIN {$levelsTable} gl ON gl.id = gt.level_id
                 LEFT JOIN {$progressTable} ugp ON ugp.topic_id = gt.id AND ugp.user_id = ?
                 LEFT JOIN {$lessonsTable} ls ON ls.topic_id = gt.id AND ls.status = 'published'
                 WHERE COALESCE(ugp.progress_percent, 0) < 100
                 ORDER BY gl.order_index ASC, gt.order_index ASC
                 LIMIT 1"
            );
            $stmt->execute([(int)$user['id']]);
            $topic = $stmt->fetch();
        }
        return $topic ? self::publicTopic($topic) : null;
    }

    public static function submit(array $user, int $topicId, array $answers): array
    {
        $detail = self::detail(0, $topicId);
        if (!$detail) {
            throw new RuntimeException('Grammar topic not found.');
        }

        $exerciseMap = [];
        foreach ($detail['exercises'] as $exercise) {
            $exerciseMap[(int)$exercise['id']] = $exercise;
        }

        $correct = 0;
        $wrong = 0;
        $wrongIds = [];
        $answerResults = [];

        foreach ($answers as $answer) {
            if (!is_array($answer)) {
                continue;
            }
            $exerciseId = (int)($answer['exercise_id'] ?? 0);
            $given = trim((string)($answer['answer'] ?? ''));
            if (!isset($exerciseMap[$exerciseId])) {
                continue;
            }
            $exercise = $exerciseMap[$exerciseId];
            $isCorrect = self::isExerciseCorrect($exercise, $given);
            if ($isCorrect) {
                $correct++;
            } else {
                $wrong++;
                $wrongIds[] = $exerciseId;
            }
            $answerResults[] = [
                'exercise_id' => $exerciseId,
                'is_correct' => $isCorrect,
                'correct_answer' => $exercise['correct_answer'],
                'explanation' => $exercise['explanation'],
            ];
        }

        $total = max(1, count($exerciseMap));
        $progress = min(100, (int)round(($correct / $total) * 100));
        $xp = max(5, $correct * 8 + ($progress >= 80 ? 12 : 0));
        $completedAt = $progress >= 80 ? date('Y-m-d H:i:s') : null;

        $progressTable = Database::table('user_grammar_progress');
        $stmt = Database::connection()->prepare(
            "INSERT INTO {$progressTable}
                (user_id, topic_id, progress_percent, correct_count, wrong_count, wrong_exercise_ids, completed_at, last_attempt_at)
             VALUES (?, ?, ?, ?, ?, ?, ?, NOW())
             ON DUPLICATE KEY UPDATE
                progress_percent = GREATEST(progress_percent, VALUES(progress_percent)),
                correct_count = VALUES(correct_count),
                wrong_count = VALUES(wrong_count),
                wrong_exercise_ids = VALUES(wrong_exercise_ids),
                completed_at = IF(VALUES(completed_at) IS NULL, completed_at, VALUES(completed_at)),
                last_attempt_at = NOW()"
        );
        $stmt->execute([
            (int)$user['id'],
            $topicId,
            $progress,
            $correct,
            $wrong,
            json_encode(array_values(array_unique($wrongIds))),
            $completedAt,
        ]);

        $profile = User::updateStatsAfterQuiz((int)$user['id'], $xp, $correct, $wrong);
        Badge::award((int)$user['id'], 7);
        if (self::levelCompleted((int)$user['id'], (string)$detail['lesson']['level'])) {
            Badge::award((int)$user['id'], 8);
        }

        return [
            'correct_count' => $correct,
            'wrong_count' => $wrong,
            'earned_xp' => $xp,
            'progress_percent' => $progress,
            'answers' => $answerResults,
            'profile' => User::publicData($profile),
        ];
    }

    public static function reviewMistakes(array $user, int $limit = 20): array
    {
        $progressTable = Database::table('user_grammar_progress');
        $topicsTable = Database::table('grammar_topics');
        $levelsTable = Database::table('grammar_levels');
        $stmt = Database::connection()->prepare(
            "SELECT ugp.wrong_exercise_ids, gt.title AS topic_title, gl.code AS level_code
             FROM {$progressTable} ugp
             INNER JOIN {$topicsTable} gt ON gt.id = ugp.topic_id
             INNER JOIN {$levelsTable} gl ON gl.id = gt.level_id
             WHERE ugp.user_id = ? AND ugp.wrong_exercise_ids IS NOT NULL
             ORDER BY ugp.last_attempt_at DESC
             LIMIT 20"
        );
        $stmt->execute([(int)$user['id']]);

        $ids = [];
        $meta = [];
        foreach ($stmt->fetchAll() as $row) {
            $decoded = json_decode((string)$row['wrong_exercise_ids'], true);
            if (!is_array($decoded)) {
                continue;
            }
            foreach ($decoded as $id) {
                $id = (int)$id;
                if ($id > 0) {
                    $ids[] = $id;
                    $meta[$id] = ['topic_title' => $row['topic_title'], 'level_code' => $row['level_code']];
                }
            }
        }
        $ids = array_values(array_unique($ids));
        if (count($ids) === 0) {
            return [];
        }
        $ids = array_slice($ids, 0, $limit);
        $placeholders = implode(',', array_fill(0, count($ids), '?'));
        $exercisesTable = Database::table('grammar_exercises');
        $stmt = Database::connection()->prepare(
            "SELECT * FROM {$exercisesTable} WHERE id IN ({$placeholders})"
        );
        $stmt->execute($ids);

        $items = [];
        foreach ($stmt->fetchAll() as $exercise) {
            $public = self::publicExercise($exercise);
            $public['topic_title'] = $meta[(int)$exercise['id']]['topic_title'] ?? '';
            $public['level_code'] = $meta[(int)$exercise['id']]['level_code'] ?? '';
            $items[] = $public;
        }
        return $items;
    }

    public static function saveGenerated(array $user, array $data): array
    {
        if (!in_array($user['role'], ['admin', 'teacher'], true)) {
            throw new LogicException('Only admin or teacher can save grammar content.');
        }

        $levelCode = strtoupper(trim((string)($data['level'] ?? 'A1')));
        $topicTitle = trim((string)($data['topic'] ?? ($data['title'] ?? 'Grammar topic')));
        $lesson = is_array($data['lesson'] ?? null) ? $data['lesson'] : $data;
        $exercises = is_array($data['exercises'] ?? null) ? $data['exercises'] : [];

        $levelId = self::ensureLevel($levelCode);
        $topicId = self::ensureTopic($levelId, $topicTitle, (string)($data['icon'] ?? 'school'), (int)($data['duration_minutes'] ?? 10));

        $lessonsTable = Database::table('grammar_lessons');
        $stmt = Database::connection()->prepare(
            "INSERT INTO {$lessonsTable}
                (topic_id, title, level, content, examples_json, common_mistakes, status, sort_order)
             VALUES (?, ?, ?, ?, ?, ?, 'published', ?)
             ON DUPLICATE KEY UPDATE
                title = VALUES(title),
                content = VALUES(content),
                examples_json = VALUES(examples_json),
                common_mistakes = VALUES(common_mistakes),
                status = 'published'"
        );
        $stmt->execute([
            $topicId,
            trim((string)($lesson['title'] ?? $topicTitle)),
            $levelCode,
            trim((string)($lesson['explanation_uz'] ?? ($lesson['content'] ?? ''))),
            json_encode(is_array($lesson['examples'] ?? null) ? $lesson['examples'] : [], JSON_UNESCAPED_UNICODE),
            trim((string)($lesson['common_mistakes'] ?? '')),
            (int)($data['order_index'] ?? 999),
        ]);

        $lessonId = (int)Database::connection()->lastInsertId();
        if ($lessonId <= 0) {
            $stmt = Database::connection()->prepare("SELECT id FROM {$lessonsTable} WHERE topic_id = ? LIMIT 1");
            $stmt->execute([$topicId]);
            $lessonId = (int)($stmt->fetch()['id'] ?? 0);
        }

        self::replaceExercises($lessonId, $exercises);
        return self::detail($lessonId, 0);
    }

    private static function replaceExercises(int $lessonId, array $exercises): void
    {
        $exercisesTable = Database::table('grammar_exercises');
        $delete = Database::connection()->prepare("DELETE FROM {$exercisesTable} WHERE lesson_id = ?");
        $delete->execute([$lessonId]);

        $insert = Database::connection()->prepare(
            "INSERT INTO {$exercisesTable}
                (lesson_id, exercise_type, question, options, correct_answer, correct_answers, explanation)
             VALUES (?, ?, ?, ?, ?, ?, ?)"
        );
        foreach ($exercises as $exercise) {
            if (!is_array($exercise)) {
                continue;
            }
            $correct = $exercise['correct_answer'] ?? ($exercise['answer'] ?? '');
            $correctAnswers = is_array($exercise['correct_answers'] ?? null) ? $exercise['correct_answers'] : [$correct];
            $insert->execute([
                $lessonId,
                trim((string)($exercise['type'] ?? ($exercise['exercise_type'] ?? 'multiple_choice'))),
                trim((string)($exercise['question'] ?? '')),
                json_encode(is_array($exercise['options'] ?? null) ? $exercise['options'] : [], JSON_UNESCAPED_UNICODE),
                trim((string)$correct),
                json_encode($correctAnswers, JSON_UNESCAPED_UNICODE),
                trim((string)($exercise['explanation'] ?? '')),
            ]);
        }
    }

    private static function ensureLevel(string $code): int
    {
        $levelsTable = Database::table('grammar_levels');
        $stmt = Database::connection()->prepare("SELECT id FROM {$levelsTable} WHERE code = ? LIMIT 1");
        $stmt->execute([$code]);
        $row = $stmt->fetch();
        if ($row) {
            return (int)$row['id'];
        }
        $order = ['A1' => 10, 'A2' => 20, 'B1' => 30, 'B2' => 40, 'C1' => 50, 'C2' => 60];
        $insert = Database::connection()->prepare(
            "INSERT INTO {$levelsTable} (code, title_uz, order_index) VALUES (?, ?, ?)"
        );
        $insert->execute([$code, $code . ' daraja', $order[$code] ?? 999]);
        return (int)Database::connection()->lastInsertId();
    }

    private static function ensureTopic(int $levelId, string $title, string $icon, int $duration): int
    {
        $topicsTable = Database::table('grammar_topics');
        $stmt = Database::connection()->prepare("SELECT id FROM {$topicsTable} WHERE level_id = ? AND title = ? LIMIT 1");
        $stmt->execute([$levelId, $title]);
        $row = $stmt->fetch();
        if ($row) {
            return (int)$row['id'];
        }
        $orderStmt = Database::connection()->prepare("SELECT COALESCE(MAX(order_index), 0) + 10 AS next_order FROM {$topicsTable} WHERE level_id = ?");
        $orderStmt->execute([$levelId]);
        $order = (int)($orderStmt->fetch()['next_order'] ?? 999);
        $insert = Database::connection()->prepare(
            "INSERT INTO {$topicsTable} (level_id, title, order_index, icon, duration_minutes) VALUES (?, ?, ?, ?, ?)"
        );
        $insert->execute([$levelId, $title, $order, $icon, max(5, $duration)]);
        return (int)Database::connection()->lastInsertId();
    }

    private static function isExerciseCorrect(array $exercise, string $given): bool
    {
        $answers = is_array($exercise['correct_answers'] ?? null) && count($exercise['correct_answers']) > 0
            ? $exercise['correct_answers']
            : [$exercise['correct_answer']];
        $givenNormalized = self::normalizeAnswer($given);
        foreach ($answers as $answer) {
            if ($givenNormalized === self::normalizeAnswer((string)$answer)) {
                return true;
            }
        }
        return false;
    }

    private static function normalizeAnswer(string $value): string
    {
        return strtolower(trim(preg_replace('/\s+/', ' ', $value)));
    }

    private static function levelCompleted(int $userId, string $levelCode): bool
    {
        $levelsTable = Database::table('grammar_levels');
        $topicsTable = Database::table('grammar_topics');
        $progressTable = Database::table('user_grammar_progress');
        $stmt = Database::connection()->prepare(
            "SELECT COUNT(gt.id) AS total,
                    SUM(CASE WHEN COALESCE(ugp.progress_percent, 0) >= 100 THEN 1 ELSE 0 END) AS completed
             FROM {$topicsTable} gt
             INNER JOIN {$levelsTable} gl ON gl.id = gt.level_id
             LEFT JOIN {$progressTable} ugp ON ugp.topic_id = gt.id AND ugp.user_id = ?
             WHERE gl.code = ?"
        );
        $stmt->execute([$userId, $levelCode]);
        $row = $stmt->fetch() ?: [];
        return (int)($row['total'] ?? 0) > 0 && (int)$row['total'] === (int)($row['completed'] ?? 0);
    }

    private static function publicLevel(array $level): array
    {
        return [
            'id' => (int)$level['id'],
            'code' => $level['code'],
            'title_uz' => $level['title_uz'],
            'order_index' => (int)$level['order_index'],
            'topic_count' => (int)($level['topic_count'] ?? 0),
            'completed_count' => (int)($level['completed_count'] ?? 0),
            'progress_percent' => (int)round((float)($level['progress_percent'] ?? 0)),
        ];
    }

    private static function publicTopic(array $topic): array
    {
        $progress = (int)($topic['progress_percent'] ?? 0);
        return [
            'id' => (int)$topic['id'],
            'level_id' => (int)$topic['level_id'],
            'level_code' => $topic['level_code'] ?? '',
            'level_title' => $topic['level_title'] ?? '',
            'title' => $topic['title'],
            'lesson_title' => $topic['lesson_title'] ?? $topic['title'],
            'lesson_id' => (int)($topic['lesson_id'] ?? 0),
            'order_index' => (int)$topic['order_index'],
            'icon' => $topic['icon'] ?? 'school',
            'duration_minutes' => (int)($topic['duration_minutes'] ?? 8),
            'exercise_count' => (int)($topic['exercise_count'] ?? 0),
            'progress_percent' => $progress,
            'status' => $progress >= 100 ? 'completed' : ($progress > 0 ? 'in_progress' : 'not_started'),
        ];
    }

    private static function publicLesson(array $lesson): array
    {
        $examples = json_decode((string)($lesson['examples_json'] ?? '[]'), true);
        return [
            'id' => (int)$lesson['id'],
            'topic_id' => (int)($lesson['topic_id'] ?? 0),
            'title' => $lesson['title'],
            'level' => $lesson['level_code'] ?? $lesson['level'],
            'content' => $lesson['content'],
            'examples' => is_array($examples) ? array_values($examples) : [],
            'common_mistakes' => $lesson['common_mistakes'] ?? '',
            'exercise_count' => (int)($lesson['exercise_count'] ?? 0),
        ];
    }

    private static function publicExercise(array $exercise): array
    {
        $options = json_decode((string)($exercise['options'] ?? '[]'), true);
        $answers = json_decode((string)($exercise['correct_answers'] ?? '[]'), true);
        return [
            'id' => (int)$exercise['id'],
            'lesson_id' => (int)$exercise['lesson_id'],
            'exercise_type' => $exercise['exercise_type'] ?? 'multiple_choice',
            'question' => $exercise['question'],
            'options' => is_array($options) ? array_values($options) : [],
            'correct_answer' => $exercise['correct_answer'],
            'correct_answers' => is_array($answers) ? array_values($answers) : [],
            'explanation' => $exercise['explanation'] ?? '',
        ];
    }
}
