<?php
require_once __DIR__ . '/wordrise-api/config/database.php';
\ = Database::connection();
\ = \->query('SELECT token FROM wr_api_tokens LIMIT 1');
\ = \->fetchColumn();

\ = curl_init('https://69a7b993deaa3.goldxost.ru/wordrise-api/api/profile/sessions.php');
curl_setopt(\, CURLOPT_RETURNTRANSFER, true);
curl_setopt(\, CURLOPT_HEADER, true);
curl_setopt(\, CURLOPT_SSL_VERIFYPEER, false);
curl_setopt(\, CURLOPT_SSL_VERIFYHOST, false);
curl_setopt(\, CURLOPT_HTTPHEADER, ['Authorization: Bearer ' . \]);
\ = curl_exec(\);
if (\ === false) echo 'Curl error: ' . curl_error(\);
else echo \;
?>
