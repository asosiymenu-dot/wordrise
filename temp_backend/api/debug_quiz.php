<?php

require_once __DIR__ . '/../helpers/response.php';
require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../models/Quiz.php';

require_method('GET');

try {
    $wordsTable = Database::table('words');
    $lessonsTable = Database::table('lessons');
    $usersTable = Database::table('users');
    
    $lessons = Database::connection()->query("
        SELECT l.id, l.user_id, u.name as user_name, u.role as user_role, l.title, l.is_public, COUNT(w.id) as word_count 
        FROM {$lessonsTable} l 
        LEFT JOIN {$usersTable} u ON u.id = l.user_id
        LEFT JOIN {$wordsTable} w ON w.lesson_id = l.id 
        GROUP BY l.id, l.user_id, u.name, u.role, l.title, l.is_public
        ORDER BY l.id ASC
    ")->fetchAll();

    $user24 = ['id' => 24, 'role' => 'student'];
    $quizWords = Quiz::generateReview($user24, 'multiple_choice', 50000);

    success_response([
        'user_24_review_words_count' => count($quizWords),
        'distinct_english_words' => (int)$distinctWords,
        'lessons' => $lessons,
    ]);
} catch (Throwable $e) {
    error_response($e->getMessage(), 500);
}
