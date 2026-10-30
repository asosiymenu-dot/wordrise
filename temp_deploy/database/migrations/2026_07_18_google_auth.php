<?php

require_once __DIR__ . '/../../config/database.php';

$pdo = Database::connection();
$users = Database::table('users');

google_auth_add_column_20260718(
    $pdo,
    $users,
    'google_sub',
    'VARCHAR(255) CHARACTER SET ascii COLLATE ascii_bin NULL AFTER password_hash'
);
google_auth_add_column_20260718(
    $pdo,
    $users,
    'google_email_verified_at',
    'DATETIME NULL AFTER google_sub'
);
google_auth_expand_avatar_20260718($pdo, $users);
google_auth_add_unique_index_20260718(
    $pdo,
    $users,
    'unique_users_google_sub',
    '(google_sub)'
);

echo "2026_07_18_google_auth ok\n";

function google_auth_add_column_20260718(
    PDO $pdo,
    string $table,
    string $column,
    string $definition
): void {
    $stmt = $pdo->prepare(
        'SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
         WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ?'
    );
    $stmt->execute([$table, $column]);
    if ((int)$stmt->fetchColumn() === 0) {
        $pdo->exec("ALTER TABLE {$table} ADD COLUMN {$column} {$definition}");
    }
}

function google_auth_expand_avatar_20260718(PDO $pdo, string $table): void
{
    $stmt = $pdo->prepare(
        'SELECT CHARACTER_MAXIMUM_LENGTH, IS_NULLABLE
         FROM INFORMATION_SCHEMA.COLUMNS
         WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ?
         LIMIT 1'
    );
    $stmt->execute([$table, 'avatar']);
    $column = $stmt->fetch();
    if (!$column) {
        return;
    }
    if ((int)$column['CHARACTER_MAXIMUM_LENGTH'] < 500 || $column['IS_NULLABLE'] !== 'YES') {
        $pdo->exec("ALTER TABLE {$table} MODIFY avatar VARCHAR(500) NULL");
    }
}

function google_auth_add_unique_index_20260718(
    PDO $pdo,
    string $table,
    string $index,
    string $columns
): void {
    $stmt = $pdo->prepare(
        'SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS
         WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND INDEX_NAME = ?'
    );
    $stmt->execute([$table, $index]);
    if ((int)$stmt->fetchColumn() === 0) {
        $pdo->exec("ALTER TABLE {$table} ADD UNIQUE INDEX {$index} {$columns}");
    }
}
