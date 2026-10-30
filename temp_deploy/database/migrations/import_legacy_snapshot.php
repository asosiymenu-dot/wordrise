<?php

require_once __DIR__ . '/../../config/database.php';

if (PHP_SAPI !== 'cli') {
    http_response_code(404);
    exit;
}

$snapshotPath = $argv[1] ?? '';
if ($snapshotPath === '' || !is_file($snapshotPath)) {
    fwrite(STDERR, "Usage: php import_legacy_snapshot.php /absolute/path/to/snapshot.json\n");
    exit(1);
}

$rawSnapshot = file_get_contents($snapshotPath);
$snapshot = json_decode((string)$rawSnapshot, true);
if (!is_array($snapshot) || json_last_error() !== JSON_ERROR_NONE) {
    fwrite(STDERR, "Invalid legacy snapshot JSON.\n");
    exit(1);
}

$sourceKey = trim((string)($snapshot['source_key'] ?? ''));
if (!preg_match('/^[A-Za-z0-9._:-]{3,100}$/', $sourceKey)) {
    fwrite(STDERR, "Invalid source_key.\n");
    exit(1);
}

$pdo = Database::connection();
$tables = [
    'users' => Database::table('users'),
    'lessons' => Database::table('lessons'),
    'words' => Database::table('words'),
    'quiz_results' => Database::table('quiz_results'),
    'quiz_result_answers' => Database::table('quiz_result_answers'),
    'mistakes' => Database::table('mistakes'),
    'badges' => Database::table('badges'),
    'user_badges' => Database::table('user_badges'),
    'progress' => Database::table('user_word_progress'),
    'map' => Database::table('legacy_import_map'),
];

$pdo->exec("CREATE TABLE IF NOT EXISTS {$tables['map']} (
  source_key VARCHAR(100) NOT NULL,
  entity VARCHAR(40) NOT NULL,
  legacy_id BIGINT UNSIGNED NOT NULL,
  target_id BIGINT UNSIGNED NOT NULL,
  imported_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (source_key, entity, legacy_id),
  INDEX idx_legacy_target (entity, target_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");

$stats = [
    'users_created' => 0,
    'users_matched' => 0,
    'lessons_created' => 0,
    'words_created' => 0,
    'quiz_results_created' => 0,
    'answers_created' => 0,
    'mistakes_synced' => 0,
    'badges_synced' => 0,
    'progress_synced' => 0,
];
$userMap = [];
$lessonMap = [];
$wordMap = [];
$resultMap = [];
$resultOwner = [];

try {
    $pdo->beginTransaction();

    foreach (snapshot_rows($snapshot, 'users') as $legacyUser) {
        $legacyId = positive_id($legacyUser['id'] ?? 0, 'user');
        $email = strtolower(trim((string)($legacyUser['email'] ?? '')));
        $passwordHash = (string)($legacyUser['password_hash'] ?? '');
        if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
            throw new RuntimeException("Invalid email for legacy user {$legacyId}.");
        }
        if ((int)(password_get_info($passwordHash)['algo'] ?? 0) === 0) {
            throw new RuntimeException("Invalid password hash for legacy user {$legacyId}.");
        }

        $targetId = mapped_target($pdo, $tables['map'], $sourceKey, 'user', $legacyId);
        if ($targetId === null) {
            $find = $pdo->prepare("SELECT id FROM {$tables['users']} WHERE email = ? LIMIT 1");
            $find->execute([$email]);
            $existingId = $find->fetchColumn();
            if ($existingId !== false) {
                $targetId = (int)$existingId;
                $stats['users_matched']++;
                $update = $pdo->prepare(
                    "UPDATE {$tables['users']}
                     SET xp = GREATEST(xp, ?), level = GREATEST(level, ?),
                         streak = GREATEST(streak, ?), updated_at = updated_at
                     WHERE id = ?"
                );
                $update->execute([
                    max(0, (int)($legacyUser['xp'] ?? 0)),
                    max(1, (int)($legacyUser['level'] ?? 1)),
                    max(0, (int)($legacyUser['streak'] ?? 0)),
                    $targetId,
                ]);
            } else {
                $username = unique_username($pdo, $tables['users'], $legacyUser);
                $role = in_array(($legacyUser['role'] ?? ''), ['student', 'teacher', 'admin'], true)
                    ? (string)$legacyUser['role']
                    : 'student';
                $insert = $pdo->prepare(
                    "INSERT INTO {$tables['users']}
                     (name, username, email, password_hash, avatar, role, xp, level, streak,
                      last_active_date, created_at, updated_at)
                     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
                );
                $insert->execute([
                    cut_text(trim((string)($legacyUser['name'] ?? 'Legacy user')), 120),
                    $username,
                    $email,
                    $passwordHash,
                    nullable_text($legacyUser['avatar'] ?? null, 255),
                    $role,
                    max(0, (int)($legacyUser['xp'] ?? 0)),
                    max(1, (int)($legacyUser['level'] ?? 1)),
                    max(0, (int)($legacyUser['streak'] ?? 0)),
                    nullable_date($legacyUser['last_active_date'] ?? null),
                    normalized_datetime($legacyUser['created_at'] ?? null),
                    normalized_datetime($legacyUser['updated_at'] ?? ($legacyUser['created_at'] ?? null)),
                ]);
                $targetId = (int)$pdo->lastInsertId();
                $stats['users_created']++;
            }
            store_mapping($pdo, $tables['map'], $sourceKey, 'user', $legacyId, $targetId);
        }
        $userMap[$legacyId] = $targetId;
    }

    foreach (snapshot_rows($snapshot, 'lessons') as $legacyLesson) {
        $legacyId = positive_id($legacyLesson['id'] ?? 0, 'lesson');
        $legacyUserId = positive_id($legacyLesson['user_id'] ?? 0, 'lesson owner');
        if (!isset($userMap[$legacyUserId])) {
            continue;
        }
        $targetId = mapped_target($pdo, $tables['map'], $sourceKey, 'lesson', $legacyId);
        if ($targetId === null) {
            $createdAt = normalized_datetime($legacyLesson['created_at'] ?? null);
            $find = $pdo->prepare(
                "SELECT id FROM {$tables['lessons']}
                 WHERE user_id = ? AND title = ? AND created_at = ? LIMIT 1"
            );
            $title = cut_text(trim((string)($legacyLesson['title'] ?? 'Legacy lesson')), 160);
            $find->execute([$userMap[$legacyUserId], $title, $createdAt]);
            $existingId = $find->fetchColumn();
            if ($existingId !== false) {
                $targetId = (int)$existingId;
            } else {
                $insert = $pdo->prepare(
                    "INSERT INTO {$tables['lessons']}
                     (user_id, title, description, category, created_at, updated_at)
                     VALUES (?, ?, ?, ?, ?, ?)"
                );
                $insert->execute([
                    $userMap[$legacyUserId],
                    $title,
                    nullable_text($legacyLesson['description'] ?? null, 65535),
                    cut_text(trim((string)($legacyLesson['category'] ?? 'General')), 100),
                    $createdAt,
                    normalized_datetime($legacyLesson['updated_at'] ?? $createdAt),
                ]);
                $targetId = (int)$pdo->lastInsertId();
                $stats['lessons_created']++;
            }
            store_mapping($pdo, $tables['map'], $sourceKey, 'lesson', $legacyId, $targetId);
        }
        $lessonMap[$legacyId] = $targetId;
    }

    foreach (snapshot_rows($snapshot, 'words') as $legacyWord) {
        $legacyId = positive_id($legacyWord['id'] ?? 0, 'word');
        $legacyLessonId = positive_id($legacyWord['lesson_id'] ?? 0, 'word lesson');
        if (!isset($lessonMap[$legacyLessonId])) {
            continue;
        }
        $targetId = mapped_target($pdo, $tables['map'], $sourceKey, 'word', $legacyId);
        if ($targetId === null) {
            $english = cut_text(trim((string)($legacyWord['english_word'] ?? '')), 120);
            $translation = cut_text(trim((string)($legacyWord['uzbek_translation'] ?? '')), 160);
            if ($english === '' || $translation === '') {
                throw new RuntimeException("Legacy word {$legacyId} is incomplete.");
            }
            $find = $pdo->prepare(
                "SELECT id FROM {$tables['words']} WHERE lesson_id = ? AND english_word = ? LIMIT 1"
            );
            $find->execute([$lessonMap[$legacyLessonId], $english]);
            $existingId = $find->fetchColumn();
            if ($existingId !== false) {
                $targetId = (int)$existingId;
            } else {
                $insert = $pdo->prepare(
                    "INSERT INTO {$tables['words']}
                     (lesson_id, english_word, uzbek_translation, example_sentence, pronunciation,
                      created_at, updated_at)
                     VALUES (?, ?, ?, ?, ?, ?, ?)"
                );
                $insert->execute([
                    $lessonMap[$legacyLessonId],
                    $english,
                    $translation,
                    nullable_text($legacyWord['example_sentence'] ?? null, 255),
                    nullable_text($legacyWord['pronunciation'] ?? null, 120),
                    normalized_datetime($legacyWord['created_at'] ?? null),
                    normalized_datetime($legacyWord['updated_at'] ?? ($legacyWord['created_at'] ?? null)),
                ]);
                $targetId = (int)$pdo->lastInsertId();
                $stats['words_created']++;
            }
            store_mapping($pdo, $tables['map'], $sourceKey, 'word', $legacyId, $targetId);
        }
        $wordMap[$legacyId] = $targetId;
    }

    foreach (snapshot_rows($snapshot, 'quiz_results') as $legacyResult) {
        $legacyId = positive_id($legacyResult['id'] ?? 0, 'quiz result');
        $legacyUserId = positive_id($legacyResult['user_id'] ?? 0, 'quiz user');
        $legacyLessonId = positive_id($legacyResult['lesson_id'] ?? 0, 'quiz lesson');
        if (!isset($userMap[$legacyUserId], $lessonMap[$legacyLessonId])) {
            continue;
        }
        $resultOwner[$legacyId] = $legacyUserId;
        $targetId = mapped_target($pdo, $tables['map'], $sourceKey, 'quiz_result', $legacyId);
        if ($targetId === null) {
            $createdAt = normalized_datetime($legacyResult['created_at'] ?? null);
            $mode = cut_text(trim((string)($legacyResult['mode'] ?? 'legacy')), 40);
            $find = $pdo->prepare(
                "SELECT id FROM {$tables['quiz_results']}
                 WHERE user_id = ? AND lesson_id = ? AND mode = ? AND created_at = ?
                   AND correct_count = ? AND wrong_count = ? AND earned_xp = ? LIMIT 1"
            );
            $values = [
                $userMap[$legacyUserId],
                $lessonMap[$legacyLessonId],
                $mode,
                $createdAt,
                max(0, (int)($legacyResult['correct_count'] ?? 0)),
                max(0, (int)($legacyResult['wrong_count'] ?? 0)),
                max(0, (int)($legacyResult['earned_xp'] ?? 0)),
            ];
            $find->execute($values);
            $existingId = $find->fetchColumn();
            if ($existingId !== false) {
                $targetId = (int)$existingId;
            } else {
                $insert = $pdo->prepare(
                    "INSERT INTO {$tables['quiz_results']}
                     (user_id, lesson_id, mode, correct_count, wrong_count, earned_xp, created_at)
                     VALUES (?, ?, ?, ?, ?, ?, ?)"
                );
                $insert->execute([
                    $values[0], $values[1], $values[2], $values[4], $values[5], $values[6], $values[3],
                ]);
                $targetId = (int)$pdo->lastInsertId();
                $stats['quiz_results_created']++;
            }
            store_mapping($pdo, $tables['map'], $sourceKey, 'quiz_result', $legacyId, $targetId);
        }
        $resultMap[$legacyId] = $targetId;
    }

    $legacyAnswers = snapshot_rows($snapshot, 'quiz_result_answers');
    usort($legacyAnswers, function (array $left, array $right): int {
        $leftKey = (string)($left['created_at'] ?? '') . ':' . str_pad((string)($left['id'] ?? 0), 20, '0', STR_PAD_LEFT);
        $rightKey = (string)($right['created_at'] ?? '') . ':' . str_pad((string)($right['id'] ?? 0), 20, '0', STR_PAD_LEFT);
        return strcmp($leftKey, $rightKey);
    });
    foreach ($legacyAnswers as $legacyAnswer) {
        $legacyId = positive_id($legacyAnswer['id'] ?? 0, 'quiz answer');
        $legacyResultId = positive_id($legacyAnswer['quiz_result_id'] ?? 0, 'answer result');
        $legacyWordId = positive_id($legacyAnswer['word_id'] ?? 0, 'answer word');
        if (!isset($resultMap[$legacyResultId], $wordMap[$legacyWordId])) {
            continue;
        }
        $targetId = mapped_target($pdo, $tables['map'], $sourceKey, 'quiz_answer', $legacyId);
        if ($targetId === null) {
            $insert = $pdo->prepare(
                "INSERT INTO {$tables['quiz_result_answers']}
                 (quiz_result_id, word_id, given_answer, is_correct, created_at)
                 VALUES (?, ?, ?, ?, ?)"
            );
            $insert->execute([
                $resultMap[$legacyResultId],
                $wordMap[$legacyWordId],
                cut_text((string)($legacyAnswer['given_answer'] ?? ''), 255),
                !empty($legacyAnswer['is_correct']) ? 1 : 0,
                normalized_datetime($legacyAnswer['created_at'] ?? null),
            ]);
            $targetId = (int)$pdo->lastInsertId();
            store_mapping($pdo, $tables['map'], $sourceKey, 'quiz_answer', $legacyId, $targetId);
            $stats['answers_created']++;
        }
    }

    foreach (snapshot_rows($snapshot, 'mistakes') as $legacyMistake) {
        $legacyUserId = positive_id($legacyMistake['user_id'] ?? 0, 'mistake user');
        $legacyWordId = positive_id($legacyMistake['word_id'] ?? 0, 'mistake word');
        if (!isset($userMap[$legacyUserId], $wordMap[$legacyWordId])) {
            continue;
        }
        $stmt = $pdo->prepare(
            "INSERT INTO {$tables['mistakes']} (user_id, word_id, mistake_count, last_mistake_at)
             VALUES (?, ?, ?, ?)
             ON DUPLICATE KEY UPDATE
               mistake_count = GREATEST(mistake_count, VALUES(mistake_count)),
               last_mistake_at = GREATEST(last_mistake_at, VALUES(last_mistake_at))"
        );
        $stmt->execute([
            $userMap[$legacyUserId],
            $wordMap[$legacyWordId],
            max(1, (int)($legacyMistake['mistake_count'] ?? 1)),
            normalized_datetime($legacyMistake['last_mistake_at'] ?? null),
        ]);
        $stats['mistakes_synced']++;
    }

    $badgeMap = [];
    foreach (snapshot_rows($snapshot, 'badges') as $legacyBadge) {
        $legacyId = positive_id($legacyBadge['id'] ?? 0, 'badge');
        $targetId = mapped_target($pdo, $tables['map'], $sourceKey, 'badge', $legacyId);
        if ($targetId === null) {
            $title = cut_text(trim((string)($legacyBadge['title'] ?? 'Legacy badge')), 120);
            $find = $pdo->prepare("SELECT id FROM {$tables['badges']} WHERE title = ? LIMIT 1");
            $find->execute([$title]);
            $existingId = $find->fetchColumn();
            if ($existingId !== false) {
                $targetId = (int)$existingId;
            } else {
                $insert = $pdo->prepare(
                    "INSERT INTO {$tables['badges']}
                     (title, description, icon, required_condition, created_at)
                     VALUES (?, ?, ?, ?, ?)"
                );
                $insert->execute([
                    $title,
                    cut_text((string)($legacyBadge['description'] ?? ''), 255),
                    cut_text((string)($legacyBadge['icon'] ?? 'award'), 80),
                    cut_text((string)($legacyBadge['required_condition'] ?? 'legacy'), 120),
                    normalized_datetime($legacyBadge['created_at'] ?? null),
                ]);
                $targetId = (int)$pdo->lastInsertId();
            }
            store_mapping($pdo, $tables['map'], $sourceKey, 'badge', $legacyId, $targetId);
        }
        $badgeMap[$legacyId] = $targetId;
    }

    foreach (snapshot_rows($snapshot, 'user_badges') as $legacyUserBadge) {
        $legacyUserId = positive_id($legacyUserBadge['user_id'] ?? 0, 'badge user');
        $legacyBadgeId = positive_id($legacyUserBadge['badge_id'] ?? 0, 'user badge');
        if (!isset($userMap[$legacyUserId], $badgeMap[$legacyBadgeId])) {
            continue;
        }
        $stmt = $pdo->prepare(
            "INSERT IGNORE INTO {$tables['user_badges']} (user_id, badge_id, earned_at) VALUES (?, ?, ?)"
        );
        $stmt->execute([
            $userMap[$legacyUserId],
            $badgeMap[$legacyBadgeId],
            normalized_datetime($legacyUserBadge['earned_at'] ?? null),
        ]);
        $stats['badges_synced']++;
    }

    $progress = build_legacy_progress($legacyAnswers, snapshot_rows($snapshot, 'mistakes'), $resultOwner);
    foreach ($progress as $row) {
        $legacyUserId = $row['user_id'];
        $legacyWordId = $row['word_id'];
        if (!isset($userMap[$legacyUserId], $wordMap[$legacyWordId])) {
            continue;
        }
        $schedule = legacy_schedule($row);
        $stmt = $pdo->prepare(
            "INSERT INTO {$tables['progress']}
             (user_id, word_id, status, correct_count, wrong_count, lapse_count,
              consecutive_correct, ease_factor, review_interval, next_review_at,
              difficulty_score, last_reviewed_at)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
             ON DUPLICATE KEY UPDATE
               status = CASE
                 WHEN status = 'mastered' OR VALUES(status) = 'mastered' THEN 'mastered'
                 WHEN status = 'review' OR VALUES(status) = 'review' THEN 'review'
                 WHEN status = 'learning' OR VALUES(status) = 'learning' THEN 'learning'
                 ELSE 'new'
               END,
               correct_count = GREATEST(correct_count, VALUES(correct_count)),
               wrong_count = GREATEST(wrong_count, VALUES(wrong_count)),
               lapse_count = GREATEST(lapse_count, VALUES(lapse_count)),
               consecutive_correct = GREATEST(consecutive_correct, VALUES(consecutive_correct)),
               ease_factor = LEAST(ease_factor, VALUES(ease_factor)),
               review_interval = GREATEST(review_interval, VALUES(review_interval)),
               next_review_at = CASE
                 WHEN next_review_at IS NULL THEN VALUES(next_review_at)
                 WHEN VALUES(next_review_at) IS NULL THEN next_review_at
                 ELSE LEAST(next_review_at, VALUES(next_review_at))
               END,
               difficulty_score = GREATEST(difficulty_score, VALUES(difficulty_score)),
               last_reviewed_at = GREATEST(
                 COALESCE(last_reviewed_at, '1970-01-01 00:00:00'),
                 COALESCE(VALUES(last_reviewed_at), '1970-01-01 00:00:00')
               )"
        );
        $stmt->execute([
            $userMap[$legacyUserId],
            $wordMap[$legacyWordId],
            $schedule['status'],
            $row['correct'],
            $row['wrong'],
            $row['wrong'],
            $row['consecutive_correct'],
            $schedule['ease_factor'],
            $schedule['interval'],
            $schedule['next_review_at'],
            $schedule['difficulty_score'],
            $row['last_reviewed_at'],
        ]);
        $stats['progress_synced']++;
    }

    $pdo->commit();
    echo json_encode([
        'ok' => true,
        'source_key' => $sourceKey,
        'stats' => $stats,
        'user_map' => $userMap,
    ], JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT) . "\n";
} catch (Throwable $error) {
    if ($pdo->inTransaction()) {
        $pdo->rollBack();
    }
    fwrite(STDERR, $error->getMessage() . "\n");
    exit(1);
}

function snapshot_rows(array $snapshot, string $key): array
{
    $rows = $snapshot[$key] ?? [];
    return is_array($rows) ? array_values(array_filter($rows, 'is_array')) : [];
}

function positive_id($value, string $entity): int
{
    $id = (int)$value;
    if ($id <= 0) {
        throw new RuntimeException("Invalid {$entity} id.");
    }
    return $id;
}

function mapped_target(PDO $pdo, string $mapTable, string $sourceKey, string $entity, int $legacyId): ?int
{
    $stmt = $pdo->prepare(
        "SELECT target_id FROM {$mapTable} WHERE source_key = ? AND entity = ? AND legacy_id = ? LIMIT 1"
    );
    $stmt->execute([$sourceKey, $entity, $legacyId]);
    $value = $stmt->fetchColumn();
    return $value === false ? null : (int)$value;
}

function store_mapping(
    PDO $pdo,
    string $mapTable,
    string $sourceKey,
    string $entity,
    int $legacyId,
    int $targetId
): void {
    $stmt = $pdo->prepare(
        "INSERT INTO {$mapTable} (source_key, entity, legacy_id, target_id)
         VALUES (?, ?, ?, ?)
         ON DUPLICATE KEY UPDATE target_id = VALUES(target_id)"
    );
    $stmt->execute([$sourceKey, $entity, $legacyId, $targetId]);
}

function unique_username(PDO $pdo, string $usersTable, array $legacyUser): string
{
    $candidate = strtolower(trim((string)($legacyUser['username'] ?? '')));
    if ($candidate === '') {
        $email = (string)($legacyUser['email'] ?? 'legacy');
        $candidate = explode('@', $email, 2)[0];
    }
    $candidate = (string)preg_replace('/[^a-z0-9_.]+/', '_', $candidate);
    $candidate = trim($candidate, '._');
    if (strlen($candidate) < 3) {
        $candidate = 'legacy_user';
    }
    $candidate = substr($candidate, 0, 22) . '_legacy';
    $candidate = substr($candidate, 0, 30);
    $base = $candidate;
    $suffix = 1;
    $find = $pdo->prepare("SELECT id FROM {$usersTable} WHERE username = ? LIMIT 1");
    while (true) {
        $find->execute([$candidate]);
        if ($find->fetchColumn() === false) {
            return $candidate;
        }
        $suffix++;
        $candidate = substr($base, 0, 30 - strlen((string)$suffix) - 1) . '_' . $suffix;
    }
}

function cut_text(string $value, int $length): string
{
    return function_exists('mb_substr') ? mb_substr($value, 0, $length) : substr($value, 0, $length);
}

function nullable_text($value, int $length): ?string
{
    $text = trim((string)$value);
    return $text === '' ? null : cut_text($text, $length);
}

function normalized_datetime($value): string
{
    $text = trim((string)$value);
    if ($text === '') {
        return date('Y-m-d H:i:s');
    }
    try {
        return (new DateTimeImmutable($text))->format('Y-m-d H:i:s');
    } catch (Throwable $error) {
        throw new RuntimeException("Invalid legacy datetime: {$text}");
    }
}

function nullable_date($value): ?string
{
    $text = trim((string)$value);
    if ($text === '') {
        return null;
    }
    try {
        return (new DateTimeImmutable($text))->format('Y-m-d');
    } catch (Throwable $error) {
        throw new RuntimeException("Invalid legacy date: {$text}");
    }
}

function build_legacy_progress(array $answers, array $mistakes, array $resultOwner): array
{
    $progress = [];
    foreach ($answers as $answer) {
        $resultId = (int)($answer['quiz_result_id'] ?? 0);
        $wordId = (int)($answer['word_id'] ?? 0);
        if ($wordId <= 0 || !isset($resultOwner[$resultId])) {
            continue;
        }
        $userId = (int)$resultOwner[$resultId];
        $key = $userId . ':' . $wordId;
        if (!isset($progress[$key])) {
            $progress[$key] = [
                'user_id' => $userId,
                'word_id' => $wordId,
                'correct' => 0,
                'wrong' => 0,
                'consecutive_correct' => 0,
                'last_reviewed_at' => null,
            ];
        }
        if (!empty($answer['is_correct'])) {
            $progress[$key]['correct']++;
            $progress[$key]['consecutive_correct']++;
        } else {
            $progress[$key]['wrong']++;
            $progress[$key]['consecutive_correct'] = 0;
        }
        $reviewedAt = normalized_datetime($answer['created_at'] ?? null);
        if ($progress[$key]['last_reviewed_at'] === null || $reviewedAt > $progress[$key]['last_reviewed_at']) {
            $progress[$key]['last_reviewed_at'] = $reviewedAt;
        }
    }

    foreach ($mistakes as $mistake) {
        $userId = (int)($mistake['user_id'] ?? 0);
        $wordId = (int)($mistake['word_id'] ?? 0);
        if ($userId <= 0 || $wordId <= 0) {
            continue;
        }
        $key = $userId . ':' . $wordId;
        if (!isset($progress[$key])) {
            $progress[$key] = [
                'user_id' => $userId,
                'word_id' => $wordId,
                'correct' => 0,
                'wrong' => 0,
                'consecutive_correct' => 0,
                'last_reviewed_at' => null,
            ];
        }
        $progress[$key]['wrong'] = max(
            $progress[$key]['wrong'],
            max(1, (int)($mistake['mistake_count'] ?? 1))
        );
        $mistakeAt = normalized_datetime($mistake['last_mistake_at'] ?? null);
        if ($progress[$key]['last_reviewed_at'] === null || $mistakeAt > $progress[$key]['last_reviewed_at']) {
            $progress[$key]['last_reviewed_at'] = $mistakeAt;
        }
    }

    return array_values($progress);
}

function legacy_schedule(array $row): array
{
    $correct = max(0, (int)$row['correct']);
    $wrong = max(0, (int)$row['wrong']);
    if ($correct >= 5 && $wrong === 0) {
        $status = 'mastered';
        $interval = 14;
    } elseif ($correct >= 3 && $correct >= ($wrong * 2)) {
        $status = 'review';
        $interval = 3;
    } elseif (($correct + $wrong) > 0) {
        $status = 'learning';
        $interval = 1;
    } else {
        $status = 'new';
        $interval = 0;
    }

    $easeFactor = max(1.30, min(2.50, 2.50 - ($wrong * 0.15) + (min($correct, 5) * 0.03)));
    $difficulty = max(0.50, min(10.00, 1.00 + ($wrong * 0.55) - ($correct * 0.05)));
    $nextReviewAt = null;
    if ($row['last_reviewed_at'] !== null && $interval > 0) {
        $nextReviewAt = (new DateTimeImmutable($row['last_reviewed_at']))
            ->add(new DateInterval('P' . $interval . 'D'))
            ->format('Y-m-d H:i:s');
    }

    return [
        'status' => $status,
        'interval' => $interval,
        'ease_factor' => number_format($easeFactor, 2, '.', ''),
        'difficulty_score' => number_format($difficulty, 2, '.', ''),
        'next_review_at' => $nextReviewAt,
    ];
}
