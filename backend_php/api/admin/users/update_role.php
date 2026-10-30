<?php

require_once __DIR__ . '/../../../helpers/response.php';
require_once __DIR__ . '/../../../middleware/auth_middleware.php';
require_once __DIR__ . '/../../../config/database.php';
require_once __DIR__ . '/../../../models/User.php';

require_method('POST');
$user = auth_user();
require_role($user, ['admin']);

$data = json_decode(file_get_contents('php://input'), true);
$targetUserId = (int)($data['user_id'] ?? 0);
$newRole = (string)($data['role'] ?? '');

if (!$targetUserId || !in_array($newRole, ['student', 'teacher', 'admin'])) {
    error_response("Invalid input", 400);
}

if ($targetUserId === (int)$user['id']) {
    error_response("You cannot change your own role", 400);
}

try {
    $db = Database::connection();
    $usersTable = Database::table('users');
    $stmt = $db->prepare("UPDATE $usersTable SET role = ? WHERE id = ?");
    $stmt->execute([$newRole, $targetUserId]);
    
    if ($stmt->rowCount() === 0) {
        error_response("User not found or role unchanged", 404);
    }
    
    require_once __DIR__ . '/../../../helpers/websocket.php';
    ws_broadcast('user_role_changed', ['user_id' => $targetUserId, 'role' => $newRole]);
    
    success_response(['message' => 'Role updated successfully', 'role' => $newRole]);
} catch (PDOException $e) {
    error_response("Database error", 500);
}
