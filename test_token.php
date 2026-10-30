<?php
ini_set('display_errors', 1);
error_reporting(E_ALL);

require_once __DIR__ . '/wordrise-api/config/database.php';
\ = Database::connection();
\ = \->query('SELECT token FROM wr_api_tokens LIMIT 1');
\ = \->fetchColumn();

if (\) {
    \ = curl_init('https://69a7b993deaa3.goldxost.ru/wordrise-api/api/profile/sessions.php');
    curl_setopt(\, CURLOPT_RETURNTRANSFER, true);
    curl_setopt(\, CURLOPT_HTTPHEADER, ['Authorization: Bearer ' . \]);
    \ = curl_exec(\);
    echo 'Response: ' . \;
} else {
    echo 'No token found';
}
?>
