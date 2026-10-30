<?php

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/Lesson.php';
require_once __DIR__ . '/User.php';
require_once __DIR__ . '/Badge.php';
require_once __DIR__ . '/UserWordProgress.php';

final class Quiz
{
    public static function generate(
        int $lessonId,
        string $mode,
        array $user,
        int $limit = 10,
        string $direction = 'eng_to_uz'
    ): array
    {
        $direction = self::sanitizeDirection($direction, $mode);
        if (!Lesson::findVisible($lessonId, $user)) {
            throw new RuntimeException('Lesson not found.');
        }

        $words = self::wordsForLesson($lessonId, (int)$user['id']);
        if (count($words) === 0) {
            throw new RuntimeException('No words in this lesson.');
        }
        if (in_array($mode, ['multiple_choice', 'reverse_quiz', 'true_false', 'speed_quiz'], true) && count($words) < 4) {
            throw new RuntimeException('This mode requires at least 4 words.');
        }

        shuffle($words);
        $selected = array_slice($words, 0, min($limit, count($words)));

        return array_map(static function (array $word) use ($words, $mode, $direction): array {
            return self::questionPayload($word, $words, $mode, $direction);
        }, $selected);
    }

    public static function generateReview(
        array $user,
        string $mode,
        int $limit = 10,
        string $direction = 'eng_to_uz'
    ): array
    {
        $direction = self::sanitizeDirection($direction, $mode);
        $words = self::wordsForReview($user);
        if (count($words) === 0) {
            throw new RuntimeException('No words available for review.');
        }
        if (in_array($mode, ['multiple_choice', 'reverse_quiz', 'true_false', 'speed_quiz'], true) && count($words) < 4) {
            throw new RuntimeException('Review mode requires at least 4 words.');
        }

        shuffle($words);
        $selected = array_slice($words, 0, min($limit, count($words)));

        return array_map(static function (array $word) use ($words, $mode, $direction): array {
            return self::questionPayload($word, $words, $mode, $direction);
        }, $selected);
    }

    public static function dueReviews(
        array $user,
        string $mode,
        int $limit = 20,
        string $direction = 'eng_to_uz'
    ): array
    {
        $direction = self::sanitizeDirection($direction, $mode);
        $words = self::wordsForDueReview($user);
        if (count($words) === 0) {
            return [];
        }
        if (in_array($mode, ['multiple_choice', 'reverse_quiz', 'true_false', 'speed_quiz'], true) && count($words) < 4) {
            $mode = 'typing_test';
        }

        $selected = array_slice($words, 0, min($limit, count($words)));
        return array_map(static function (array $word) use ($words, $mode, $direction): array {
            return self::questionPayload($word, $words, $mode, $direction);
        }, $selected);
    }

    public static function dueReviewCount(array $user): int
    {
        return count(self::wordsForDueReview($user, 500));
    }

    public static function generateMistakes(array $user, string $mode, string $direction = 'eng_to_uz', int $limit = 20): array
    {
        $direction = self::sanitizeDirection($direction, $mode);
        $progressTable = Database::table('user_word_progress');
        $wordsTable = Database::table('words');
        $stmt = Database::connection()->prepare(
            "SELECT w.*
             FROM {$progressTable} p
             INNER JOIN {$wordsTable} w ON w.id = p.word_id
             WHERE p.user_id = ? AND p.wrong_count > 0
             ORDER BY p.wrong_count DESC, p.last_reviewed_at DESC
             LIMIT 100"
        );
        $stmt->execute([(int)$user['id']]);
        $words = $stmt->fetchAll();
        if (!$words) {
            return [];
        }

        $safeMode = count($words) < 4 ? 'typing_test' : $mode;
        shuffle($words);
        $selected = array_slice($words, 0, min($limit, count($words)));

        return array_map(static function (array $word) use ($words, $safeMode, $direction): array {
            return self::questionPayload($word, $words, $safeMode, $direction);
        }, $selected);
    }

    public static function submit(
        int $lessonId,
        string $mode,
        array $answers,
        array $user,
        string $direction = 'eng_to_uz'
    ): array
    {
        $direction = self::sanitizeDirection($direction, $mode);
        if (!Lesson::findVisible($lessonId, $user)) {
            throw new RuntimeException('Lesson not found.');
        }
        if (count($answers) === 0) {
            throw new RuntimeException('Answers are required.');
        }

        $pdo = Database::connection();
        $pdo->beginTransaction();

        try {
            $correct = 0;
            $wrong = 0;
            $currentStreak = 0;
            $maxStreak = 0;
            $answerRows = [];

            foreach ($answers as $answer) {
                $wordId = (int)($answer['word_id'] ?? 0);
                $given = trim((string)($answer['answer'] ?? ''));
                $shownTranslation = trim((string)($answer['shown_translation'] ?? ''));
                $word = self::wordInLesson($lessonId, $wordId) ?: self::visibleWord($wordId, $user);

                if (!$word) {
                    continue;
                }

                $answerDirection = self::sanitizeDirection((string)($answer['direction'] ?? $direction), $mode);
                $isCorrect = self::isCorrect($word, $mode, $given, $shownTranslation, $answerDirection);
                if ($isCorrect) {
                    $correct++;
                    $currentStreak++;
                    $maxStreak = max($maxStreak, $currentStreak);
                } else {
                    $wrong++;
                    $currentStreak = 0;
                    self::recordMistake((int)$user['id'], $wordId);
                }
                self::updateReviewState(
                    (int)$user['id'],
                    $word,
                    $isCorrect,
                    (int)($answer['answer_ms'] ?? 0)
                );

                $answerRows[] = [
                    'word_id' => $wordId,
                    'given_answer' => $given,
                    'is_correct' => $isCorrect ? 1 : 0,
                ];
            }

            $earnedXp = self::calculateXp($mode, $correct, $maxStreak);

            $resultsTable = Database::table('quiz_results');
            $answersTable = Database::table('quiz_result_answers');
            $stmt = $pdo->prepare(
                "INSERT INTO {$resultsTable}
                 (user_id, lesson_id, mode, correct_count, wrong_count, earned_xp)
                 VALUES (?, ?, ?, ?, ?, ?)"
            );
            $stmt->execute([(int)$user['id'], $lessonId, $mode, $correct, $wrong, $earnedXp]);
            $resultId = (int)$pdo->lastInsertId();

            $answerStmt = $pdo->prepare(
                "INSERT INTO {$answersTable}
                 (quiz_result_id, word_id, given_answer, is_correct)
                 VALUES (?, ?, ?, ?)"
            );
            foreach ($answerRows as $row) {
                $answerStmt->execute([
                    $resultId,
                    $row['word_id'],
                    $row['given_answer'],
                    $row['is_correct'],
                ]);
            }

            $updatedUser = User::updateStatsAfterQuiz((int)$user['id'], $earnedXp, $correct, $wrong);
            Badge::evaluateAfterQuiz($updatedUser, $mode, $correct, $wrong === 0);

            $pdo->commit();

            return [
                'id' => $resultId,
                'lesson_id' => $lessonId,
                'mode' => $mode,
                'correct_count' => $correct,
                'wrong_count' => $wrong,
                'earned_xp' => $earnedXp,
                'max_correct_streak' => $maxStreak,
                'profile' => User::publicData($updatedUser),
            ];
        } catch (Throwable $error) {
            $pdo->rollBack();
            throw $error;
        }
    }

    public static function submitReview(
        string $mode,
        array $answers,
        array $user,
        string $direction = 'eng_to_uz'
    ): array
    {
        $direction = self::sanitizeDirection($direction, $mode);
        if (count($answers) === 0) {
            throw new RuntimeException('Answers are required.');
        }

        $pdo = Database::connection();
        $pdo->beginTransaction();

        try {
            $correct = 0;
            $wrong = 0;
            $currentStreak = 0;
            $maxStreak = 0;
            $lessonId = null;
            $answerRows = [];

            foreach ($answers as $answer) {
                $wordId = (int)($answer['word_id'] ?? 0);
                $given = trim((string)($answer['answer'] ?? ''));
                $shownTranslation = trim((string)($answer['shown_translation'] ?? ''));
                $word = self::visibleWord($wordId, $user);

                if (!$word) {
                    continue;
                }
                if ($lessonId === null) {
                    $lessonId = (int)$word['lesson_id'];
                }

                $answerDirection = self::sanitizeDirection((string)($answer['direction'] ?? $direction), $mode);
                $isCorrect = self::isCorrect($word, $mode, $given, $shownTranslation, $answerDirection);
                if ($isCorrect) {
                    $correct++;
                    $currentStreak++;
                    $maxStreak = max($maxStreak, $currentStreak);
                } else {
                    $wrong++;
                    $currentStreak = 0;
                    self::recordMistake((int)$user['id'], $wordId);
                }
                self::updateReviewState(
                    (int)$user['id'],
                    $word,
                    $isCorrect,
                    (int)($answer['answer_ms'] ?? 0)
                );

                $answerRows[] = [
                    'word_id' => $wordId,
                    'given_answer' => $given,
                    'is_correct' => $isCorrect ? 1 : 0,
                ];
            }

            if (count($answerRows) === 0) {
                throw new RuntimeException('No answers found.');
            }

            if ($lessonId === null || $lessonId <= 0) {
                $lessonStmt = $pdo->query("SELECT id FROM " . Database::table('lessons') . " LIMIT 1");
                $lessonId = (int)$lessonStmt->fetchColumn();
            }

            $earnedXp = self::calculateXp($mode, $correct, $maxStreak);

            $resultsTable = Database::table('quiz_results');
            $answersTable = Database::table('quiz_result_answers');
            $stmt = $pdo->prepare(
                "INSERT INTO {$resultsTable}
                 (user_id, lesson_id, mode, correct_count, wrong_count, earned_xp)
                 VALUES (?, ?, ?, ?, ?, ?)"
            );
            $stmt->execute([(int)$user['id'], $lessonId, $mode, $correct, $wrong, $earnedXp]);
            $resultId = (int)$pdo->lastInsertId();

            $answerStmt = $pdo->prepare(
                "INSERT INTO {$answersTable}
                 (quiz_result_id, word_id, given_answer, is_correct)
                 VALUES (?, ?, ?, ?)"
            );
            foreach ($answerRows as $row) {
                $answerStmt->execute([
                    $resultId,
                    $row['word_id'],
                    $row['given_answer'],
                    $row['is_correct'],
                ]);
            }

            $updatedUser = User::updateStatsAfterQuiz((int)$user['id'], $earnedXp, $correct, $wrong);
            Badge::evaluateAfterQuiz($updatedUser, $mode, $correct, $wrong === 0);

            $pdo->commit();

            return [
                'id' => $resultId,
                'lesson_id' => $lessonId,
                'mode' => $mode,
                'correct_count' => $correct,
                'wrong_count' => $wrong,
                'earned_xp' => $earnedXp,
                'max_correct_streak' => $maxStreak,
                'profile' => User::publicData($updatedUser),
            ];
        } catch (Throwable $error) {
            $pdo->rollBack();
            throw $error;
        }
    }

    public static function mistakes(array $user): array
    {
        $mistakesTable = Database::table('mistakes');
        $wordsTable = Database::table('words');
        $stmt = Database::connection()->prepare(
            "SELECT m.*, w.english_word, w.uzbek_translation, w.example_sentence, w.pronunciation
             FROM {$mistakesTable} m
             INNER JOIN {$wordsTable} w ON w.id = m.word_id
             WHERE m.user_id = ?
             ORDER BY m.mistake_count DESC, m.last_mistake_at DESC"
        );
        $stmt->execute([(int)$user['id']]);
        return $stmt->fetchAll();
    }

    private static function wordsForLesson(int $lessonId, int $userId): array
    {
        $wordsTable = Database::table('words');
        $progressTable = Database::table('user_word_progress');
        $stmt = Database::connection()->prepare(
            "SELECT w.* FROM {$wordsTable} w 
             LEFT JOIN {$progressTable} p ON p.word_id = w.id AND p.user_id = ?
             WHERE w.lesson_id = ? AND (p.status IS NULL OR p.status != 'mastered')"
        );
        $stmt->execute([$userId, $lessonId]);
        return $stmt->fetchAll();
    }

    private static function wordsForReview(array $user): array
    {
        $wordsTable = Database::table('words');
        $lessonsTable = Database::table('lessons');
        $usersTable = Database::table('users');
        $progressTable = Database::table('user_word_progress');

        $stmt = Database::connection()->prepare(
            "SELECT w.*
             FROM {$wordsTable} w
             INNER JOIN {$lessonsTable} l ON l.id = w.lesson_id
             INNER JOIN {$usersTable} u ON u.id = l.user_id
             LEFT JOIN {$progressTable} p ON p.word_id = w.id AND p.user_id = ?
             WHERE (l.user_id = ? OR u.role IN ('teacher', 'admin'))
               AND (p.status IS NULL OR p.status != 'mastered')
             ORDER BY w.id ASC"
        );
        $stmt->execute([(int)$user['id'], (int)$user['id']]);
        return $stmt->fetchAll();
    }

    private static function wordsForDueReview(array $user, int $limit = 100): array
    {
        $wordsTable = Database::table('words');
        $lessonsTable = Database::table('lessons');
        $usersTable = Database::table('users');
        $progressTable = Database::table('user_word_progress');
        $baseWhere = "(p.id IS NULL OR p.next_review_at IS NULL OR p.next_review_at <= NOW())";
        if ($user['role'] === 'admin') {
            $stmt = Database::connection()->prepare(
                "SELECT w.*, p.status AS progress_status, p.next_review_at AS progress_next_review_at
                 FROM {$wordsTable} w
                 INNER JOIN {$lessonsTable} l ON l.id = w.lesson_id
                 LEFT JOIN {$progressTable} p ON p.word_id = w.id AND p.user_id = ?
                 WHERE {$baseWhere}
                 ORDER BY COALESCE(p.next_review_at, '1970-01-01') ASC, w.created_at DESC
                 LIMIT ?"
            );
            $stmt->bindValue(1, (int)$user['id'], PDO::PARAM_INT);
            $stmt->bindValue(2, $limit, PDO::PARAM_INT);
            $stmt->execute();
            return $stmt->fetchAll();
        }

        $stmt = Database::connection()->prepare(
            "SELECT w.*, p.status AS progress_status, p.next_review_at AS progress_next_review_at
             FROM {$wordsTable} w
             INNER JOIN {$lessonsTable} l ON l.id = w.lesson_id
             INNER JOIN {$usersTable} u ON u.id = l.user_id
             LEFT JOIN {$progressTable} p ON p.word_id = w.id AND p.user_id = ?
             WHERE {$baseWhere}
               AND (l.user_id = ? OR u.role IN ('teacher', 'admin'))
             ORDER BY COALESCE(p.next_review_at, '1970-01-01') ASC, w.created_at DESC
             LIMIT ?"
        );
        $stmt->bindValue(1, (int)$user['id'], PDO::PARAM_INT);
        $stmt->bindValue(2, (int)$user['id'], PDO::PARAM_INT);
        $stmt->bindValue(3, $limit, PDO::PARAM_INT);
        $stmt->execute();
        return $stmt->fetchAll();
    }

    private static function wordInLesson(int $lessonId, int $wordId): ?array
    {
        $wordsTable = Database::table('words');
        $stmt = Database::connection()->prepare(
            "SELECT * FROM {$wordsTable} WHERE id = ? AND lesson_id = ? LIMIT 1"
        );
        $stmt->execute([$wordId, $lessonId]);
        $word = $stmt->fetch();
        return $word ?: null;
    }

    private static function visibleWord(int $wordId, array $user): ?array
    {
        $wordsTable = Database::table('words');
        $stmt = Database::connection()->prepare(
            "SELECT * FROM {$wordsTable} WHERE id = ? LIMIT 1"
        );
        $stmt->execute([$wordId]);
        $word = $stmt->fetch();
        if (!$word) {
            return null;
        }
        return $word;
    }

    private static function questionPayload(array $word, array $words, string $mode, string $direction): array
    {
        $direction = self::sanitizeDirection($direction, $mode);
        if ($direction === 'mixed') {
            $direction = random_int(0, 1) === 1 ? 'eng_to_uz' : 'uz_to_eng';
        }
        if ($mode === 'reverse_quiz') {
            $options = self::options($words, $word['id'], 'english_word', $word['english_word']);
            return [
                'word_id' => (int)$word['id'],
                'lesson_id' => (int)$word['lesson_id'],
                'mode' => $mode,
                'direction' => 'uz_to_eng',
                'prompt' => $word['uzbek_translation'],
                'correct_answer' => $word['english_word'],
                'shown_translation' => null,
                'speech_text' => $word['english_word'],
                'pronunciation' => (string)($word['pronunciation'] ?? ''),
                'options' => $options,
            ];
        }

        if ($mode === 'typing_test') {
            return [
                'word_id' => (int)$word['id'],
                'lesson_id' => (int)$word['lesson_id'],
                'mode' => $mode,
                'direction' => $direction,
                'prompt' => $direction === 'uz_to_eng' ? $word['uzbek_translation'] : $word['english_word'],
                'correct_answer' => $direction === 'uz_to_eng' ? $word['english_word'] : $word['uzbek_translation'],
                'shown_translation' => null,
                'speech_text' => $word['english_word'],
                'pronunciation' => (string)($word['pronunciation'] ?? ''),
                'options' => [],
            ];
        }

        if ($mode === 'true_false') {
            $others = array_values(array_filter($words, static function (array $item) use ($word): bool {
                return (int)$item['id'] !== (int)$word['id'];
            }));
            shuffle($others);
            $useCorrect = random_int(0, 1) === 1 || count($others) === 0;
            $shownField = $direction === 'uz_to_eng' ? 'english_word' : 'uzbek_translation';
            $promptField = $direction === 'uz_to_eng' ? 'uzbek_translation' : 'english_word';
            $shown = $useCorrect ? $word[$shownField] : $others[0][$shownField];
            return [
                'word_id' => (int)$word['id'],
                'lesson_id' => (int)$word['lesson_id'],
                'mode' => $mode,
                'direction' => $direction,
                'prompt' => $word[$promptField] . ' = ' . $shown,
                'correct_answer' => $useCorrect ? 'true' : 'false',
                'shown_translation' => $shown,
                'speech_text' => $word['english_word'],
                'pronunciation' => (string)($word['pronunciation'] ?? ''),
                'options' => ['true', 'false'],
            ];
        }

        if ($direction === 'uz_to_eng') {
            $options = self::options($words, $word['id'], 'english_word', $word['english_word']);
            return [
                'word_id' => (int)$word['id'],
                'lesson_id' => (int)$word['lesson_id'],
                'mode' => $mode,
                'direction' => 'uz_to_eng',
                'prompt' => $word['uzbek_translation'],
                'correct_answer' => $word['english_word'],
                'shown_translation' => null,
                'speech_text' => $word['english_word'],
                'pronunciation' => (string)($word['pronunciation'] ?? ''),
                'options' => $options,
            ];
        }

        $options = self::options($words, $word['id'], 'uzbek_translation', $word['uzbek_translation']);
        return [
            'word_id' => (int)$word['id'],
            'lesson_id' => (int)$word['lesson_id'],
            'mode' => $mode,
            'direction' => 'eng_to_uz',
            'prompt' => $word['english_word'],
            'correct_answer' => $word['uzbek_translation'],
            'shown_translation' => null,
            'speech_text' => $word['english_word'],
            'pronunciation' => (string)($word['pronunciation'] ?? ''),
            'options' => $options,
        ];
    }

    private static function options(array $words, int $correctId, string $field, string $correct): array
    {
        $wrong = [];
        $normalizedCorrect = strtolower(trim((string)$correct));
        foreach ($words as $word) {
            $candidate = (string)$word[$field];
            if ((int)$word['id'] !== $correctId && strtolower(trim($candidate)) !== $normalizedCorrect) {
                $wrong[] = $word[$field];
            }
        }
        $wrong = array_values(array_unique($wrong));
        shuffle($wrong);

        $options = array_merge([$correct], array_slice($wrong, 0, 3));
        shuffle($options);
        return $options;
    }

    private static function isCorrect(
        array $word,
        string $mode,
        string $given,
        string $shownTranslation,
        string $direction = 'eng_to_uz'
    ): bool
    {
        $direction = self::sanitizeDirection($direction, $mode);
        $normalize = static function (string $value): string {
            return strtolower(trim(preg_replace('/\s+/', ' ', $value)));
        };

        if ($mode === 'true_false') {
            $expected = $direction === 'uz_to_eng' ? $word['english_word'] : $word['uzbek_translation'];
            $actual = $normalize($shownTranslation) === $normalize($expected) ? 'true' : 'false';
            return $normalize($given) === $actual;
        }
        if ($mode === 'reverse_quiz' || $direction === 'uz_to_eng') {
            return $normalize($given) === $normalize($word['english_word']);
        }

        return $normalize($given) === $normalize($word['uzbek_translation']);
    }

    private static function sanitizeDirection(string $direction, string $mode): string
    {
        if ($mode === 'reverse_quiz') {
            return 'uz_to_eng';
        }
        if ($direction === 'mixed') {
            return 'mixed';
        }
        return $direction === 'uz_to_eng' ? 'uz_to_eng' : 'eng_to_uz';
    }

    private static function calculateXp(string $mode, int $correctCount, int $maxStreak): int
    {
        switch ($mode) {
            case 'typing_test':
                $base = 15;
                break;
            case 'match_mode':
                $base = 12;
                break;
            case 'speed_quiz':
                $base = 20;
                break;
            case 'reverse_quiz':
                $base = 10;
                break;
            default:
                $base = 10;
                break;
        }

        $xp = $correctCount * $base;
        if ($maxStreak >= 5) {
            $xp += 30;
        }
        return $xp;
    }

    private static function recordMistake(int $userId, int $wordId): void
    {
        try {
            $mistakesTable = Database::table('mistakes');
            $stmt = Database::connection()->prepare(
                "INSERT INTO {$mistakesTable} (user_id, word_id, mistake_count, last_mistake_at)
                 VALUES (?, ?, 1, NOW())
                 ON DUPLICATE KEY UPDATE mistake_count = mistake_count + 1, last_mistake_at = NOW()"
            );
            $stmt->execute([$userId, $wordId]);
        } catch (Throwable $e) {
            error_log('[recordMistake error] ' . $e->getMessage());
        }
    }

    private static function updateReviewState(int $userId, array $word, bool $isCorrect, int $answerMs): void
    {
        try {
            UserWordProgress::recordAnswer($userId, (int)$word['id'], $isCorrect, $answerMs);
        } catch (Throwable $e) {
            error_log('[updateReviewState error] ' . $e->getMessage());
        }
    }
}
