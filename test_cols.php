<?php
ini_set('display_errors', 1);
error_reporting(E_ALL);

try {
    \ = new PDO('mysql:host=localhost;dbname=69a7b993de9dc_ojspkp;charset=utf8mb4', '69a7b993de9dc_ojspkp', 'ojspkp');
    \ = \->query('SHOW COLUMNS FROM wr_api_tokens');
    \ = \->fetchAll(PDO::FETCH_ASSOC);
    foreach (\ as \) {
        echo \['Field'] . ', ';
    }
} catch (Throwable \) {
    echo \->getMessage();
}
?>
