<?php

require_once __DIR__ . '/../../config/database.php';

$pdo = Database::connection();
$users = Database::table('users');
$words = Database::table('words');
$lessons = Database::table('lessons');
$messages = Database::table('messages');
$rooms = Database::table('battle_rooms');
$answers = Database::table('battle_answers');
$progress = Database::table('user_word_progress');
$settings = Database::table('user_learning_settings');
$sessions = Database::table('smart_learn_sessions');
$items = Database::table('smart_learn_session_items');
$invites = Database::table('battle_invites');
$notifications = Database::table('notifications');

$pdo->exec("CREATE TABLE IF NOT EXISTS {$progress} (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id INT UNSIGNED NOT NULL,
  word_id INT UNSIGNED NOT NULL,
  status ENUM('new', 'learning', 'review', 'mastered') NOT NULL DEFAULT 'new',
  correct_count INT UNSIGNED NOT NULL DEFAULT 0,
  wrong_count INT UNSIGNED NOT NULL DEFAULT 0,
  lapse_count INT UNSIGNED NOT NULL DEFAULT 0,
  consecutive_correct INT UNSIGNED NOT NULL DEFAULT 0,
  ease_factor DECIMAL(4,2) NOT NULL DEFAULT 2.50,
  review_interval INT UNSIGNED NOT NULL DEFAULT 0,
  next_review_at DATETIME NULL,
  last_answer_ms INT UNSIGNED NULL,
  average_answer_ms INT UNSIGNED NULL,
  difficulty_score DECIMAL(5,2) NOT NULL DEFAULT 1.00,
  last_reviewed_at DATETIME NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES {$users}(id) ON DELETE CASCADE,
  FOREIGN KEY (word_id) REFERENCES {$words}(id) ON DELETE CASCADE,
  UNIQUE KEY unique_user_word_progress (user_id, word_id),
  INDEX idx_progress_due (user_id, next_review_at, status),
  INDEX idx_progress_weak (user_id, difficulty_score, wrong_count),
  INDEX idx_progress_word (word_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");

$pdo->exec("CREATE TABLE IF NOT EXISTS {$settings} (
  user_id INT UNSIGNED PRIMARY KEY,
  daily_goal_minutes TINYINT UNSIGNED NOT NULL DEFAULT 10,
  preferred_direction ENUM('eng_to_uz', 'uz_to_eng', 'mixed') NOT NULL DEFAULT 'mixed',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES {$users}(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");

$pdo->exec("CREATE TABLE IF NOT EXISTS {$sessions} (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id INT UNSIGNED NOT NULL,
  status ENUM('active', 'completed', 'abandoned') NOT NULL DEFAULT 'active',
  daily_goal_minutes TINYINT UNSIGNED NOT NULL DEFAULT 10,
  direction ENUM('eng_to_uz', 'uz_to_eng', 'mixed') NOT NULL DEFAULT 'mixed',
  planned_count INT UNSIGNED NOT NULL DEFAULT 0,
  answered_count INT UNSIGNED NOT NULL DEFAULT 0,
  correct_count INT UNSIGNED NOT NULL DEFAULT 0,
  wrong_count INT UNSIGNED NOT NULL DEFAULT 0,
  earned_xp INT UNSIGNED NOT NULL DEFAULT 0,
  started_at DATETIME NOT NULL,
  last_activity_at DATETIME NOT NULL,
  completed_at DATETIME NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES {$users}(id) ON DELETE CASCADE,
  INDEX idx_smart_session_resume (user_id, status, last_activity_at),
  INDEX idx_smart_session_day (user_id, started_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");

$pdo->exec("CREATE TABLE IF NOT EXISTS {$items} (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  session_id BIGINT UNSIGNED NOT NULL,
  word_id INT UNSIGNED NOT NULL,
  position INT UNSIGNED NOT NULL,
  source_bucket ENUM('due', 'weak', 'new', 'mature', 'retry', 'final_retry') NOT NULL,
  direction ENUM('eng_to_uz', 'uz_to_eng') NOT NULL,
  mode ENUM('choice', 'typing') NOT NULL DEFAULT 'choice',
  attempt_no TINYINT UNSIGNED NOT NULL DEFAULT 1,
  status ENUM('pending', 'answered', 'skipped') NOT NULL DEFAULT 'pending',
  given_answer VARCHAR(255) NULL,
  is_correct TINYINT(1) NULL,
  answer_ms INT UNSIGNED NULL,
  answered_at DATETIME NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (session_id) REFERENCES {$sessions}(id) ON DELETE CASCADE,
  FOREIGN KEY (word_id) REFERENCES {$words}(id) ON DELETE CASCADE,
  INDEX idx_smart_item_next (session_id, status, position, id),
  INDEX idx_smart_item_word (session_id, word_id, attempt_no)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");

if (!has_column_20260715($pdo, $messages, 'message_type')) {
    $pdo->exec("ALTER TABLE {$messages} ADD COLUMN message_type VARCHAR(32) NOT NULL DEFAULT 'text' AFTER body");
}
if (!has_column_20260715($pdo, $messages, 'metadata_json')) {
    $pdo->exec("ALTER TABLE {$messages} ADD COLUMN metadata_json JSON NULL AFTER message_type");
}
if (!has_index_20260715($pdo, $messages, 'idx_messages_type')) {
    $pdo->exec("ALTER TABLE {$messages} ADD INDEX idx_messages_type (message_type, created_at)");
}

if (!has_column_20260715($pdo, $rooms, 'invited_user_id')) {
    $pdo->exec("ALTER TABLE {$rooms} ADD COLUMN invited_user_id INT UNSIGNED NULL AFTER opponent_id");
}
if (!has_column_20260715($pdo, $rooms, 'starts_at')) {
    $pdo->exec("ALTER TABLE {$rooms} ADD COLUMN starts_at DATETIME NULL AFTER duration_seconds");
}
if (!has_column_20260715($pdo, $rooms, 'rematch_of_id')) {
    $pdo->exec("ALTER TABLE {$rooms} ADD COLUMN rematch_of_id BIGINT UNSIGNED NULL AFTER starts_at");
}
if (!has_column_20260715($pdo, $rooms, 'finished_reason')) {
    $pdo->exec("ALTER TABLE {$rooms} ADD COLUMN finished_reason VARCHAR(40) NULL AFTER finished_at");
}
if (!has_column_20260715($pdo, $rooms, 'version')) {
    $pdo->exec("ALTER TABLE {$rooms} ADD COLUMN version INT UNSIGNED NOT NULL DEFAULT 1 AFTER finished_reason");
}
if (!has_index_20260715($pdo, $rooms, 'idx_battle_invited')) {
    $pdo->exec("ALTER TABLE {$rooms} ADD INDEX idx_battle_invited (invited_user_id, status, created_at)");
}
if (!has_constraint_20260715($pdo, $rooms, 'fk_battle_invited_user')) {
    $pdo->exec(
        "ALTER TABLE {$rooms} ADD CONSTRAINT fk_battle_invited_user
         FOREIGN KEY (invited_user_id) REFERENCES {$users}(id) ON DELETE SET NULL"
    );
}
if (!has_constraint_20260715($pdo, $rooms, 'fk_battle_rematch')) {
    $pdo->exec(
        "ALTER TABLE {$rooms} ADD CONSTRAINT fk_battle_rematch
         FOREIGN KEY (rematch_of_id) REFERENCES {$rooms}(id) ON DELETE SET NULL"
    );
}

if (!has_column_20260715($pdo, $answers, 'client_answer_ms')) {
    $pdo->exec("ALTER TABLE {$answers} ADD COLUMN client_answer_ms INT UNSIGNED NULL AFTER answered_ms");
}

$pdo->exec("CREATE TABLE IF NOT EXISTS {$invites} (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  battle_id BIGINT UNSIGNED NOT NULL,
  message_id BIGINT UNSIGNED NULL,
  sender_id INT UNSIGNED NOT NULL,
  receiver_id INT UNSIGNED NOT NULL,
  status ENUM('pending', 'accepted', 'declined', 'cancelled', 'expired') NOT NULL DEFAULT 'pending',
  expires_at DATETIME NOT NULL,
  responded_at DATETIME NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (battle_id) REFERENCES {$rooms}(id) ON DELETE CASCADE,
  FOREIGN KEY (message_id) REFERENCES {$messages}(id) ON DELETE SET NULL,
  FOREIGN KEY (sender_id) REFERENCES {$users}(id) ON DELETE CASCADE,
  FOREIGN KEY (receiver_id) REFERENCES {$users}(id) ON DELETE CASCADE,
  UNIQUE KEY unique_battle_invite (battle_id),
  INDEX idx_invite_receiver (receiver_id, status, expires_at),
  INDEX idx_invite_sender (sender_id, status, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");

$pdo->exec("CREATE TABLE IF NOT EXISTS {$notifications} (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id INT UNSIGNED NOT NULL,
  type VARCHAR(40) NOT NULL,
  title VARCHAR(160) NOT NULL,
  body VARCHAR(500) NOT NULL,
  data_json JSON NULL,
  read_at DATETIME NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES {$users}(id) ON DELETE CASCADE,
  INDEX idx_notifications_unread (user_id, read_at, id),
  INDEX idx_notifications_created (user_id, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");

echo "2026_07_15_smart_learn_battle_invites ok\n";

function has_column_20260715(PDO $pdo, string $table, string $column): bool
{
    $stmt = $pdo->prepare(
        "SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
         WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ?"
    );
    $stmt->execute([$table, $column]);
    return (int)$stmt->fetchColumn() > 0;
}

function has_index_20260715(PDO $pdo, string $table, string $index): bool
{
    $stmt = $pdo->prepare(
        "SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS
         WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND INDEX_NAME = ?"
    );
    $stmt->execute([$table, $index]);
    return (int)$stmt->fetchColumn() > 0;
}

function has_constraint_20260715(PDO $pdo, string $table, string $constraint): bool
{
    $stmt = $pdo->prepare(
        "SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS
         WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND CONSTRAINT_NAME = ?"
    );
    $stmt->execute([$table, $constraint]);
    return (int)$stmt->fetchColumn() > 0;
}
