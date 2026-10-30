<?php
require_once __DIR__ . '/config/database.php';
$stmt = Database::connection()->query("SELECT * FROM wr_app_releases ORDER BY version_code DESC LIMIT 1");
print_r($stmt->fetch(PDO::FETCH_ASSOC));
?>
