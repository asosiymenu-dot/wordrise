<?php

require_once __DIR__ . '/../config/database.php';

final class UserWordProgress
{
    public static function recordAnswer(int $userId, int $wordId, bool $isCorrect, int $answerMs): array
    {
        $pdo = Database::connection();
        $table = Database::table('user_word_progress');
        $answerMs = max(0, min($answerMs, 120000));

        $insert = $pdo->prepare(
            "INSERT IGNORE INTO {$table} (user_id, word_id) VALUES (?, ?)"
        );
        $insert->execute([$userId, $wordId]);

        $stmt = $pdo->prepare(
            "SELECT * FROM {$table} WHERE user_id = ? AND word_id = ? FOR UPDATE"
        );
        $stmt->execute([$userId, $wordId]);
        $progress = $stmt->fetch();
        if (!$progress) {
            throw new RuntimeException('Word progress could not be created.');
        }

        $correctCount = (int)$progress['correct_count'];
        $wrongCount = (int)$progress['wrong_count'];
        $lapseCount = (int)$progress['lapse_count'];
        $consecutive = (int)$progress['consecutive_correct'];
        $reviewInterval = (int)$progress['review_interval'];
        $ease = max(1.30, min(3.20, (float)$progress['ease_factor']));
        $oldAverage = $progress['average_answer_ms'] === null ? null : (int)$progress['average_answer_ms'];
        $averageMs = $answerMs > 0
            ? ($oldAverage === null ? $answerMs : (int)round(($oldAverage * 0.70) + ($answerMs * 0.30)))
            : $oldAverage;

        if ($isCorrect) {
            $correctCount++;
            $consecutive++;
            $quality = $answerMs > 0 && $answerMs <= 4500
                ? 5
                : ($answerMs > 0 && $answerMs <= 9000 ? 4 : 3);
            if ($reviewInterval <= 0) {
                $nextInterval = 1;
            } elseif ($reviewInterval === 1) {
                $nextInterval = $quality >= 4 ? 3 : 2;
            } else {
                $recallFactor = $quality === 5 ? 1.08 : ($quality === 3 ? 0.72 : 1.0);
                $lapsePenalty = max(0.58, 1.0 - (min($lapseCount, 8) * 0.055));
                $nextInterval = max(
                    2,
                    (int)round($reviewInterval * $ease * $recallFactor * $lapsePenalty)
                );
            }
            $nextInterval = min($nextInterval, 365);
            $qualityGap = 5 - $quality;
            $ease += 0.10 - ($qualityGap * (0.08 + ($qualityGap * 0.02)));
            $ease = max(1.30, min(3.20, $ease));
            $status = $consecutive >= 5
                ? 'mastered'
                : ($consecutive >= 2 ? 'review' : 'learning');
            $nextReviewAt = (new DateTimeImmutable('+' . $nextInterval . ' days'))->format('Y-m-d H:i:s');
        } else {
            $wrongCount++;
            $lapseCount++;
            $consecutive = 0;
            $nextInterval = 0;
            $ease = max(1.30, $ease - min(0.34, 0.16 + ($lapseCount * 0.025)));
            $status = 'learning';
            $retryMinutes = $lapseCount === 1
                ? 10
                : ($lapseCount === 2 ? 5 : ($lapseCount === 3 ? 3 : 2));
            $nextReviewAt = (new DateTimeImmutable('+' . $retryMinutes . ' minutes'))->format('Y-m-d H:i:s');
        }

        $total = max(1, $correctCount + $wrongCount);
        $wrongRatio = $wrongCount / $total;
        $slowScore = $averageMs === null ? 0.0 : min(2.5, max(0.0, ($averageMs - 4500) / 4500));
        $difficulty = 0.60 + ($wrongRatio * 4.0) + (min($lapseCount, 10) * 0.22) + $slowScore;
        if ($status === 'mastered') {
            $difficulty *= 0.65;
        }
        $difficulty = max(0.50, min(9.99, $difficulty));

        $isLearned = $consecutive >= 5 ? 1 : 0;
        $isDifficult = $wrongCount > 0 ? 1 : 0;

        try {
            $update = $pdo->prepare(
                "UPDATE {$table}
                 SET status = ?, correct_count = ?, wrong_count = ?, lapse_count = ?,
                     consecutive_correct = ?, ease_factor = ?, review_interval = ?,
                     next_review_at = ?, last_answer_ms = ?, average_answer_ms = ?,
                     difficulty_score = ?,
                     last_reviewed_at = NOW(), updated_at = NOW()
                 WHERE id = ?"
            );
            $update->execute([
                $status,
                $correctCount,
                $wrongCount,
                $lapseCount,
                $consecutive,
                round($ease, 2),
                $nextInterval,
                $nextReviewAt,
                $answerMs > 0 ? $answerMs : null,
                $averageMs,
                round($difficulty, 2),
                (int)$progress['id'],
            ]);
        } catch (Throwable) {
            $fallback = $pdo->prepare(
                "UPDATE {$table}
                 SET status = ?, correct_count = ?, wrong_count = ?, lapse_count = ?,
                     consecutive_correct = ?, ease_factor = ?, review_interval = ?,
                     next_review_at = ?, last_reviewed_at = NOW(), updated_at = NOW()
                 WHERE id = ?"
            );
            $fallback->execute([
                $status,
                $correctCount,
                $wrongCount,
                $lapseCount,
                $consecutive,
                round($ease, 2),
                $nextInterval,
                $nextReviewAt,
                (int)$progress['id'],
            ]);
        }

        return self::find($userId, $wordId);
    }

    public static function find(int $userId, int $wordId): array
    {
        $table = Database::table('user_word_progress');
        $stmt = Database::connection()->prepare(
            "SELECT * FROM {$table} WHERE user_id = ? AND word_id = ? LIMIT 1"
        );
        $stmt->execute([$userId, $wordId]);
        $row = $stmt->fetch();
        return $row ? self::publicData($row) : self::emptyData($userId, $wordId);
    }

    public static function publicData(array $row): array
    {
        return [
            'user_id' => (int)($row['user_id'] ?? 0),
            'word_id' => (int)($row['word_id'] ?? 0),
            'status' => (string)($row['status'] ?? 'new'),
            'is_starred' => (int)($row['is_starred'] ?? 0) === 1,
            'correct_count' => (int)($row['correct_count'] ?? 0),
            'wrong_count' => (int)($row['wrong_count'] ?? 0),
            'lapse_count' => (int)($row['lapse_count'] ?? 0),
            'consecutive_correct' => (int)($row['consecutive_correct'] ?? 0),
            'ease_factor' => (float)($row['ease_factor'] ?? 2.50),
            'interval' => (int)($row['review_interval'] ?? 0),
            'next_review_at' => $row['next_review_at'] ?? null,
            'last_answer_ms' => ($row['last_answer_ms'] ?? null) === null ? null : (int)$row['last_answer_ms'],
            'average_answer_ms' => ($row['average_answer_ms'] ?? null) === null ? null : (int)$row['average_answer_ms'],
            'difficulty' => (float)($row['difficulty_score'] ?? 1.0),
            'last_reviewed_at' => $row['last_reviewed_at'] ?? null,
        ];
    }

    private static function emptyData(int $userId, int $wordId): array
    {
        return [
            'user_id' => $userId,
            'word_id' => $wordId,
            'status' => 'new',
            'is_starred' => false,
            'correct_count' => 0,
            'wrong_count' => 0,
            'lapse_count' => 0,
            'consecutive_correct' => 0,
            'ease_factor' => 2.5,
            'interval' => 0,
            'next_review_at' => null,
            'last_answer_ms' => null,
            'average_answer_ms' => null,
            'difficulty' => 1.0,
            'last_reviewed_at' => null,
        ];
    }

    public static function setStarred(int $userId, int $wordId, bool $isStarred): array
    {
        $table = Database::table('user_word_progress');
        $stmt = Database::connection()->prepare(
            "INSERT INTO {$table} (user_id, word_id, is_starred)
             VALUES (?, ?, ?)
             ON DUPLICATE KEY UPDATE is_starred = VALUES(is_starred), updated_at = NOW()"
        );
        $stmt->execute([$userId, $wordId, $isStarred ? 1 : 0]);
        return self::find($userId, $wordId);
    }

    public static function starredWords(int $userId): array
    {
        $progress = Database::table('user_word_progress');
        $words = Database::table('words');
        $lessons = Database::table('lessons');
        $stmt = Database::connection()->prepare(
            "SELECT w.*, l.title AS lesson_title, 1 AS is_starred,
                    p.status AS status, p.correct_count, p.wrong_count,
                    p.lapse_count, p.ease_factor, p.review_interval,
                    p.next_review_at,
                    p.average_answer_ms, p.difficulty_score
             FROM {$progress} p
             INNER JOIN {$words} w ON w.id = p.word_id
             INNER JOIN {$lessons} l ON l.id = w.lesson_id
             WHERE p.user_id = ? AND p.is_starred = 1
               AND l.user_id = ?
             ORDER BY p.difficulty_score DESC, p.updated_at DESC"
        );
        $stmt->execute([$userId, $userId]);
        return $stmt->fetchAll();
    }
}
