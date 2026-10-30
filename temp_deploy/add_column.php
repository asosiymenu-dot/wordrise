<?php
require_once __DIR__ . '/config/database.php';

try {
    $pdo = Database::connection();
    $usersTable = Database::table('users');
    $pdo->exec("ALTER TABLE {$usersTable} ADD COLUMN IF NOT EXISTS total_learned INT UNSIGNED NOT NULL DEFAULT 0");
    echo "Success!";
} catch (Throwable $e) {
    echo "Error: " . $e->getMessage();
}
