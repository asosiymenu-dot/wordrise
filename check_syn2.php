<?php
echo shell_exec('php -l wordrise-api/helpers/websocket.php 2>&1');
echo shell_exec('php -l wordrise-api/api/profile/sessions.php 2>&1');
echo shell_exec('php -l wordrise-api/models/Session.php 2>&1');
?>
