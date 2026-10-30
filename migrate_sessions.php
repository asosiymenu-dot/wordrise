<?php
ini_set('display_errors', 1);
error_reporting(E_ALL);

require_once __DIR__ . '/../config/database.php';

try {
    \ = Database::connection();
    \ = Database::table('api_tokens');

    \ = [
        "ALTER TABLE {\} ADD COLUMN device_name VARCHAR(255) NULL AFTER token_hash",
        "ALTER TABLE {\} ADD COLUMN ip_address VARCHAR(45) NULL AFTER device_name",
        "ALTER TABLE {\} ADD COLUMN last_active_at DATETIME NULL AFTER ip_address",
        "ALTER TABLE {\} ADD COLUMN is_online TINYINT(1) NOT NULL DEFAULT 0 AFTER last_active_at"
    ];

    foreach (\ as \) {
        try {
            \->exec(\);
            echo "Executed: \\n";
        } catch (PDOException \) {
            echo "Skipped (or error): " . \->getMessage() . "\n";
        }
    }
    echo "Migration completed successfully.\n";
} catch (Throwable \) {
    echo "Fatal error: " . \->getMessage() . "\n";
}

