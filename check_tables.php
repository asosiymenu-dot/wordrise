<?php
require_once __DIR__ . '/wordrise-api/config/database.php';
\ = Database::connection();
\ = \->query('SHOW TABLES');
\ = \->fetchAll(PDO::FETCH_COLUMN);
echo 'Tables: ' . implode(', ', \) . '\\n';

if (in_array('wr_api_tokens', \)) {
    \ = \->query('SELECT COUNT(*) FROM wr_api_tokens');
    echo 'Tokens count: ' . \->fetchColumn() . '\\n';
}
?>
