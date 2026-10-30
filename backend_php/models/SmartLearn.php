<?php

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/User.php';
require_once __DIR__ . '/UserWordProgress.php';

final class SmartLearn
{
    public static function dashboard(array $user): array
    {
        $userId = (int)$user['id'];
        $settings = self::settings($userId);
        $pool = self::wordPool($user);
        $stats = ['due' => 0, 'weak' => 0, 'new' => 0, 'mastered' => 0, 'starred' => 0, 'total' => count($pool)];
        foreach ($pool as $word) {
            $bucket = self::bucket($word);
            if ($bucket === 'new') {
                $stats['new']++;
            }
            if ($bucket === 'weak') {
                $stats['weak']++;
            }
            if (!empty($word['progress_id'])) {
                $nextReview = $word['progress_next_review_at'] ?? null;
                if ($nextReview === null || strtotime((string)$nextReview) <= time()) {
                    $stats['due']++;
                }
            }
            if (($word['progress_status'] ?? '') === 'mastered') {
                $stats['mastered']++;
            }
            if ((int)($word['is_starred'] ?? 0) === 1) {
                $stats['starred']++;
            }
        }

        $sessions = Database::table('smart_learn_sessions');
        $stmt = Database::connection()->prepare(
            "SELECT * FROM {$sessions}
             WHERE user_id = ? AND status = 'active'
             ORDER BY last_activity_at DESC LIMIT 1"
        );
        $stmt->execute([$userId]);
        $active = $stmt->fetch();

        $stmt = Database::connection()->prepare(
            "SELECT COALESCE(SUM(
                TIMESTAMPDIFF(SECOND, started_at, COALESCE(completed_at, last_activity_at))
             ), 0) AS seconds_today
             FROM {$sessions}
             WHERE user_id = ? AND DATE(started_at) = CURDATE()"
        );
        $stmt->execute([$userId]);
        $secondsToday = max(0, (int)($stmt->fetch()['seconds_today'] ?? 0));
        $todayMinutes = min(1440, (int)floor($secondsToday / 60));

        return [
            'daily_goal_minutes' => (int)$settings['daily_goal_minutes'],
            'preferred_direction' => $settings['preferred_direction'],
            'today_minutes' => $todayMinutes,
            'goal_completed' => $todayMinutes >= (int)$settings['daily_goal_minutes'],
            'due_count' => $stats['due'],
            'weak_count' => $stats['weak'],
            'new_count' => $stats['new'],
            'mastered_count' => $stats['mastered'],
            'starred_count' => $stats['starred'],
            'total_words' => $stats['total'],
            'suggested_count' => min(count($pool), (int)$settings['daily_goal_minutes'] * 2),
            'active_session' => $active ? self::sessionSummary($active) : null,
        ];
    }

    public static function updateSettings(int $userId, int $goalMinutes, string $direction): array
    {
        if (!in_array($goalMinutes, [5, 10, 15], true)) {
            throw new InvalidArgumentException('daily_goal_minutes must be 5, 10 or 15.');
        }
        $direction = self::sanitizeSessionDirection($direction);
        $table = Database::table('user_learning_settings');
        $stmt = Database::connection()->prepare(
            "INSERT INTO {$table} (user_id, daily_goal_minutes, preferred_direction)
             VALUES (?, ?, ?)
             ON DUPLICATE KEY UPDATE daily_goal_minutes = VALUES(daily_goal_minutes),
                 preferred_direction = VALUES(preferred_direction), updated_at = NOW()"
        );
        $stmt->execute([$userId, $goalMinutes, $direction]);
        return self::settings($userId);
    }

    public static function start(array $user, ?int $goalMinutes, ?string $direction, bool $resume = true): array
    {
        $pdo = Database::connection();
        $userId = (int)$user['id'];
        $settings = self::settings($userId);
        $goal = $goalMinutes === null ? (int)$settings['daily_goal_minutes'] : $goalMinutes;
        if (!in_array($goal, [5, 10, 15], true)) {
            throw new InvalidArgumentException('daily_goal_minutes must be 5, 10 or 15.');
        }
        $sessionDirection = self::sanitizeSessionDirection($direction === null ? $settings['preferred_direction'] : $direction);
        $sessions = Database::table('smart_learn_sessions');
        $items = Database::table('smart_learn_session_items');

        $pdo->beginTransaction();
        try {
            $stmt = $pdo->prepare(
                "SELECT * FROM {$sessions}
                 WHERE user_id = ? AND status = 'active'
                 ORDER BY last_activity_at DESC LIMIT 1 FOR UPDATE"
            );
            $stmt->execute([$userId]);
            $active = $stmt->fetch();
            if ($active && $resume) {
                $pdo->commit();
                return self::state($user, (int)$active['id']);
            }
            if ($active) {
                $abandon = $pdo->prepare(
                    "UPDATE {$sessions} SET status = 'abandoned', completed_at = NOW() WHERE id = ?"
                );
                $abandon->execute([(int)$active['id']]);
            }

            $pool = self::wordPool($user);
            if (count($pool) === 0) {
                throw new RuntimeException('Smart Learn uchun soʼz topilmadi. Avval darsga soʼz qoʼshing.');
            }
            $target = min(count($pool), $goal * 2);
            $selected = self::balancedSelection($pool, $target);

            $stmt = $pdo->prepare(
                "INSERT INTO {$sessions}
                 (user_id, daily_goal_minutes, direction, planned_count, started_at, last_activity_at)
                 VALUES (?, ?, ?, ?, NOW(), NOW())"
            );
            $stmt->execute([$userId, $goal, $sessionDirection, count($selected)]);
            $sessionId = (int)$pdo->lastInsertId();

            $insert = $pdo->prepare(
                "INSERT INTO {$items}
                 (session_id, word_id, position, source_bucket, direction, mode, attempt_no)
                 VALUES (?, ?, ?, ?, ?, ?, 1)"
            );
            foreach ($selected as $index => $word) {
                $itemDirection = self::itemDirection($sessionDirection, $index);
                $mode = (($index + 1) % 4 === 0 || ($word['progress_status'] ?? '') === 'mastered')
                    ? 'typing'
                    : 'choice';
                $insert->execute([
                    $sessionId,
                    (int)$word['id'],
                    ($index + 1) * 100,
                    self::bucket($word),
                    $itemDirection,
                    $mode,
                ]);
            }

            $pdo->commit();
            return self::state($user, $sessionId);
        } catch (Throwable $error) {
            if ($pdo->inTransaction()) {
                $pdo->rollBack();
            }
            throw $error;
        }
    }

    public static function state(array $user, int $sessionId): array
    {
        $session = self::sessionForUser((int)$user['id'], $sessionId);
        if (!$session) {
            throw new RuntimeException('Smart Learn session not found.');
        }
        $next = $session['status'] === 'active' ? self::nextItem($sessionId) : null;
        if ($session['status'] === 'active' && !$next) {
            self::finish($user, $sessionId);
            $session = self::sessionForUser((int)$user['id'], $sessionId);
        }

        return [
            'session' => self::sessionSummary($session),
            'question' => $next ? self::questionPayload($user, $next) : null,
            'profile' => $session['status'] === 'completed'
                ? User::publicData(User::findById((int)$user['id']))
                : null,
        ];
    }

    public static function answer(array $user, int $sessionId, int $itemId, string $givenAnswer, int $answerMs): array
    {
        $pdo = Database::connection();
        $items = Database::table('smart_learn_session_items');
        $sessions = Database::table('smart_learn_sessions');
        $words = Database::table('words');
        $answerMs = max(250, min($answerMs, 120000));

        $pdo->beginTransaction();
        try {
            $session = self::sessionForUser((int)$user['id'], $sessionId, true);
            if (!$session || $session['status'] !== 'active') {
                throw new RuntimeException('Smart Learn session is not active.');
            }
            $stmt = $pdo->prepare(
                "SELECT i.*, w.english_word, w.uzbek_translation, w.example_sentence, w.pronunciation
                 FROM {$items} i
                 INNER JOIN {$words} w ON w.id = i.word_id
                 WHERE i.id = ? AND i.session_id = ? LIMIT 1 FOR UPDATE"
            );
            $stmt->execute([$itemId, $sessionId]);
            $item = $stmt->fetch();
            if (!$item) {
                throw new RuntimeException('Smart Learn question not found.');
            }
            if ($item['status'] === 'answered') {
                $pdo->commit();
                return self::answerResponse($user, $sessionId, $item, true);
            }

            $next = self::nextItem($sessionId, true);
            if (!$next || (int)$next['id'] !== $itemId) {
                throw new LogicException('Questions must be answered in server order.');
            }

            $correctAnswer = $item['direction'] === 'uz_to_eng'
                ? (string)$item['english_word']
                : (string)$item['uzbek_translation'];
            $isCorrect = self::sameAnswer($givenAnswer, $correctAnswer);
            $update = $pdo->prepare(
                "UPDATE {$items}
                 SET status = 'answered', given_answer = ?, is_correct = ?, answer_ms = ?, answered_at = NOW()
                 WHERE id = ? AND status = 'pending'"
            );
            $update->execute([trim($givenAnswer), $isCorrect ? 1 : 0, $answerMs, $itemId]);
            if ($update->rowCount() !== 1) {
                throw new RuntimeException('Answer was already processed.');
            }

            UserWordProgress::recordAnswer(
                (int)$user['id'],
                (int)$item['word_id'],
                $isCorrect,
                $answerMs
            );

            $xp = $isCorrect ? ((int)$item['attempt_no'] === 1 ? 8 : 4) : 0;
            if ($isCorrect && $answerMs <= 5000) {
                $xp += 2;
            }
            $sessionUpdate = $pdo->prepare(
                "UPDATE {$sessions}
                 SET answered_count = answered_count + 1,
                     correct_count = correct_count + ?, wrong_count = wrong_count + ?,
                     earned_xp = earned_xp + ?, last_activity_at = NOW(), updated_at = NOW()
                 WHERE id = ?"
            );
            $sessionUpdate->execute([$isCorrect ? 1 : 0, $isCorrect ? 0 : 1, $xp, $sessionId]);

            if (!$isCorrect && (int)$item['attempt_no'] === 1) {
                self::scheduleRetries($sessionId, $item);
            }

            $freshItem = $item;
            $freshItem['status'] = 'answered';
            $freshItem['given_answer'] = trim($givenAnswer);
            $freshItem['is_correct'] = $isCorrect ? 1 : 0;
            $freshItem['answer_ms'] = $answerMs;
            $pdo->commit();

            $result = self::answerResponse($user, $sessionId, $freshItem, false);
            if ($result['session']['status'] === 'completed') {
                $result['profile'] = User::publicData(User::findById((int)$user['id']));
            }
            return $result;
        } catch (Throwable $error) {
            if ($pdo->inTransaction()) {
                $pdo->rollBack();
            }
            throw $error;
        }
    }

    public static function offlinePack(array $user, int $limit = 200): array
    {
        $pool = self::wordPool($user, max(20, min($limit, 500)));
        $selected = self::balancedSelection($pool, min(count($pool), max(20, min($limit, 200))));
        $words = array_map(static function (array $word): array {
            return [
                'id' => (int)$word['id'],
                'lesson_id' => (int)$word['lesson_id'],
                'lesson_title' => (string)($word['lesson_title'] ?? ''),
                'english_word' => (string)$word['english_word'],
                'uzbek_translation' => (string)$word['uzbek_translation'],
                'example_sentence' => (string)($word['example_sentence'] ?? ''),
                'pronunciation' => (string)($word['pronunciation'] ?? ''),
                'bucket' => SmartLearn::bucket($word),
                'is_starred' => (int)($word['is_starred'] ?? 0) === 1,
                'status' => (string)($word['progress_status'] ?? 'new'),
                'correct_count' => (int)($word['correct_count'] ?? 0),
                'wrong_count' => (int)($word['wrong_count'] ?? 0),
                'lapse_count' => (int)($word['lapse_count'] ?? 0),
                'consecutive_correct' => (int)($word['consecutive_correct'] ?? 0),
                'ease_factor' => (float)($word['progress_ease_factor'] ?? 2.5),
                'interval' => (int)($word['progress_interval'] ?? 0),
                'next_review_at' => $word['progress_next_review_at'] ?? null,
                'average_answer_ms' => empty($word['average_answer_ms']) ? null : (int)$word['average_answer_ms'],
                'difficulty' => (float)($word['difficulty_score'] ?? 1.0),
            ];
        }, $selected);
        $settings = self::settings((int)$user['id']);
        return [
            'generated_at' => (new DateTimeImmutable())->format(DateTime::ATOM),
            'daily_goal_minutes' => (int)$settings['daily_goal_minutes'],
            'preferred_direction' => (string)$settings['preferred_direction'],
            'words' => $words,
        ];
    }

    public static function syncOfflineAnswers(array $user, array $events): array
    {
        if (count($events) === 0 || count($events) > 100) {
            throw new InvalidArgumentException('Offline events count must be between 1 and 100.');
        }
        $visible = [];
        foreach (self::wordPool($user, 1500) as $word) {
            $visible[(int)$word['id']] = $word;
        }
        $pdo = Database::connection();
        $offlineEvents = Database::table('offline_review_events');
        $insert = $pdo->prepare(
            "INSERT IGNORE INTO {$offlineEvents}
             (user_id, word_id, client_event_id, given_answer, direction,
              answer_ms, is_correct, earned_xp, answered_at)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)"
        );
        $processed = 0;
        $skipped = 0;
        $earnedXp = 0;
        $pdo->beginTransaction();
        try {
            foreach ($events as $event) {
                if (!is_array($event)) {
                    $skipped++;
                    continue;
                }
                $eventId = trim((string)($event['client_event_id'] ?? ''));
                $wordId = (int)($event['word_id'] ?? 0);
                $given = trim((string)($event['answer'] ?? ''));
                $direction = trim((string)($event['direction'] ?? 'eng_to_uz'));
                if (!preg_match('/^[A-Za-z0-9_-]{8,64}$/', $eventId)
                    || !isset($visible[$wordId])
                    || $given === ''
                    || strlen($given) > 255
                    || !in_array($direction, ['eng_to_uz', 'uz_to_eng'], true)
                ) {
                    $skipped++;
                    continue;
                }
                $word = $visible[$wordId];
                $correctAnswer = $direction === 'uz_to_eng'
                    ? (string)$word['english_word']
                    : (string)$word['uzbek_translation'];
                $isCorrect = self::sameAnswer($given, $correctAnswer);
                $answerMs = max(250, min((int)($event['answer_ms'] ?? 0), 120000));
                $answeredAt = self::safeOfflineDate((string)($event['answered_at'] ?? ''));
                $xp = $isCorrect ? ($answerMs <= 5000 ? 5 : 4) : 0;
                $insert->execute([
                    (int)$user['id'],
                    $wordId,
                    $eventId,
                    $given,
                    $direction,
                    $answerMs,
                    $isCorrect ? 1 : 0,
                    $xp,
                    $answeredAt,
                ]);
                if ($insert->rowCount() !== 1) {
                    $skipped++;
                    continue;
                }
                UserWordProgress::recordAnswer((int)$user['id'], $wordId, $isCorrect, $answerMs);
                $earnedXp += $xp;
                $processed++;
            }
            $profile = $processed > 0
                ? User::updateStatsAfterQuiz((int)$user['id'], $earnedXp, 0, 0)
                : User::findById((int)$user['id']);
            $pdo->commit();
        } catch (Throwable $error) {
            if ($pdo->inTransaction()) {
                $pdo->rollBack();
            }
            throw $error;
        }
        return [
            'processed_count' => $processed,
            'skipped_count' => $skipped,
            'earned_xp' => $earnedXp,
            'profile' => $profile ? User::publicData($profile) : null,
        ];
    }

    private static function answerResponse(array $user, int $sessionId, array $item, bool $duplicate): array
    {
        $correctAnswer = $item['direction'] === 'uz_to_eng'
            ? (string)$item['english_word']
            : (string)$item['uzbek_translation'];
        $isCorrect = (int)$item['is_correct'] === 1;
        $state = self::state($user, $sessionId);
        $example = trim((string)($item['example_sentence'] ?? ''));
        $feedbackCode = $isCorrect
            ? (((int)($item['answer_ms'] ?? 0)) > 10000 ? 'correct_slow' : 'correct')
            : 'wrong';
        return array_merge($state, [
            'feedback' => [
                'is_correct' => $isCorrect,
                'correct_answer' => $correctAnswer,
                'given_answer' => (string)($item['given_answer'] ?? ''),
                'answer_ms' => (int)($item['answer_ms'] ?? 0),
                'code' => $feedbackCode,
                'explanation' => $isCorrect
                    ? 'Javob toʼgʼri. Keyingi interval natijaga qarab uzaytirildi.'
                    : 'Toʼgʼri javob: ' . $correctAnswer . ($example !== '' ? '. Misol: ' . $example : ''),
                'example_sentence' => $example,
                'duplicate' => $duplicate,
            ],
        ]);
    }

    private static function finish(array $user, int $sessionId): void
    {
        $pdo = Database::connection();
        $sessions = Database::table('smart_learn_sessions');
        $stmt = $pdo->prepare(
            "SELECT * FROM {$sessions} WHERE id = ? AND user_id = ? LIMIT 1"
        );
        $stmt->execute([$sessionId, (int)$user['id']]);
        $session = $stmt->fetch();
        if (!$session || $session['status'] !== 'active') {
            return;
        }
        $update = $pdo->prepare(
            "UPDATE {$sessions}
             SET status = 'completed', completed_at = NOW(), last_activity_at = NOW(), updated_at = NOW()
             WHERE id = ? AND status = 'active'"
        );
        $update->execute([$sessionId]);
        if ($update->rowCount() === 1) {
            User::updateStatsAfterQuiz(
                (int)$user['id'],
                (int)$session['earned_xp'],
                (int)$session['correct_count'],
                (int)$session['wrong_count']
            );
        }
    }

    private static function scheduleRetries(int $sessionId, array $item): void
    {
        $pdo = Database::connection();
        $items = Database::table('smart_learn_session_items');
        $sessions = Database::table('smart_learn_sessions');
        $check = $pdo->prepare(
            "SELECT COUNT(*) FROM {$items}
             WHERE session_id = ? AND word_id = ? AND source_bucket IN ('retry', 'final_retry')"
        );
        $check->execute([$sessionId, (int)$item['word_id']]);
        if ((int)$check->fetchColumn() > 0) {
            return;
        }

        $future = $pdo->prepare(
            "SELECT position FROM {$items}
             WHERE session_id = ? AND status = 'pending' AND position > ?
             ORDER BY position ASC, id ASC LIMIT 5"
        );
        $future->execute([$sessionId, (int)$item['position']]);
        $positions = array_map('intval', array_column($future->fetchAll(), 'position'));
        $distance = random_int(2, 4);
        if (count($positions) > $distance) {
            $shortPosition = max((int)$item['position'] + 1, $positions[$distance] - 1);
        } elseif (count($positions) === $distance) {
            $shortPosition = $positions[$distance - 1] + 1;
        } else {
            $shortPosition = (int)$item['position'] + ($distance * 100);
        }
        $maxStmt = $pdo->prepare("SELECT COALESCE(MAX(position), 0) FROM {$items} WHERE session_id = ?");
        $maxStmt->execute([$sessionId]);
        $finalPosition = max($shortPosition + 100, (int)$maxStmt->fetchColumn() + 1000);

        $insert = $pdo->prepare(
            "INSERT INTO {$items}
             (session_id, word_id, position, source_bucket, direction, mode, attempt_no)
             VALUES (?, ?, ?, ?, ?, ?, ?)"
        );
        $insert->execute([
            $sessionId,
            (int)$item['word_id'],
            $shortPosition,
            'retry',
            $item['direction'],
            'choice',
            2,
        ]);
        $insert->execute([
            $sessionId,
            (int)$item['word_id'],
            $finalPosition,
            'final_retry',
            $item['direction'],
            'typing',
            3,
        ]);
        $update = $pdo->prepare(
            "UPDATE {$sessions} SET planned_count = planned_count + 2, updated_at = NOW() WHERE id = ?"
        );
        $update->execute([$sessionId]);
    }

    private static function questionPayload(array $user, array $item): array
    {
        $direction = $item['direction'];
        $prompt = $direction === 'uz_to_eng' ? $item['uzbek_translation'] : $item['english_word'];
        $answer = $direction === 'uz_to_eng' ? $item['english_word'] : $item['uzbek_translation'];
        $mode = $item['mode'];
        $options = $mode === 'choice' ? self::options($user, $item, $answer) : [];
        if (count($options) < 4) {
            $mode = 'typing';
            $options = [];
        }
        return [
            'item_id' => (int)$item['id'],
            'word_id' => (int)$item['word_id'],
            'position' => (int)$item['position'],
            'source_bucket' => $item['source_bucket'],
            'attempt_no' => (int)$item['attempt_no'],
            'direction' => $direction,
            'mode' => $mode,
            'prompt' => $prompt,
            'options' => $options,
            'pronunciation' => (string)($item['pronunciation'] ?? ''),
            'example_sentence' => (string)($item['example_sentence'] ?? ''),
            'hint' => self::hint($answer),
        ];
    }

    private static function options(array $user, array $item, string $correct): array
    {
        $pool = self::wordPool($user, 300);
        $field = $item['direction'] === 'uz_to_eng' ? 'english_word' : 'uzbek_translation';
        $wrong = [];
        foreach ($pool as $word) {
            $candidate = trim((string)$word[$field]);
            if ((int)$word['id'] !== (int)$item['word_id'] && !self::sameAnswer($candidate, $correct)) {
                $wrong[self::normalize($candidate)] = $candidate;
            }
        }
        $wrong = array_values($wrong);
        shuffle($wrong);
        $options = array_merge([$correct], array_slice($wrong, 0, 3));
        shuffle($options);
        return $options;
    }

    private static function hint(string $answer): string
    {
        $answer = trim($answer);
        if ($answer === '') {
            return '';
        }
        $first = function_exists('mb_substr') ? mb_substr($answer, 0, 1, 'UTF-8') : substr($answer, 0, 1);
        $length = function_exists('mb_strlen') ? mb_strlen($answer, 'UTF-8') : strlen($answer);
        return $first . str_repeat(' •', max(0, min($length - 1, 14))) . ' (' . $length . ')';
    }

    private static function settings(int $userId): array
    {
        $table = Database::table('user_learning_settings');
        $insert = Database::connection()->prepare(
            "INSERT IGNORE INTO {$table} (user_id, daily_goal_minutes, preferred_direction) VALUES (?, 10, 'mixed')"
        );
        $insert->execute([$userId]);
        $stmt = Database::connection()->prepare("SELECT * FROM {$table} WHERE user_id = ? LIMIT 1");
        $stmt->execute([$userId]);
        return $stmt->fetch();
    }

    private static function wordPool(array $user, int $limit = 1500): array
    {
        $words = Database::table('words');
        $lessons = Database::table('lessons');
        $users = Database::table('users');
        $progress = Database::table('user_word_progress');
        $stmt = Database::connection()->prepare(
            "SELECT w.*, l.title AS lesson_title,
                    p.id AS progress_id, p.status AS progress_status, p.is_starred,
                    p.correct_count, p.wrong_count, p.lapse_count, p.consecutive_correct,
                    p.ease_factor AS progress_ease_factor, p.review_interval AS progress_interval,
                    p.next_review_at AS progress_next_review_at,
                    p.last_answer_ms, p.average_answer_ms, p.difficulty_score, p.last_reviewed_at
             FROM {$words} w
             INNER JOIN {$lessons} l ON l.id = w.lesson_id
             INNER JOIN {$users} owner ON owner.id = l.user_id
             LEFT JOIN {$progress} p ON p.word_id = w.id AND p.user_id = ?
             WHERE l.user_id = ? OR owner.role IN ('teacher', 'admin')
             ORDER BY w.created_at DESC
             LIMIT ?"
        );
        $stmt->bindValue(1, (int)$user['id'], PDO::PARAM_INT);
        $stmt->bindValue(2, (int)$user['id'], PDO::PARAM_INT);
        $stmt->bindValue(3, $limit, PDO::PARAM_INT);
        $stmt->execute();
        return $stmt->fetchAll();
    }

    private static function balancedSelection(array $pool, int $target): array
    {
        $buckets = ['due' => [], 'weak' => [], 'new' => [], 'mature' => []];
        foreach ($pool as $word) {
            $word['_priority'] = self::priority($word) + (random_int(0, 100) / 500.0);
            $buckets[self::bucket($word)][] = $word;
        }
        foreach ($buckets as &$bucket) {
            usort($bucket, static function (array $a, array $b): int {
                return $a['_priority'] === $b['_priority'] ? 0 : ($a['_priority'] < $b['_priority'] ? 1 : -1);
            });
        }
        unset($bucket);

        $quotas = [
            'due' => (int)ceil($target * 0.30),
            'weak' => (int)ceil($target * 0.35),
            'new' => (int)ceil($target * 0.25),
            'mature' => max(1, (int)floor($target * 0.10)),
        ];
        $selected = [];
        $seen = [];
        if ($target >= 4) {
            foreach (['weak', 'due', 'new', 'mature'] as $name) {
                if (count($buckets[$name]) === 0) {
                    continue;
                }
                $word = array_shift($buckets[$name]);
                $id = (int)$word['id'];
                $seen[$id] = true;
                $selected[] = $word;
            }
        }
        foreach (['due', 'weak', 'new', 'mature'] as $name) {
            $take = $quotas[$name];
            foreach ($buckets[$name] as $word) {
                if ($take <= 0 || count($selected) >= $target) {
                    break;
                }
                $id = (int)$word['id'];
                if (isset($seen[$id])) {
                    continue;
                }
                $seen[$id] = true;
                $selected[] = $word;
                $take--;
            }
        }
        if (count($selected) < $target) {
            $all = $pool;
            usort($all, static function (array $a, array $b): int {
                return SmartLearn::priority($a) < SmartLearn::priority($b) ? 1 : -1;
            });
            foreach ($all as $word) {
                $id = (int)$word['id'];
                if (isset($seen[$id])) {
                    continue;
                }
                $seen[$id] = true;
                $selected[] = $word;
                if (count($selected) >= $target) {
                    break;
                }
            }
        }
        return $selected;
    }

    private static function bucket(array $word): string
    {
        if ((int)($word['is_starred'] ?? 0) === 1) {
            return 'weak';
        }
        if (empty($word['progress_id']) || ($word['progress_status'] ?? 'new') === 'new') {
            return 'new';
        }
        $total = max(1, (int)$word['correct_count'] + (int)$word['wrong_count']);
        $wrongRatio = (int)$word['wrong_count'] / $total;
        $slow = (int)($word['average_answer_ms'] ?? 0) >= 9000;
        $stillRecovering = (int)$word['wrong_count'] > 0 && (int)$word['consecutive_correct'] < 3;
        if ($wrongRatio >= 0.25 || (float)$word['difficulty_score'] >= 2.2 || $slow || $stillRecovering || (int)$word['lapse_count'] >= 2) {
            return 'weak';
        }
        $next = $word['progress_next_review_at'] ?? null;
        if ($next === null || strtotime((string)$next) <= time()) {
            return 'due';
        }
        return 'mature';
    }

    private static function priority(array $word): float
    {
        if (empty($word['progress_id'])) {
            return 2.0;
        }
        $total = max(1, (int)$word['correct_count'] + (int)$word['wrong_count']);
        $wrongRatio = (int)$word['wrong_count'] / $total;
        $score = (float)($word['difficulty_score'] ?? 1.0) + ($wrongRatio * 5.0);
        $score += min(4.0, (int)($word['lapse_count'] ?? 0) * 0.55);
        if ((int)($word['is_starred'] ?? 0) === 1) {
            $score += 3.0;
        }
        $average = (int)($word['average_answer_ms'] ?? 0);
        if ($average > 6000) {
            $score += min(2.0, ($average - 6000) / 5000);
        }
        $next = $word['progress_next_review_at'] ?? null;
        if ($next !== null && strtotime((string)$next) <= time()) {
            $score += min(5.0, max(0.0, (time() - strtotime((string)$next)) / 86400));
        }
        $last = $word['last_reviewed_at'] ?? null;
        if ($last !== null) {
            $score += min(2.0, max(0.0, (time() - strtotime((string)$last)) / (86400 * 30)));
        }
        return $score;
    }

    private static function nextItem(int $sessionId, bool $forUpdate = false): ?array
    {
        $items = Database::table('smart_learn_session_items');
        $words = Database::table('words');
        $sql = "SELECT i.*, w.lesson_id, w.english_word, w.uzbek_translation,
                       w.example_sentence, w.pronunciation
                FROM {$items} i
                INNER JOIN {$words} w ON w.id = i.word_id
                WHERE i.session_id = ? AND i.status = 'pending'
                ORDER BY i.position ASC, i.id ASC LIMIT 1";
        if ($forUpdate) {
            $sql .= ' FOR UPDATE';
        }
        $stmt = Database::connection()->prepare($sql);
        $stmt->execute([$sessionId]);
        $row = $stmt->fetch();
        return $row ?: null;
    }

    private static function sessionForUser(int $userId, int $sessionId, bool $forUpdate = false): ?array
    {
        $sessions = Database::table('smart_learn_sessions');
        $sql = "SELECT * FROM {$sessions} WHERE id = ? AND user_id = ? LIMIT 1";
        if ($forUpdate) {
            $sql .= ' FOR UPDATE';
        }
        $stmt = Database::connection()->prepare($sql);
        $stmt->execute([$sessionId, $userId]);
        $row = $stmt->fetch();
        return $row ?: null;
    }

    private static function sessionSummary(array $session): array
    {
        $planned = (int)$session['planned_count'];
        $answered = (int)$session['answered_count'];
        return [
            'id' => (int)$session['id'],
            'status' => $session['status'],
            'daily_goal_minutes' => (int)$session['daily_goal_minutes'],
            'direction' => $session['direction'],
            'planned_count' => $planned,
            'answered_count' => $answered,
            'correct_count' => (int)$session['correct_count'],
            'wrong_count' => (int)$session['wrong_count'],
            'earned_xp' => (int)$session['earned_xp'],
            'progress' => $planned <= 0 ? 0.0 : min(1.0, $answered / $planned),
            'started_at' => $session['started_at'],
            'last_activity_at' => $session['last_activity_at'],
            'completed_at' => $session['completed_at'],
        ];
    }

    private static function itemDirection(string $direction, int $index): string
    {
        if ($direction === 'mixed') {
            return $index % 2 === 0 ? 'eng_to_uz' : 'uz_to_eng';
        }
        return $direction;
    }

    private static function sanitizeSessionDirection(string $direction): string
    {
        return in_array($direction, ['eng_to_uz', 'uz_to_eng', 'mixed'], true) ? $direction : 'mixed';
    }

    private static function sameAnswer(string $left, string $right): bool
    {
        return self::normalize($left) === self::normalize($right);
    }

    private static function safeOfflineDate(string $value): string
    {
        try {
            $date = new DateTimeImmutable($value);
            $now = new DateTimeImmutable();
            if ($date > $now || $date < $now->modify('-30 days')) {
                return $now->format('Y-m-d H:i:s');
            }
            return $date->format('Y-m-d H:i:s');
        } catch (Throwable $error) {
            return (new DateTimeImmutable())->format('Y-m-d H:i:s');
        }
    }

    private static function normalize(string $value): string
    {
        $value = trim((string)preg_replace('/\s+/u', ' ', $value));
        return function_exists('mb_strtolower') ? mb_strtolower($value, 'UTF-8') : strtolower($value);
    }
}
