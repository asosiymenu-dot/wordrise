<?php

require_once __DIR__ . '/../../helpers/response.php';
require_once __DIR__ . '/../../middleware/auth_middleware.php';
require_once __DIR__ . '/../../config/database.php';

require_method('GET');
$user = auth_user();
require_role($user, ['admin']);

try {
    $db = Database::connection();
    
    $usersTable = Database::table('users');
    $messagesTable = Database::table('messages');
    $lessonsTable = Database::table('lessons');

    // Total users
    $stmt = $db->query("SELECT COUNT(*) FROM $usersTable");
    $totalUsers = (int)$stmt->fetchColumn();
    
    // Online users (active within last 5 minutes)
    $stmt = $db->query("SELECT COUNT(*) FROM $usersTable WHERE last_seen_at >= DATE_SUB(NOW(), INTERVAL 5 MINUTE)");
    $onlineUsers = (int)$stmt->fetchColumn();
    
    // New users today
    $stmt = $db->query("SELECT COUNT(*) FROM $usersTable WHERE DATE(created_at) = CURDATE()");
    $newUsersToday = (int)$stmt->fetchColumn();
    
    // Total messages
    $stmt = $db->query("SELECT COUNT(*) FROM $messagesTable");
    $totalMessages = (int)$stmt->fetchColumn();

    // Total lessons
    $stmt = $db->query("SELECT COUNT(*) FROM $lessonsTable");
    $totalLessons = (int)$stmt->fetchColumn();

    success_response([
        'stats' => [
            'total_users' => $totalUsers,
            'online_users' => $onlineUsers,
            'new_users_today' => $newUsersToday,
            'total_messages' => $totalMessages,
            'total_lessons' => $totalLessons
        ]
    ]);
} catch (PDOException $e) {
    error_response("Database error", 500);
}
