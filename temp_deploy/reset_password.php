<?php

require_once __DIR__ . '/../config/database.php';

try {
    $db = Database::connection();
    $password = '123456';
    $hash = password_hash($password, PASSWORD_DEFAULT);
    
    $stmt = $db->prepare("UPDATE users SET password = :hash WHERE username = 'shahzodbek'");
    $stmt->execute([':hash' => $hash]);
    
    if ($stmt->rowCount() > 0) {
        echo "✅ Password for @shahzodbek has been reset to: $password";
    } else {
        echo "❌ User @shahzodbek not found or password is already $password.";
    }
} catch (Exception $e) {
    echo "❌ Error: " . $e->getMessage();
}
