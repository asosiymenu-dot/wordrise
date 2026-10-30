<?php

require_once __DIR__ . '/../../../helpers/response.php';
require_once __DIR__ . '/../../../middleware/auth_middleware.php';
require_once __DIR__ . '/../../../config/database.php';

require_method('POST');
$user = auth_user();
require_role($user, ['admin']);

$data = json_decode(file_get_contents('php://input'), true);
$lessonId = (int)($data['lesson_id'] ?? 0);

if (!$lessonId) {
    error_response("Invalid lesson ID", 400);
}

try {
    $db = Database::connection();
    $lessonsTable = Database::table('lessons');
    
    $stmt = $db->prepare("DELETE FROM $lessonsTable WHERE id = ?");
    $stmt->execute([$lessonId]);
    
    if ($stmt->rowCount() === 0) {
        error_response("Lesson not found", 404);
    }
    
    success_response(['message' => 'Lesson deleted successfully']);
} catch (PDOException $e) {
    error_response("Database error", 500);
}
