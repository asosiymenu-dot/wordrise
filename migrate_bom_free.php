<?php
ini_set('display_errors', 1);
error_reporting(E_ALL);

try {
    $pdo = new PDO('mysql:host=localhost;dbname=69a7b993de9dc_ojspkp;charset=utf8mb4', '69a7b993de9dc_ojspkp', 'ojspkp');
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    $table = 'wr_api_tokens';

    $commands = [
        "ALTER TABLE {$table} ADD COLUMN device_name VARCHAR(255) NULL AFTER token_hash",
        "ALTER TABLE {$table} ADD COLUMN ip_address VARCHAR(45) NULL AFTER device_name",
        "ALTER TABLE {$table} ADD COLUMN last_active_at DATETIME NULL AFTER ip_address",
        "ALTER TABLE {$table} ADD COLUMN is_online TINYINT(1) NOT NULL DEFAULT 0 AFTER last_active_at"
    ];

    foreach ($commands as $sql) {
        try {
            $pdo->exec($sql);
            echo "Executed: $sql\n";
        } catch (PDOException $e) {
            echo "Skipped (or error): " . $e->getMessage() . "\n";
        }
    }
    echo "Migration completed successfully.";
} catch (Throwable $e) {
    echo "Fatal error: " . $e->getMessage();
}
?>
