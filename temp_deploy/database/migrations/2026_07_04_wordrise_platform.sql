ALTER TABLE users
  ADD COLUMN IF NOT EXISTS english_level VARCHAR(4) NOT NULL DEFAULT 'A1' AFTER avatar;

ALTER TABLE lessons
  ADD COLUMN IF NOT EXISTS share_code VARCHAR(12) NULL UNIQUE AFTER category,
  ADD COLUMN IF NOT EXISTS is_public TINYINT(1) NOT NULL DEFAULT 0 AFTER share_code,
  ADD COLUMN IF NOT EXISTS import_count INT UNSIGNED NOT NULL DEFAULT 0 AFTER is_public,
  ADD INDEX IF NOT EXISTS idx_lessons_public (is_public, import_count, created_at),
  ADD INDEX IF NOT EXISTS idx_lessons_share_code (share_code);

ALTER TABLE words
  ADD COLUMN IF NOT EXISTS next_review_at DATETIME NULL AFTER pronunciation,
  ADD COLUMN IF NOT EXISTS review_interval INT UNSIGNED NOT NULL DEFAULT 0 AFTER next_review_at,
  ADD COLUMN IF NOT EXISTS ease_factor DECIMAL(4,2) NOT NULL DEFAULT 2.50 AFTER review_interval,
  ADD INDEX IF NOT EXISTS idx_words_review (next_review_at);

CREATE TABLE IF NOT EXISTS grammar_lessons (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  title VARCHAR(160) NOT NULL,
  level VARCHAR(4) NOT NULL DEFAULT 'A1',
  content MEDIUMTEXT NOT NULL,
  sort_order INT UNSIGNED NOT NULL DEFAULT 0,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_grammar_level (level, sort_order)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS grammar_exercises (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  lesson_id INT UNSIGNED NOT NULL,
  question TEXT NOT NULL,
  options JSON NULL,
  correct_answer VARCHAR(255) NOT NULL,
  explanation TEXT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (lesson_id) REFERENCES grammar_lessons(id) ON DELETE CASCADE,
  INDEX idx_grammar_exercises_lesson (lesson_id)
) ENGINE=InnoDB;

INSERT IGNORE INTO grammar_lessons (id, title, level, content, sort_order) VALUES
  (1, 'Present Simple', 'A1', 'Present Simple odat, har kuni takrorlanadigan ishlar va umumiy haqiqatlar uchun ishlatiladi. I/you/we/they bilan feʼl oddiy shaklda keladi: I study English. He/she/it bilan feʼlga -s yoki -es qoʼshiladi: She studies English.', 10),
  (2, 'Past Simple', 'A2', 'Past Simple oʼtmishda tugagan ish-harakatlar uchun ishlatiladi. Regular feʼllarga -ed qoʼshiladi: worked, played. Irregular feʼllar alohida yodlanadi: go - went, see - saw.', 20),
  (3, 'Present Perfect', 'B1', 'Present Perfect oʼtmishda boshlangan va hozirga bogʼliq natijasi bor holatlar uchun ishlatiladi. Tuzilishi: have/has + V3. Masalan: I have finished my homework.', 30);

INSERT IGNORE INTO grammar_exercises (id, lesson_id, question, options, correct_answer, explanation) VALUES
  (1, 1, 'She ____ English every day.', JSON_ARRAY('study', 'studies', 'studied', 'studying'), 'studies', 'He/she/it bilan Present Simpleda feʼlga -s/-es qoʼshiladi.'),
  (2, 2, 'Yesterday I ____ to school.', JSON_ARRAY('go', 'went', 'gone', 'going'), 'went', 'Yesterday oʼtmish vaqt, go feʼlining Past Simple shakli went.'),
  (3, 3, 'I ____ already finished the task.', JSON_ARRAY('has', 'have', 'am', 'did'), 'have', 'I bilan Present Perfectda have ishlatiladi.');
