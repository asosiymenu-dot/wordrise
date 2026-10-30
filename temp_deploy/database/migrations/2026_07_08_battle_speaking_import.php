<?php

require_once __DIR__ . '/../../config/database.php';

$pdo = Database::connection();
$lessons = Database::table('lessons');
$users = Database::table('users');
$words = Database::table('words');
$rooms = Database::table('battle_rooms');
$questions = Database::table('battle_questions');
$answers = Database::table('battle_answers');

if (!has_column($pdo, $lessons, 'source_lesson_id')) {
    $pdo->exec("ALTER TABLE {$lessons} ADD COLUMN source_lesson_id INT UNSIGNED NULL AFTER category");
}
if (!has_index($pdo, $lessons, 'unique_user_source_lesson')) {
    $pdo->exec("ALTER TABLE {$lessons} ADD UNIQUE KEY unique_user_source_lesson (user_id, source_lesson_id)");
}

$pdo->exec("CREATE TABLE IF NOT EXISTS {$rooms} (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  room_code VARCHAR(10) NOT NULL UNIQUE,
  creator_id INT UNSIGNED NOT NULL,
  opponent_id INT UNSIGNED NULL,
  lesson_id INT UNSIGNED NULL,
  status ENUM('waiting', 'active', 'finished', 'cancelled') NOT NULL DEFAULT 'waiting',
  direction ENUM('eng_to_uz', 'uz_to_eng') NOT NULL DEFAULT 'eng_to_uz',
  question_limit INT UNSIGNED NOT NULL DEFAULT 10,
  duration_seconds INT UNSIGNED NOT NULL DEFAULT 90,
  started_at DATETIME NULL,
  finished_at DATETIME NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (creator_id) REFERENCES {$users}(id) ON DELETE CASCADE,
  FOREIGN KEY (opponent_id) REFERENCES {$users}(id) ON DELETE SET NULL,
  FOREIGN KEY (lesson_id) REFERENCES {$lessons}(id) ON DELETE SET NULL,
  INDEX idx_battle_code (room_code),
  INDEX idx_battle_creator (creator_id, created_at),
  INDEX idx_battle_opponent (opponent_id, created_at),
  INDEX idx_battle_status (status, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");

$pdo->exec("CREATE TABLE IF NOT EXISTS {$questions} (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  battle_id BIGINT UNSIGNED NOT NULL,
  word_id INT UNSIGNED NOT NULL,
  prompt VARCHAR(255) NOT NULL,
  correct_answer VARCHAR(255) NOT NULL,
  options JSON NOT NULL,
  order_index INT UNSIGNED NOT NULL DEFAULT 0,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (battle_id) REFERENCES {$rooms}(id) ON DELETE CASCADE,
  FOREIGN KEY (word_id) REFERENCES {$words}(id) ON DELETE CASCADE,
  UNIQUE KEY unique_battle_word (battle_id, word_id),
  INDEX idx_battle_questions_order (battle_id, order_index)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");

$pdo->exec("CREATE TABLE IF NOT EXISTS {$answers} (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  battle_id BIGINT UNSIGNED NOT NULL,
  question_id BIGINT UNSIGNED NOT NULL,
  user_id INT UNSIGNED NOT NULL,
  given_answer VARCHAR(255) NOT NULL,
  is_correct TINYINT(1) NOT NULL DEFAULT 0,
  answered_ms INT UNSIGNED NOT NULL DEFAULT 0,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (battle_id) REFERENCES {$rooms}(id) ON DELETE CASCADE,
  FOREIGN KEY (question_id) REFERENCES {$questions}(id) ON DELETE CASCADE,
  FOREIGN KEY (user_id) REFERENCES {$users}(id) ON DELETE CASCADE,
  UNIQUE KEY unique_battle_user_question (battle_id, user_id, question_id),
  INDEX idx_battle_answers_score (battle_id, user_id, is_correct)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");

echo "2026_07_08_battle_speaking_import ok\n";

function has_column(PDO $pdo, string $table, string $column): bool
{
    $stmt = $pdo->prepare(
        "SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
         WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ?"
    );
    $stmt->execute([$table, $column]);
    return (int)$stmt->fetchColumn() > 0;
}

function has_index(PDO $pdo, string $table, string $index): bool
{
    $stmt = $pdo->prepare(
        "SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS
         WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND INDEX_NAME = ?"
    );
    $stmt->execute([$table, $index]);
    return (int)$stmt->fetchColumn() > 0;
}
