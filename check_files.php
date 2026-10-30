<?php
echo 'Models: ' . print_r(scandir(__DIR__ . '/wordrise-api/models'), true);
echo 'Profile API: ' . print_r(scandir(__DIR__ . '/wordrise-api/api/profile'), true);
?>
