<?php
require_once __DIR__ . '/config/database.php';

try {
    $pdo = Database::connection();
    $stmt = $pdo->query("SELECT user_id, COUNT(*) as c FROM user_word_progress WHERE correct_count > 0 GROUP BY user_id");
    $users = $stmt->fetchAll(PDO::FETCH_ASSOC);
    echo json_encode($users);
} catch (Throwable $e) {
    echo "Error: " . $e->getMessage();
}
