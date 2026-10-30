<?php
echo 'Perms: ' . substr(sprintf('%o', fileperms(__DIR__ . '/wordrise-api/helpers/websocket.php')), -4);
?>
