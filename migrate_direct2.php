<?php
ini_set('display_errors', 1);
error_reporting(E_ALL);

try {
    \ = new PDO('mysql:host=localhost;dbname=69a7b993de9dc_ojspkp;charset=utf8mb4', '69a7b993de9dc_ojspkp', 'ojspkp');
    \->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    \ = 'wr_api_tokens';

    \ = [
        "ALTER TABLE {\} ADD COLUMN device_name VARCHAR(255) NULL AFTER token_hash",
        "ALTER TABLE {\} ADD COLUMN ip_address VARCHAR(45) NULL AFTER device_name",
        "ALTER TABLE {\} ADD COLUMN last_active_at DATETIME NULL AFTER ip_address",
        "ALTER TABLE {\} ADD COLUMN is_online TINYINT(1) NOT NULL DEFAULT 0 AFTER last_active_at"
    ];

    foreach (\ as \) {
        try {
            \->exec(\);
            echo "Executed: \<br>";
        } catch (PDOException \) {
            echo "Skipped (or error): " . \->getMessage() . "<br>";
        }
    }
    echo "Migration completed successfully.";
} catch (Throwable \) {
    echo "Fatal error: " . \->getMessage();
}
?>
