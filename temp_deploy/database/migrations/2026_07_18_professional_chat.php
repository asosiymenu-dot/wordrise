<?php

require_once __DIR__ . '/../../config/database.php';

$pdo = Database::connection();
$users = Database::table('users');
$messages = Database::table('messages');
$deletions = Database::table('message_user_deletions');
$attachments = Database::table('message_attachments');
$rateLimits = Database::table('message_rate_limits');

chat_add_column_20260718($pdo, $users, 'last_seen_at', 'DATETIME NULL AFTER last_active_date');
chat_add_index_20260718($pdo, $users, 'idx_users_last_seen', '(last_seen_at)');

chat_add_column_20260718($pdo, $messages, 'delivered_at', 'DATETIME NULL AFTER metadata_json');
chat_add_column_20260718($pdo, $messages, 'edited_at', 'DATETIME NULL AFTER read_at');
chat_add_column_20260718(
    $pdo,
    $messages,
    'deleted_for_everyone_at',
    'DATETIME NULL AFTER edited_at'
);
chat_add_column_20260718(
    $pdo,
    $messages,
    'deleted_for_everyone_by',
    'INT UNSIGNED NULL AFTER deleted_for_everyone_at'
);
chat_add_column_20260718(
    $pdo,
    $messages,
    'reply_to_message_id',
    'BIGINT UNSIGNED NULL AFTER deleted_for_everyone_by'
);
chat_add_column_20260718(
    $pdo,
    $messages,
    'updated_at',
    'TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP AFTER created_at'
);

chat_add_index_20260718(
    $pdo,
    $messages,
    'idx_messages_sender_receiver_id',
    '(sender_id, receiver_id, id)'
);
chat_add_index_20260718(
    $pdo,
    $messages,
    'idx_messages_receiver_delivered',
    '(receiver_id, delivered_at, id)'
);
chat_add_index_20260718($pdo, $messages, 'idx_messages_reply', '(reply_to_message_id)');
chat_add_index_20260718($pdo, $messages, 'idx_messages_updated', '(updated_at, id)');

chat_add_foreign_key_20260718(
    $pdo,
    $messages,
    chat_fk_name_20260718($messages, 'deleted_by'),
    'deleted_for_everyone_by',
    $users,
    'id',
    'SET NULL'
);
chat_add_foreign_key_20260718(
    $pdo,
    $messages,
    chat_fk_name_20260718($messages, 'reply'),
    'reply_to_message_id',
    $messages,
    'id',
    'SET NULL'
);

$pdo->exec("CREATE TABLE IF NOT EXISTS {$deletions} (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  message_id BIGINT UNSIGNED NOT NULL,
  user_id INT UNSIGNED NOT NULL,
  deleted_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY unique_message_user_deletion (message_id, user_id),
  INDEX idx_message_deletions_user (user_id, message_id),
  CONSTRAINT " . chat_fk_name_20260718($deletions, 'message') . "
    FOREIGN KEY (message_id) REFERENCES {$messages}(id) ON DELETE CASCADE,
  CONSTRAINT " . chat_fk_name_20260718($deletions, 'user') . "
    FOREIGN KEY (user_id) REFERENCES {$users}(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");

$pdo->exec("CREATE TABLE IF NOT EXISTS {$attachments} (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  message_id BIGINT UNSIGNED NOT NULL,
  type VARCHAR(24) NOT NULL DEFAULT 'image',
  storage_path VARCHAR(500) NOT NULL,
  thumbnail_path VARCHAR(500) NOT NULL,
  mime_type VARCHAR(100) NOT NULL,
  width INT UNSIGNED NOT NULL,
  height INT UNSIGNED NOT NULL,
  size_bytes INT UNSIGNED NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY unique_message_attachment (message_id),
  INDEX idx_message_attachments_type (type, created_at),
  CONSTRAINT " . chat_fk_name_20260718($attachments, 'message') . "
    FOREIGN KEY (message_id) REFERENCES {$messages}(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");

$pdo->exec("CREATE TABLE IF NOT EXISTS {$rateLimits} (
  user_id INT UNSIGNED NOT NULL,
  scope VARCHAR(32) NOT NULL,
  attempts SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  window_started_at DATETIME NOT NULL,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (user_id, scope),
  INDEX idx_message_rate_window (window_started_at),
  CONSTRAINT " . chat_fk_name_20260718($rateLimits, 'user') . "
    FOREIGN KEY (user_id) REFERENCES {$users}(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");

echo "2026_07_18_professional_chat ok\n";

function chat_add_column_20260718(PDO $pdo, string $table, string $column, string $definition): void
{
    $stmt = $pdo->prepare(
        'SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
         WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ?'
    );
    $stmt->execute([$table, $column]);
    if ((int)$stmt->fetchColumn() === 0) {
        $pdo->exec("ALTER TABLE {$table} ADD COLUMN {$column} {$definition}");
    }
}

function chat_add_index_20260718(PDO $pdo, string $table, string $index, string $columns): void
{
    $stmt = $pdo->prepare(
        'SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS
         WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND INDEX_NAME = ?'
    );
    $stmt->execute([$table, $index]);
    if ((int)$stmt->fetchColumn() === 0) {
        $pdo->exec("ALTER TABLE {$table} ADD INDEX {$index} {$columns}");
    }
}

function chat_add_foreign_key_20260718(
    PDO $pdo,
    string $table,
    string $constraint,
    string $column,
    string $referencedTable,
    string $referencedColumn,
    string $onDelete
): void {
    $stmt = $pdo->prepare(
        'SELECT COUNT(*) FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
         WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ?
           AND REFERENCED_TABLE_NAME IS NOT NULL'
    );
    $stmt->execute([$table, $column]);
    if ((int)$stmt->fetchColumn() === 0) {
        $pdo->exec(
            "ALTER TABLE {$table} ADD CONSTRAINT {$constraint}
             FOREIGN KEY ({$column}) REFERENCES {$referencedTable}({$referencedColumn})
             ON DELETE {$onDelete}"
        );
    }
}

function chat_fk_name_20260718(string $table, string $suffix): string
{
    return substr('fk_' . preg_replace('/[^A-Za-z0-9_]/', '_', $table) . '_' . $suffix, 0, 64);
}

