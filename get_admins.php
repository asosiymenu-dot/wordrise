<?php
require_once __DIR__ . '/wordrise-api/config/database.php';
try {
    $db = Database::connection();
    $stmt = $db->query("SELECT email, password_hash FROM users WHERE role = 'admin' LIMIT 1");
    $admin = $stmt->fetch();
    
    if ($admin) {
        echo "Admin email: " . $admin['email'];
        // We can't see the plain text password, so we can generate a new one
        $newPass = password_hash('12345678', PASSWORD_DEFAULT);
        $db->query("UPDATE users SET password_hash = '$newPass' WHERE email = '{$admin['email']}'");
        echo " | Password reset to: 12345678";
    } else {
        // Create an admin
        $newPass = password_hash('12345678', PASSWORD_DEFAULT);
        $db->query("INSERT INTO users (name, email, password_hash, role) VALUES ('Admin', 'admin@wordrise.uz', '$newPass', 'admin')");
        echo "Created new admin: admin@wordrise.uz | 12345678";
    }
} catch (Exception $e) {
    echo $e->getMessage();
}
