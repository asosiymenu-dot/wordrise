<?php
require_once __DIR__ . '/config/database.php';
require_once __DIR__ . '/models/User.php';

try {
    $userId = 24; // Abbosbek
    $updated = User::updateStatsAfterQuiz($userId, 10, 5, 0);
    echo "Success! Total learned: " . $updated['total_learned'];
} catch (Throwable $e) {
    echo "Error: " . $e->getMessage() . "\n" . $e->getTraceAsString();
}
