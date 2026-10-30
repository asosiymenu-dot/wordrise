<?php

require_once __DIR__ . '/../../config/database.php';

$pdo = Database::connection();
$messages = Database::table('messages');

if (!has_message_column_20260716($pdo, $messages, 'client_message_id')) {
    $pdo->exec(
        "ALTER TABLE {$messages}
         ADD COLUMN client_message_id VARCHAR(64) NULL AFTER body"
    );
}
if (!has_message_index_20260716($pdo, $messages, 'unique_sender_client_message')) {
    $pdo->exec(
        "ALTER TABLE {$messages}
         ADD UNIQUE KEY unique_sender_client_message (sender_id, client_message_id)"
    );
}

echo "2026_07_16_message_reliability ok\n";

function has_message_column_20260716(PDO $pdo, string $table, string $column): bool
{
    $stmt = $pdo->prepare(
        "SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
         WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ?"
    );
    $stmt->execute([$table, $column]);
    return (int)$stmt->fetchColumn() > 0;
}

function has_message_index_20260716(PDO $pdo, string $table, string $index): bool
{
    $stmt = $pdo->prepare(
        "SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS
         WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND INDEX_NAME = ?"
    );
    $stmt->execute([$table, $index]);
    return (int)$stmt->fetchColumn() > 0;
}
