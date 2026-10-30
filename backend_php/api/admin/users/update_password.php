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
$newPassword = (string)($data['password'] ?? '');

if (!$targetUserId || strlen($newPassword) < 6) {
    error_response("Invalid input. Password must be at least 6 characters.", 400);
}

try {
    $db = Database::connection();
    $usersTable = Database::table('users');
    
    $passwordHash = password_hash($newPassword, PASSWORD_DEFAULT);
    
    $stmt = $db->prepare("UPDATE $usersTable SET password_hash = ? WHERE id = ?");
    $stmt->execute([$passwordHash, $targetUserId]);
    
    if ($stmt->rowCount() === 0) {
        error_response("User not found or password unchanged", 404);
    }
    
    require_once __DIR__ . '/../../../helpers/websocket.php';
    $updatedUser = User::findById($targetUserId);
    ws_broadcast('user_updated', User::publicData($updatedUser));
    
    success_response(['message' => 'Password updated successfully']);
} catch (PDOException $e) {
    error_response("Database error", 500);
}
