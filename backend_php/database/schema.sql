CREATE DATABASE IF NOT EXISTS wordrise
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE wordrise;

CREATE TABLE IF NOT EXISTS users (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(120) NOT NULL,
  username VARCHAR(80) NOT NULL UNIQUE,
  email VARCHAR(160) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  avatar VARCHAR(255) NULL,
  english_level VARCHAR(4) NOT NULL DEFAULT 'A1',
  role ENUM('student', 'teacher', 'admin') NOT NULL DEFAULT 'student',
  xp INT UNSIGNED NOT NULL DEFAULT 0,
  level INT UNSIGNED NOT NULL DEFAULT 1,
  streak INT UNSIGNED NOT NULL DEFAULT 0,
  streak_freezes TINYINT UNSIGNED NOT NULL DEFAULT 1,
  last_active_date DATE NULL,
  last_seen_at DATETIME NULL,
  typing_to_user_id INT UNSIGNED NULL,
  typing_expires_at DATETIME NULL,
  last_streak_freeze_at DATE NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_users_xp (xp),
  INDEX idx_users_role (role),
  INDEX idx_users_last_seen (last_seen_at),
  INDEX idx_users_typing (typing_to_user_id, typing_expires_at),
  FOREIGN KEY (typing_to_user_id) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS api_tokens (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id INT UNSIGNED NOT NULL,
  token_hash CHAR(64) NOT NULL UNIQUE,
  expires_at DATETIME NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  INDEX idx_api_tokens_user (user_id),
  INDEX idx_api_tokens_expires (expires_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS auth_rate_limits (
  scope VARCHAR(32) NOT NULL,
  fingerprint CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  attempts SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  window_started_at DATETIME NOT NULL,
  blocked_until DATETIME NULL,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (scope, fingerprint),
  INDEX idx_auth_rate_blocked (blocked_until)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS app_releases (
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
  FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS legacy_import_map (
  source_key VARCHAR(100) NOT NULL,
  entity VARCHAR(40) NOT NULL,
  legacy_id BIGINT UNSIGNED NOT NULL,
  target_id BIGINT UNSIGNED NOT NULL,
  imported_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (source_key, entity, legacy_id),
  INDEX idx_legacy_target (entity, target_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS lessons (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id INT UNSIGNED NOT NULL,
  title VARCHAR(160) NOT NULL,
  description TEXT NULL,
  category VARCHAR(100) NOT NULL DEFAULT 'General',
  source_lesson_id INT UNSIGNED NULL,
  share_code VARCHAR(12) NULL UNIQUE,
  is_public TINYINT(1) NOT NULL DEFAULT 0,
  import_count INT UNSIGNED NOT NULL DEFAULT 0,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  INDEX idx_lessons_user (user_id),
  INDEX idx_lessons_category (category),
  INDEX idx_lessons_public (is_public, import_count, created_at),
  INDEX idx_lessons_share_code (share_code),
  UNIQUE KEY unique_user_source_lesson (user_id, source_lesson_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS words (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  lesson_id INT UNSIGNED NOT NULL,
  english_word VARCHAR(120) NOT NULL,
  uzbek_translation VARCHAR(160) NOT NULL,
  example_sentence VARCHAR(255) NULL,
  pronunciation VARCHAR(120) NULL,
  next_review_at DATETIME NULL,
  review_interval INT UNSIGNED NOT NULL DEFAULT 0,
  ease_factor DECIMAL(4,2) NOT NULL DEFAULT 2.50,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (lesson_id) REFERENCES lessons(id) ON DELETE CASCADE,
  UNIQUE KEY unique_lesson_word (lesson_id, english_word),
  INDEX idx_words_lesson (lesson_id),
  INDEX idx_words_review (next_review_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS user_word_progress (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id INT UNSIGNED NOT NULL,
  word_id INT UNSIGNED NOT NULL,
  status ENUM('new', 'learning', 'review', 'mastered') NOT NULL DEFAULT 'new',
  is_starred TINYINT(1) NOT NULL DEFAULT 0,
  correct_count INT UNSIGNED NOT NULL DEFAULT 0,
  is_learned TINYINT(1) NOT NULL DEFAULT 0,
  wrong_count INT UNSIGNED NOT NULL DEFAULT 0,
  is_difficult TINYINT(1) NOT NULL DEFAULT 0,
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
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (word_id) REFERENCES words(id) ON DELETE CASCADE,
  UNIQUE KEY unique_user_word_progress (user_id, word_id),
  INDEX idx_progress_due (user_id, next_review_at, status),
  INDEX idx_progress_weak (user_id, difficulty_score, wrong_count),
  INDEX idx_progress_starred (user_id, is_starred, updated_at),
  INDEX idx_progress_word (word_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS user_learning_settings (
  user_id INT UNSIGNED PRIMARY KEY,
  daily_goal_minutes TINYINT UNSIGNED NOT NULL DEFAULT 10,
  preferred_direction ENUM('eng_to_uz', 'uz_to_eng', 'mixed') NOT NULL DEFAULT 'mixed',
  reminder_enabled TINYINT(1) NOT NULL DEFAULT 0,
  reminder_hour TINYINT UNSIGNED NOT NULL DEFAULT 19,
  reminder_minute TINYINT UNSIGNED NOT NULL DEFAULT 0,
  streak_risk_enabled TINYINT(1) NOT NULL DEFAULT 1,
  streak_risk_hour TINYINT UNSIGNED NOT NULL DEFAULT 21,
  streak_risk_minute TINYINT UNSIGNED NOT NULL DEFAULT 0,
  timezone VARCHAR(64) NOT NULL DEFAULT 'Asia/Tashkent',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS smart_learn_sessions (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id INT UNSIGNED NOT NULL,
  status ENUM('active', 'completed', 'abandoned') NOT NULL DEFAULT 'active',
  daily_goal_minutes TINYINT UNSIGNED NOT NULL DEFAULT 10,
  direction ENUM('eng_to_uz', 'uz_to_eng', 'mixed') NOT NULL DEFAULT 'mixed',
  planned_count INT UNSIGNED NOT NULL DEFAULT 0,
  answered_count INT UNSIGNED NOT NULL DEFAULT 0,
  correct_count INT UNSIGNED NOT NULL DEFAULT 0,
  is_learned TINYINT(1) NOT NULL DEFAULT 0,
  wrong_count INT UNSIGNED NOT NULL DEFAULT 0,
  is_difficult TINYINT(1) NOT NULL DEFAULT 0,
  earned_xp INT UNSIGNED NOT NULL DEFAULT 0,
  started_at DATETIME NOT NULL,
  last_activity_at DATETIME NOT NULL,
  completed_at DATETIME NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  INDEX idx_smart_session_resume (user_id, status, last_activity_at),
  INDEX idx_smart_session_day (user_id, started_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS smart_learn_session_items (
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
  FOREIGN KEY (session_id) REFERENCES smart_learn_sessions(id) ON DELETE CASCADE,
  FOREIGN KEY (word_id) REFERENCES words(id) ON DELETE CASCADE,
  INDEX idx_smart_item_next (session_id, status, position, id),
  INDEX idx_smart_item_word (session_id, word_id, attempt_no)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS quiz_results (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id INT UNSIGNED NOT NULL,
  lesson_id INT UNSIGNED NOT NULL,
  mode VARCHAR(40) NOT NULL,
  correct_count INT UNSIGNED NOT NULL DEFAULT 0,
  is_learned TINYINT(1) NOT NULL DEFAULT 0,
  wrong_count INT UNSIGNED NOT NULL DEFAULT 0,
  is_difficult TINYINT(1) NOT NULL DEFAULT 0,
  earned_xp INT UNSIGNED NOT NULL DEFAULT 0,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (lesson_id) REFERENCES lessons(id) ON DELETE CASCADE,
  INDEX idx_quiz_user_created (user_id, created_at),
  INDEX idx_quiz_lesson (lesson_id),
  INDEX idx_quiz_created (created_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS quiz_result_answers (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  quiz_result_id BIGINT UNSIGNED NOT NULL,
  word_id INT UNSIGNED NOT NULL,
  given_answer VARCHAR(255) NOT NULL,
  is_correct TINYINT(1) NOT NULL DEFAULT 0,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (quiz_result_id) REFERENCES quiz_results(id) ON DELETE CASCADE,
  FOREIGN KEY (word_id) REFERENCES words(id) ON DELETE CASCADE,
  INDEX idx_answers_result (quiz_result_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS mistakes (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id INT UNSIGNED NOT NULL,
  word_id INT UNSIGNED NOT NULL,
  mistake_count INT UNSIGNED NOT NULL DEFAULT 1,
  last_mistake_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (word_id) REFERENCES words(id) ON DELETE CASCADE,
  UNIQUE KEY unique_user_word_mistake (user_id, word_id),
  INDEX idx_mistakes_user (user_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS badges (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  title VARCHAR(120) NOT NULL,
  description VARCHAR(255) NOT NULL,
  icon VARCHAR(80) NOT NULL,
  required_condition VARCHAR(120) NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS user_badges (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id INT UNSIGNED NOT NULL,
  badge_id INT UNSIGNED NOT NULL,
  earned_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (badge_id) REFERENCES badges(id) ON DELETE CASCADE,
  UNIQUE KEY unique_user_badge (user_id, badge_id),
  INDEX idx_user_badges_user (user_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS messages (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  sender_id INT UNSIGNED NOT NULL,
  receiver_id INT UNSIGNED NOT NULL,
  body TEXT NOT NULL,
  client_message_id VARCHAR(64) NULL,
  message_type VARCHAR(32) NOT NULL DEFAULT 'text',
  metadata_json JSON NULL,
  delivered_at DATETIME NULL,
  read_at DATETIME NULL,
  edited_at DATETIME NULL,
  deleted_for_everyone_at DATETIME NULL,
  deleted_for_everyone_by INT UNSIGNED NULL,
  reply_to_message_id BIGINT UNSIGNED NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (sender_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (receiver_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (deleted_for_everyone_by) REFERENCES users(id) ON DELETE SET NULL,
  FOREIGN KEY (reply_to_message_id) REFERENCES messages(id) ON DELETE SET NULL,
  UNIQUE KEY unique_sender_client_message (sender_id, client_message_id),
  INDEX idx_messages_sender_receiver (sender_id, receiver_id, created_at),
  INDEX idx_messages_sender_receiver_id (sender_id, receiver_id, id),
  INDEX idx_messages_receiver_read (receiver_id, read_at),
  INDEX idx_messages_receiver_delivered (receiver_id, delivered_at, id),
  INDEX idx_messages_reply (reply_to_message_id),
  INDEX idx_messages_updated (updated_at, id),
  INDEX idx_messages_type (message_type, created_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS message_user_deletions (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  message_id BIGINT UNSIGNED NOT NULL,
  user_id INT UNSIGNED NOT NULL,
  deleted_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (message_id) REFERENCES messages(id) ON DELETE CASCADE,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  UNIQUE KEY unique_message_user_deletion (message_id, user_id),
  INDEX idx_message_deletions_user (user_id, message_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS message_attachments (
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
  FOREIGN KEY (message_id) REFERENCES messages(id) ON DELETE CASCADE,
  UNIQUE KEY unique_message_attachment (message_id),
  INDEX idx_message_attachments_type (type, created_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS message_rate_limits (
  user_id INT UNSIGNED NOT NULL,
  scope VARCHAR(32) NOT NULL,
  attempts SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  window_started_at DATETIME NOT NULL,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (user_id, scope),
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  INDEX idx_message_rate_window (window_started_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS battle_rooms (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  room_code VARCHAR(10) NOT NULL UNIQUE,
  creator_id INT UNSIGNED NOT NULL,
  opponent_id INT UNSIGNED NULL,
  invited_user_id INT UNSIGNED NULL,
  lesson_id INT UNSIGNED NULL,
  status ENUM('waiting', 'active', 'finished', 'cancelled') NOT NULL DEFAULT 'waiting',
  direction ENUM('eng_to_uz', 'uz_to_eng') NOT NULL DEFAULT 'eng_to_uz',
  question_limit INT UNSIGNED NOT NULL DEFAULT 10,
  duration_seconds INT UNSIGNED NOT NULL DEFAULT 90,
  starts_at DATETIME NULL,
  rematch_of_id BIGINT UNSIGNED NULL,
  started_at DATETIME NULL,
  finished_at DATETIME NULL,
  finished_reason VARCHAR(40) NULL,
  version INT UNSIGNED NOT NULL DEFAULT 1,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (creator_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (opponent_id) REFERENCES users(id) ON DELETE SET NULL,
  FOREIGN KEY (invited_user_id) REFERENCES users(id) ON DELETE SET NULL,
  FOREIGN KEY (lesson_id) REFERENCES lessons(id) ON DELETE SET NULL,
  FOREIGN KEY (rematch_of_id) REFERENCES battle_rooms(id) ON DELETE SET NULL,
  INDEX idx_battle_code (room_code),
  INDEX idx_battle_creator (creator_id, created_at),
  INDEX idx_battle_opponent (opponent_id, created_at),
  INDEX idx_battle_invited (invited_user_id, status, created_at),
  INDEX idx_battle_status (status, created_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS battle_questions (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  battle_id BIGINT UNSIGNED NOT NULL,
  word_id INT UNSIGNED NOT NULL,
  prompt VARCHAR(255) NOT NULL,
  correct_answer VARCHAR(255) NOT NULL,
  options JSON NOT NULL,
  order_index INT UNSIGNED NOT NULL DEFAULT 0,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (battle_id) REFERENCES battle_rooms(id) ON DELETE CASCADE,
  FOREIGN KEY (word_id) REFERENCES words(id) ON DELETE CASCADE,
  UNIQUE KEY unique_battle_word (battle_id, word_id),
  INDEX idx_battle_questions_order (battle_id, order_index)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS battle_answers (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  battle_id BIGINT UNSIGNED NOT NULL,
  question_id BIGINT UNSIGNED NOT NULL,
  user_id INT UNSIGNED NOT NULL,
  given_answer VARCHAR(255) NOT NULL,
  is_correct TINYINT(1) NOT NULL DEFAULT 0,
  answered_ms INT UNSIGNED NOT NULL DEFAULT 0,
  client_answer_ms INT UNSIGNED NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (battle_id) REFERENCES battle_rooms(id) ON DELETE CASCADE,
  FOREIGN KEY (question_id) REFERENCES battle_questions(id) ON DELETE CASCADE,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  UNIQUE KEY unique_battle_user_question (battle_id, user_id, question_id),
  INDEX idx_battle_answers_score (battle_id, user_id, is_correct)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS battle_invites (
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
  FOREIGN KEY (battle_id) REFERENCES battle_rooms(id) ON DELETE CASCADE,
  FOREIGN KEY (message_id) REFERENCES messages(id) ON DELETE SET NULL,
  FOREIGN KEY (sender_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (receiver_id) REFERENCES users(id) ON DELETE CASCADE,
  UNIQUE KEY unique_battle_invite (battle_id),
  INDEX idx_invite_receiver (receiver_id, status, expires_at),
  INDEX idx_invite_sender (sender_id, status, created_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS notifications (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id INT UNSIGNED NOT NULL,
  type VARCHAR(40) NOT NULL,
  title VARCHAR(160) NOT NULL,
  body VARCHAR(500) NOT NULL,
  data_json JSON NULL,
  read_at DATETIME NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  INDEX idx_notifications_unread (user_id, read_at, id),
  INDEX idx_notifications_created (user_id, created_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS device_tokens (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id INT UNSIGNED NOT NULL,
  token VARCHAR(512) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  platform ENUM('android', 'ios', 'web', 'unknown') NOT NULL DEFAULT 'unknown',
  locale VARCHAR(8) NOT NULL DEFAULT 'uz',
  active TINYINT(1) NOT NULL DEFAULT 1,
  last_seen_at DATETIME NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  UNIQUE KEY unique_device_token (token),
  INDEX idx_device_user_active (user_id, active, last_seen_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS offline_review_events (
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
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (word_id) REFERENCES words(id) ON DELETE CASCADE,
  UNIQUE KEY unique_offline_event (user_id, client_event_id),
  INDEX idx_offline_events_word (user_id, word_id, answered_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS notification_dispatch_log (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id INT UNSIGNED NOT NULL,
  notification_type ENUM('daily_reminder', 'streak_risk') NOT NULL,
  local_date DATE NOT NULL,
  sent_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  UNIQUE KEY unique_notification_dispatch (user_id, notification_type, local_date),
  INDEX idx_dispatch_date (local_date, notification_type)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS grammar_levels (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  code VARCHAR(4) NOT NULL UNIQUE,
  title_uz VARCHAR(120) NOT NULL,
  order_index INT UNSIGNED NOT NULL DEFAULT 0,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_grammar_levels_order (order_index)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS grammar_topics (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  level_id INT UNSIGNED NOT NULL,
  title VARCHAR(160) NOT NULL,
  order_index INT UNSIGNED NOT NULL DEFAULT 0,
  icon VARCHAR(32) NULL,
  duration_minutes INT UNSIGNED NOT NULL DEFAULT 8,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (level_id) REFERENCES grammar_levels(id) ON DELETE CASCADE,
  UNIQUE KEY unique_level_topic (level_id, title),
  INDEX idx_grammar_topics_level (level_id, order_index)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS grammar_lessons (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  topic_id INT UNSIGNED NULL,
  title VARCHAR(160) NOT NULL,
  level VARCHAR(4) NOT NULL DEFAULT 'A1',
  content MEDIUMTEXT NOT NULL,
  examples_json JSON NULL,
  common_mistakes MEDIUMTEXT NULL,
  status ENUM('draft', 'published') NOT NULL DEFAULT 'published',
  sort_order INT UNSIGNED NOT NULL DEFAULT 0,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (topic_id) REFERENCES grammar_topics(id) ON DELETE SET NULL,
  UNIQUE KEY unique_grammar_lesson_topic (topic_id),
  INDEX idx_grammar_level (level, sort_order)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS grammar_exercises (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  lesson_id INT UNSIGNED NOT NULL,
  exercise_type VARCHAR(40) NOT NULL DEFAULT 'multiple_choice',
  question TEXT NOT NULL,
  options JSON NULL,
  correct_answer VARCHAR(255) NOT NULL,
  correct_answers JSON NULL,
  explanation TEXT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (lesson_id) REFERENCES grammar_lessons(id) ON DELETE CASCADE,
  INDEX idx_grammar_exercises_lesson (lesson_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS user_grammar_progress (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id INT UNSIGNED NOT NULL,
  topic_id INT UNSIGNED NOT NULL,
  progress_percent TINYINT UNSIGNED NOT NULL DEFAULT 0,
  correct_count INT UNSIGNED NOT NULL DEFAULT 0,
  is_learned TINYINT(1) NOT NULL DEFAULT 0,
  wrong_count INT UNSIGNED NOT NULL DEFAULT 0,
  is_difficult TINYINT(1) NOT NULL DEFAULT 0,
  wrong_exercise_ids JSON NULL,
  completed_at DATETIME NULL,
  last_attempt_at DATETIME NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (topic_id) REFERENCES grammar_topics(id) ON DELETE CASCADE,
  UNIQUE KEY unique_user_grammar_topic (user_id, topic_id),
  INDEX idx_user_grammar_user (user_id, progress_percent)
) ENGINE=InnoDB;

INSERT IGNORE INTO badges (id, title, description, icon, required_condition) VALUES
  (1, 'First 10 Words', 'Add or study first 10 words.', 'stars', 'words_count>=10'),
  (2, '100 Correct Answers', 'Answer 100 quiz questions correctly.', 'verified', 'correct_answers>=100'),
  (3, '7 Day Streak', 'Study seven days in a row.', 'fire', 'streak>=7'),
  (4, 'Speed Quiz Master', 'Get 10 speed answers correct in a session.', 'bolt', 'speed_correct>=10'),
  (5, 'No Mistake Round', 'Finish a round without mistakes.', 'shield', 'perfect_round=true'),
  (6, 'Top 10 Student', 'Reach top 10 in leaderboard.', 'trophy', 'rank<=10'),
  (7, 'Grammar Starter', 'Finish your first grammar practice.', 'school', 'grammar_completed>=1'),
  (8, 'Grammar Master', 'Complete a grammar level.', 'workspace_premium', 'grammar_level_complete=true');

INSERT IGNORE INTO grammar_lessons (id, title, level, content, sort_order) VALUES
  (1, 'Present Simple', 'A1', 'Present Simple odat, har kuni takrorlanadigan ishlar va umumiy haqiqatlar uchun ishlatiladi. I/you/we/they bilan feʼl oddiy shaklda keladi: I study English. He/she/it bilan feʼlga -s yoki -es qoʼshiladi: She studies English.', 10),
  (2, 'Past Simple', 'A2', 'Past Simple oʼtmishda tugagan ish-harakatlar uchun ishlatiladi. Regular feʼllarga -ed qoʼshiladi: worked, played. Irregular feʼllar alohida yodlanadi: go - went, see - saw.', 20),
  (3, 'Present Perfect', 'B1', 'Present Perfect oʼtmishda boshlangan va hozirga bogʼliq natijasi bor holatlar uchun ishlatiladi. Tuzilishi: have/has + V3. Masalan: I have finished my homework.', 30);

INSERT IGNORE INTO grammar_exercises (id, lesson_id, question, options, correct_answer, explanation) VALUES
  (1, 1, 'She ____ English every day.', JSON_ARRAY('study', 'studies', 'studied', 'studying'), 'studies', 'He/she/it bilan Present Simpleda feʼlga -s/-es qoʼshiladi.'),
  (2, 2, 'Yesterday I ____ to school.', JSON_ARRAY('go', 'went', 'gone', 'going'), 'went', 'Yesterday oʼtmish vaqt, go feʼlining Past Simple shakli went.'),
  (3, 3, 'I ____ already finished the task.', JSON_ARRAY('has', 'have', 'am', 'did'), 'have', 'I bilan Present Perfectda have ishlatiladi.');
