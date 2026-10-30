<?php

require_once __DIR__ . '/../../helpers/response.php';
require_once __DIR__ . '/../../middleware/auth_middleware.php';
require_once __DIR__ . '/../../config/database.php';

require_method('GET');

try {
    $user = auth_user();
    $pdo = Database::connection();
    $userId = (int)$user['id'];

    $wordsTable = Database::table('words');
    $lessonsTable = Database::table('lessons');
    $wordProgressTable = Database::table('user_word_progress');
    $stmt = $pdo->prepare(
        "SELECT
            COUNT(*) AS total_words,
            SUM(CASE WHEN p.correct_count > 0 THEN 1 ELSE 0 END) AS mastered_words
         FROM {$wordsTable} w
         INNER JOIN {$lessonsTable} l ON l.id = w.lesson_id
         LEFT JOIN {$wordProgressTable} p ON p.word_id = w.id AND p.user_id = ?
         WHERE l.user_id = ?"
    );
    $stmt->execute([$userId, $userId]);
    $wordStats = $stmt->fetch() ?: [];

    $resultsTable = Database::table('quiz_results');
    $weekly = [];
    for ($i = 6; $i >= 0; $i--) {
        $date = (new DateTimeImmutable("-{$i} days"))->format('Y-m-d');
        $weekly[$date] = 0;
    }
    $stmt = $pdo->prepare(
        "SELECT DATE(created_at) AS day, SUM(earned_xp) AS xp
         FROM {$resultsTable}
         WHERE user_id = ? AND created_at >= DATE_SUB(CURDATE(), INTERVAL 6 DAY)
         GROUP BY DATE(created_at)"
    );
    $stmt->execute([$userId]);
    foreach ($stmt->fetchAll() as $row) {
        $weekly[$row['day']] = (int)$row['xp'];
    }

    success_response([
        'stats' => [
            'english_level' => $user['english_level'] ?? 'A1',
            'total_words' => (int)($wordStats['total_words'] ?? 0),
            'mastered_words' => (int)($wordStats['mastered_words'] ?? 0),
            'progress_percentage' => (int)($wordStats['total_words'] ?? 0) > 0 
                ? (int)round(((int)($wordStats['mastered_words'] ?? 0) / (int)($wordStats['total_words'] ?? 0)) * 100) 
                : 0,
            'grammar_completed' => 0,
            'grammar_total' => 0,
            'weekly_xp' => array_map(static function (string $day, int $xp): array {
                return ['day' => $day, 'xp' => $xp];
            }, array_keys($weekly), array_values($weekly)),
        ],
    ]);
} catch (Throwable $error) {
    error_response($error->getMessage(), 500);
}
