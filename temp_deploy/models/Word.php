<?php

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../helpers/websocket.php';
require_once __DIR__ . '/Lesson.php';

final class WordModel
{
    public static function allByLesson(int $lessonId, array $user): array
    {
        if (!Lesson::findVisible($lessonId, $user)) {
            throw new RuntimeException('Lesson not found.');
        }

        $wordsTable = Database::table('words');
        $progressTable = Database::table('user_word_progress');
        $stmt = Database::connection()->prepare(
            "SELECT w.*, COALESCE(p.is_starred, 0) AS is_starred,
                    p.status AS progress_status, p.correct_count, p.wrong_count,
                    p.lapse_count, p.ease_factor, p.review_interval,
                    p.next_review_at, p.average_answer_ms, p.difficulty_score
             FROM {$wordsTable} w
             LEFT JOIN {$progressTable} p ON p.word_id = w.id AND p.user_id = ?
             WHERE w.lesson_id = ? ORDER BY w.created_at DESC, w.id DESC"
        );
        $stmt->execute([(int)$user['id'], $lessonId]);
        return $stmt->fetchAll();
    }

    public static function findInVisibleLesson(int $wordId, array $user): ?array
    {
        $wordsTable = Database::table('words');
        $lessonsTable = Database::table('lessons');
        $stmt = Database::connection()->prepare(
            "SELECT w.*, l.user_id AS lesson_owner_id
             FROM {$wordsTable} w
             INNER JOIN {$lessonsTable} l ON l.id = w.lesson_id
             WHERE w.id = ?
             LIMIT 1"
        );
        $stmt->execute([$wordId]);
        $word = $stmt->fetch();

        if (!$word) {
            return null;
        }

        if (!Lesson::findVisible((int)$word['lesson_id'], $user)) {
            return null;
        }

        return $word;
    }

    public static function create(
        int $lessonId,
        array $user,
        string $englishWord,
        string $uzbekTranslation,
        ?string $exampleSentence,
        ?string $pronunciation
    ): array {
        $lesson = Lesson::findVisible($lessonId, $user);
        if (!$lesson) {
            throw new RuntimeException('Lesson not found.');
        }
        if ((int)$lesson['user_id'] !== (int)$user['id'] && $user['role'] !== 'admin') {
            throw new LogicException('Forbidden.');
        }

        $wordsTable = Database::table('words');
        $stmt = Database::connection()->prepare(
            "INSERT INTO {$wordsTable} (lesson_id, english_word, uzbek_translation, example_sentence, pronunciation)
             VALUES (?, ?, ?, ?, ?)"
        );
        $stmt->execute([$lessonId, $englishWord, $uzbekTranslation, $exampleSentence, $pronunciation]);

        $newWord = self::findById((int)Database::connection()->lastInsertId());
        if ($newWord) {
            ws_broadcast('word_added', ['lesson_id' => $lessonId, 'word' => $newWord]);
        }
        return $newWord;
    }

    public static function update(
        int $wordId,
        array $user,
        string $englishWord,
        string $uzbekTranslation,
        ?string $exampleSentence,
        ?string $pronunciation
    ): array {
        $word = self::findInVisibleLesson($wordId, $user);
        if (!$word) {
            throw new RuntimeException('Word not found.');
        }
        if ((int)$word['lesson_owner_id'] !== (int)$user['id'] && $user['role'] !== 'admin') {
            throw new LogicException('Forbidden.');
        }

        $wordsTable = Database::table('words');
        $stmt = Database::connection()->prepare(
            "UPDATE {$wordsTable}
             SET english_word = ?, uzbek_translation = ?, example_sentence = ?, pronunciation = ?, updated_at = NOW()
             WHERE id = ?"
        );
        $stmt->execute([$englishWord, $uzbekTranslation, $exampleSentence, $pronunciation, $wordId]);

        $updatedWord = self::findById($wordId);
        if ($updatedWord) {
            ws_broadcast('word_updated', ['lesson_id' => $updatedWord['lesson_id'], 'word' => $updatedWord]);
        }
        return $updatedWord;
    }

    public static function delete(int $wordId, array $user): void
    {
        $word = self::findInVisibleLesson($wordId, $user);
        if (!$word) {
            throw new RuntimeException('Word not found.');
        }
        if ((int)$word['lesson_owner_id'] !== (int)$user['id'] && $user['role'] !== 'admin') {
            throw new LogicException('Forbidden.');
        }

        $wordsTable = Database::table('words');
        $stmt = Database::connection()->prepare("DELETE FROM {$wordsTable} WHERE id = ?");
        $stmt->execute([$wordId]);
        ws_broadcast('word_deleted', ['lesson_id' => $word['lesson_id'], 'word_id' => $wordId]);
    }

    public static function findById(int $wordId): ?array
    {
        $wordsTable = Database::table('words');
        $stmt = Database::connection()->prepare("SELECT * FROM {$wordsTable} WHERE id = ? LIMIT 1");
        $stmt->execute([$wordId]);
        $word = $stmt->fetch();
        return $word ?: null;
    }
}
