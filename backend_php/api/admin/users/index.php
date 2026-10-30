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
    
    $whereClause = "1=1";
    $params = [];
    
    if ($search !== '') {
        $whereClause .= " AND (name LIKE ? OR email LIKE ? OR username LIKE ?)";
        $params[] = "%$search%";
        $params[] = "%$search%";
        $params[] = "%$search%";
    }
    
    $usersTable = Database::table('users');
    $countStmt = $db->prepare("SELECT COUNT(*) FROM $usersTable WHERE $whereClause");
    $countStmt->execute($params);
    $totalUsers = (int)$countStmt->fetchColumn();
    
    $params[] = $limit;
    $params[] = $offset;
    
    $stmt = $db->prepare("SELECT id, name, username, email, role, level, xp, last_seen_at, created_at, avatar FROM $usersTable WHERE $whereClause ORDER BY id DESC LIMIT ? OFFSET ?");
    $stmt->execute($params);
    $users = $stmt->fetchAll();
    
    success_response([
        'users' => $users,
        'pagination' => [
            'total' => $totalUsers,
            'page' => $page,
            'limit' => $limit,
            'total_pages' => ceil($totalUsers / $limit)
        ]
    ]);
} catch (PDOException $e) {
    error_response("Database error", 500);
}
