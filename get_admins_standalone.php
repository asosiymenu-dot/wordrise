<?php
try {
    $db = new PDO("mysql:host=localhost;dbname=69a7b993de9dc_ojspkp;charset=utf8mb4", "69a7b993de9dc_ojspkp", "ojspkp");
    $db->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    
    $stmt = $db->query("SELECT email, password_hash FROM wr_users WHERE role = 'admin' LIMIT 1");
    $admin = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if ($admin) {
        $email = $admin['email'];
        $newPass = password_hash('admin1234', PASSWORD_DEFAULT);
        $db->query("UPDATE wr_users SET password_hash = '$newPass' WHERE email = '$email'");
        echo "Admin found: " . $email . " | Password reset to: admin1234";
    } else {
        $newPass = password_hash('admin1234', PASSWORD_DEFAULT);
        $db->query("INSERT INTO wr_users (name, email, password_hash, role) VALUES ('Admin', 'admin@wordrise.uz', '$newPass', 'admin')");
        echo "No admin found. Created: admin@wordrise.uz | admin1234";
    }
} catch (Exception $e) {
    echo "DB Error: " . $e->getMessage();
}
