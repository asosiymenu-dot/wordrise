<?php
echo "Step 1\n";
require_once __DIR__ . '/wordrise-api/config/database.php';
echo "Step 2\n";
$pdo = Database::connection();
echo "Step 3\n";
?>
