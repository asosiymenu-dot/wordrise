<?php
ini_set('display_errors', 1);
error_reporting(E_ALL);
require_once __DIR__ . '/wordrise-api/config/database.php';
try {
    \ = Database::connection();
    \ = \->query('SHOW COLUMNS FROM wr_api_tokens');
    \ = \->fetchAll(PDO::FETCH_ASSOC);
    echo print_r(\, true);
} catch (Throwable \) {
    echo 'DB ERROR: ' . \->getMessage();
}
?>
