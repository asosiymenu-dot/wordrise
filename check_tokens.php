<?php
require_once __DIR__ . '/wordrise-api/config/database.php';
\ = Database::connection();
\ = \->query('SELECT COUNT(*) FROM wr_api_tokens');
echo \->fetchColumn();
?>
