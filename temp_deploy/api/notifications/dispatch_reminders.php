<?php

require_once __DIR__ . '/../../helpers/response.php';
require_once __DIR__ . '/../../models/LearningPreferences.php';

$isCli = PHP_SAPI === 'cli';
if (!$isCli) {
    require_method('POST');
    $configuredSecret = (string)(getenv('CRON_SECRET') ?: '');
    $providedSecret = (string)($_SERVER['HTTP_X_CRON_SECRET'] ?? ($_GET['secret'] ?? ''));
    if ($configuredSecret === '') {
        error_response('Reminder cron is not configured.', 503);
    }
    if (!hash_equals($configuredSecret, $providedSecret)) {
        error_response('Unauthorized.', 401);
    }
}

success_response(LearningPreferences::dispatchDueReminders());
