<?php 
if (file_exists(__DIR__ . '/wordrise-api/config/env.php')) {
    echo file_get_contents(__DIR__ . '/wordrise-api/config/env.php');
} else {
    echo 'no env';
}
?>
