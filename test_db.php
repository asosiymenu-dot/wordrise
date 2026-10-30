<?php 
ini_set('display_errors', 1);
error_reporting(E_ALL);
echo 'start';
require_once __DIR__ . '/wordrise-api/config/database.php';
echo ' loaded db';
\ = Database::connection();
echo ' connected';
?>
