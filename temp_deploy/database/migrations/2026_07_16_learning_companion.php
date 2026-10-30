<?php

require_once __DIR__ . '/../../config/database.php';

$pdo = Database::connection();
$users = Database::table('users');
$words = Database::table('words');
$progress = Database::table('user_word_progress');
$settings = Database::table('user_learning_settings');
$deviceTokens = Database::table('device_tokens');
$offlineEvents = Database::table('offline_review_events');
$dispatchLog = Database::table('notification_dispatch_log');

if (!has_column_20260716($pdo, $users, 'streak_freezes')) {
    $pdo->exec("ALTER TABLE {$users} ADD COLUMN streak_freezes TINYINT UNSIGNED NOT NULL DEFAULT 1 AFTER streak");
}
if (!has_column_20260716($pdo, $users, 'last_streak_freeze_at')) {
    $pdo->exec("ALTER TABLE {$users} ADD COLUMN last_streak_freeze_at DATE NULL AFTER last_active_date");
}
if (!has_column_20260716($pdo, $progress, 'is_starred')) {
    $pdo->exec("ALTER TABLE {$progress} ADD COLUMN is_starred TINYINT(1) NOT NULL DEFAULT 0 AFTER status");
}
if (!has_index_20260716($pdo, $progress, 'idx_progress_starred')) {
    $pdo->exec("ALTER TABLE {$progress} ADD INDEX idx_progress_starred (user_id, is_starred, updated_at)");
}

$settingColumns = [
    'reminder_enabled' => "TINYINT(1) NOT NULL DEFAULT 0",
    'reminder_hour' => "TINYINT UNSIGNED NOT NULL DEFAULT 19",
    'reminder_minute' => "TINYINT UNSIGNED NOT NULL DEFAULT 0",
    'streak_risk_enabled' => "TINYINT(1) NOT NULL DEFAULT 1",
    'streak_risk_hour' => "TINYINT UNSIGNED NOT NULL DEFAULT 21",
    'streak_risk_minute' => "TINYINT UNSIGNED NOT NULL DEFAULT 0",
    'timezone' => "VARCHAR(64) NOT NULL DEFAULT 'Asia/Tashkent'",
];
foreach ($settingColumns as $column => $definition) {
    if (!has_column_20260716($pdo, $settings, $column)) {
        $pdo->exec("ALTER TABLE {$settings} ADD COLUMN {$column} {$definition}");
    }
}

$pdo->exec("CREATE TABLE IF NOT EXISTS {$deviceTokens} (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id INT UNSIGNED NOT NULL,
  token VARCHAR(512) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  platform ENUM('android', 'ios', 'web', 'unknown') NOT NULL DEFAULT 'unknown',
  locale VARCHAR(8) NOT NULL DEFAULT 'uz',
  active TINYINT(1) NOT NULL DEFAULT 1,
  last_seen_at DATETIME NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES {$users}(id) ON DELETE CASCADE,
  UNIQUE KEY unique_device_token (token),
  INDEX idx_device_user_active (user_id, active, last_seen_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");
$pdo->exec("ALTER TABLE {$deviceTokens} MODIFY token VARCHAR(512) CHARACTER SET ascii COLLATE ascii_bin NOT NULL");

$pdo->exec("CREATE TABLE IF NOT EXISTS {$offlineEvents} (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id INT UNSIGNED NOT NULL,
  word_id INT UNSIGNED NOT NULL,
  client_event_id VARCHAR(64) NOT NULL,
  given_answer VARCHAR(255) NOT NULL,
  direction ENUM('eng_to_uz', 'uz_to_eng') NOT NULL,
  answer_ms INT UNSIGNED NOT NULL DEFAULT 0,
  is_correct TINYINT(1) NOT NULL,
  earned_xp INT UNSIGNED NOT NULL DEFAULT 0,
  answered_at DATETIME NOT NULL,
  synced_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES {$users}(id) ON DELETE CASCADE,
  FOREIGN KEY (word_id) REFERENCES {$words}(id) ON DELETE CASCADE,
  UNIQUE KEY unique_offline_event (user_id, client_event_id),
  INDEX idx_offline_events_word (user_id, word_id, answered_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");

$pdo->exec("CREATE TABLE IF NOT EXISTS {$dispatchLog} (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id INT UNSIGNED NOT NULL,
  notification_type ENUM('daily_reminder', 'streak_risk') NOT NULL,
  local_date DATE NOT NULL,
  sent_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES {$users}(id) ON DELETE CASCADE,
  UNIQUE KEY unique_notification_dispatch (user_id, notification_type, local_date),
  INDEX idx_dispatch_date (local_date, notification_type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");

echo "2026_07_16_learning_companion ok\n";

function has_column_20260716(PDO $pdo, string $table, string $column): bool
{
    $stmt = $pdo->prepare(
        "SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
         WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ?"
    );
    $stmt->execute([$table, $column]);
    return (int)$stmt->fetchColumn() > 0;
}

function has_index_20260716(PDO $pdo, string $table, string $index): bool
{
    $stmt = $pdo->prepare(
        "SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS
         WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND INDEX_NAME = ?"
    );
    $stmt->execute([$table, $index]);
    return (int)$stmt->fetchColumn() > 0;
}
