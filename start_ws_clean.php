<?php
$cmd = 'nohup php ' . __DIR__ . '/wordrise-api/websocket/server.php > /dev/null 2>&1 & echo $!';
$pid = shell_exec($cmd);
echo 'Started with PID: ' . $pid;
?>
