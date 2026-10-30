<?php

require_once __DIR__ . '/../../config/database.php';

$pdo = Database::connection();
$users = Database::table('users');
$releases = Database::table('app_releases');

update_add_column_20260718(
    $pdo,
    $users,
    'typing_to_user_id',
    'INT UNSIGNED NULL AFTER last_seen_at'
);
update_add_column_20260718(
    $pdo,
    $users,
    'typing_expires_at',
    'DATETIME NULL AFTER typing_to_user_id'
);
update_add_index_20260718(
    $pdo,
    $users,
    'idx_users_typing',
    '(typing_to_user_id, typing_expires_at)'
);
update_add_foreign_key_20260718(
    $pdo,
    $users,
    update_fk_name_20260718($users, 'typing_to'),
    'typing_to_user_id',
    $users,
    'id',
    'SET NULL'
);

$pdo->exec("CREATE TABLE IF NOT EXISTS {$releases} (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  platform VARCHAR(16) NOT NULL,
  version_name VARCHAR(32) NOT NULL,
  version_code INT UNSIGNED NOT NULL,
  min_supported_version_code INT UNSIGNED NOT NULL DEFAULT 1,
  download_url VARCHAR(500) NOT NULL,
  release_notes_uz TEXT NULL,
  release_notes_en TEXT NULL,
  release_notes_ru TEXT NULL,
  sha256 CHAR(64) NULL,
  file_size_bytes BIGINT UNSIGNED NULL,
  is_required TINYINT(1) NOT NULL DEFAULT 1,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  published_at DATETIME NOT NULL,
  created_by INT UNSIGNED NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY unique_app_release_version (platform, version_code),
  INDEX idx_app_releases_latest (platform, is_active, version_code),
  INDEX idx_app_releases_published (published_at),
  CONSTRAINT " . update_fk_name_20260718($releases, 'created_by') . "
    FOREIGN KEY (created_by) REFERENCES {$users}(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");

echo "2026_07_18_typing_forced_update ok\n";

function update_add_column_20260718(
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

function update_add_index_20260718(
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
        $pdo->exec("ALTER TABLE {$table} ADD INDEX {$index} {$columns}");
    }
}

function update_add_foreign_key_20260718(
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

function update_fk_name_20260718(string $table, string $suffix): string
{
    return substr(
        'fk_' . preg_replace('/[^A-Za-z0-9_]/', '_', $table) . '_' . $suffix,
        0,
        64
    );
}
