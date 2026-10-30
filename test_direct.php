<?php
ini_set('display_errors', 1);
error_reporting(E_ALL);

require_once __DIR__ . '/wordrise-api/config/database.php';
\ = Database::connection();
\ = \->query('SELECT token FROM wr_api_tokens LIMIT 1');
\ = \->fetchColumn();

\['HTTP_AUTHORIZATION'] = 'Bearer ' . \;
\['REQUEST_METHOD'] = 'GET';

require_once __DIR__ . '/wordrise-api/api/profile/sessions.php';
?>
