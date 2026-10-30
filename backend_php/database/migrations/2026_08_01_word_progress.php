<?php
require_once __DIR__ . '/../../config/database.php';

try {
    $pdo = Database::connection();
    
    $table = Database::table('user_word_progress');
    $pdo->exec("
        ALTER TABLE {$table}
        ADD COLUMN is_learned TINYINT(1) NOT NULL DEFAULT 0 AFTER correct_count,
        ADD COLUMN is_difficult TINYINT(1) NOT NULL DEFAULT 0 AFTER wrong_count
    ");

    echo "Migration completed successfully.\n";

    $usersTable = Database::table('users');
    $pdo->exec("
        ALTER TABLE {$usersTable}
        ADD COLUMN IF NOT EXISTS total_learned INT UNSIGNED NOT NULL DEFAULT 0,
        ADD COLUMN IF NOT EXISTS progress_percent DECIMAL(5,2) NOT NULL DEFAULT 0.0
    ");
    echo "Users table updated.\n";

} catch (Exception $e) {
    echo "Migration failed (might already exist): " . $e->getMessage() . "\n";
}
