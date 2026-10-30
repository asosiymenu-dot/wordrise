<?php
ini_set('display_errors', 1);
error_reporting(E_ALL);

try {
    require_once __DIR__ . '/wordrise-api/api/profile/sessions.php';
} catch (Throwable \) {
    echo 'Error: ' . \->getMessage();
}
?>
