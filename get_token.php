<?php
require_once __DIR__ . '/wordrise-api/config/database.php';
\ = Database::connection();
\ = \->query('SELECT token FROM wr_api_tokens LIMIT 1');
\ = \->fetchColumn();
echo \;
?>
