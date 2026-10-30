<?php
echo 'Step 1\\n';
require_once __DIR__ . '/wordrise-api/config/database.php';
echo 'Step 2\\n';
\ = Database::connection();
echo 'Step 3\\n';
\ = \->query('SELECT token FROM wr_api_tokens LIMIT 1');
\ = \->fetchColumn();
echo 'Token: ' . substr(\, 0, 10) . '...\\n';
?>
