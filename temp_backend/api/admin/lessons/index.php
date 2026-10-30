<?php

require_once __DIR__ . '/../../../helpers/response.php';
require_once __DIR__ . '/../../../middleware/auth_middleware.php';
require_once __DIR__ . '/../../../config/database.php';

require_method('GET');
$user = auth_user();
require_role($user, ['admin']);

try {
    $db = Database::connection();
    
    $page = max(1, (int)($_GET['page'] ?? 1));
    $limit = max(10, min((int)($_GET['limit'] ?? 20), 100));
    $offset = ($page - 1) * $limit;
    
    $search = trim((string)($_GET['q'] ?? ''));
    
    $lessonsTable = Database::table('lessons');
    $usersTable = Database::table('users');
    
    $whereClause = "1=1";
    $params = [];
    
    if ($search !== '') {
        $whereClause .= " AND (l.title LIKE ? OR l.category LIKE ? OR u.name LIKE ?)";
        $params[] = "%$search%";
        $params[] = "%$search%";
        $params[] = "%$search%";
    }
    
    $countStmt = $db->prepare("
        SELECT COUNT(*) 
        FROM $lessonsTable l
        LEFT JOIN $usersTable u ON l.user_id = u.id
        WHERE $whereClause
    ");
    $countStmt->execute($params);
    $totalLessons = (int)$countStmt->fetchColumn();
    
    $params[] = $limit;
    $params[] = $offset;
    
    $stmt = $db->prepare("
        SELECT l.id, l.title, l.category, l.is_public, l.import_count, l.created_at,
               u.name as author_name, u.email as author_email, u.avatar as author_avatar,
               (SELECT COUNT(*) FROM " . Database::table('words') . " w WHERE w.lesson_id = l.id) as words_count
        FROM $lessonsTable l
        LEFT JOIN $usersTable u ON l.user_id = u.id
        WHERE $whereClause 
        ORDER BY l.id DESC 
        LIMIT ? OFFSET ?
    ");
    $stmt->execute($params);
    $lessons = $stmt->fetchAll();
    
    success_response([
        'lessons' => $lessons,
        'pagination' => [
            'total' => $totalLessons,
            'page' => $page,
            'limit' => $limit,
            'total_pages' => ceil($totalLessons / $limit)
        ]
    ]);
} catch (PDOException $e) {
    error_response("Database error: " . $e->getMessage(), 500);
}
