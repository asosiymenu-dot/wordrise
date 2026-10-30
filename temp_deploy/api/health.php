<?php

require_once __DIR__ . '/../helpers/response.php';

require_method('GET');

$dbConnected = false;
$dbError = null;
$stats = [];

try {
    require_once __DIR__ . '/../config/database.php';
    $pdo = Database::connection();
    $dbConnected = true;
    $wordsCount = (int)$pdo->query("SELECT COUNT(*) FROM " . Database::table('words'))->fetchColumn();
    $lessonsCount = (int)$pdo->query("SELECT COUNT(*) FROM " . Database::table('lessons'))->fetchColumn();
    $stats = [
        'words_count' => $wordsCount,
        'lessons_count' => $lessonsCount,
    ];
} catch (Throwable $error) {
    $dbError = $error->getMessage();
}

success_response([
    'php_version' => PHP_VERSION,
    'pdo_mysql_loaded' => extension_loaded('pdo_mysql'),
    'db_connected' => $dbConnected,
    'db_error' => $dbError,
    'stats' => $stats,
], 'Backend health.');
