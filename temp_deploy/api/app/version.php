<?php

require_once __DIR__ . '/../../helpers/response.php';
require_once __DIR__ . '/../../models/AppRelease.php';

require_method('GET');
header('Cache-Control: no-store, max-age=0');

try {
    $platform = strtolower(trim((string)($_GET['platform'] ?? 'android')));
    if (!in_array($platform, ['android', 'ios'], true)) {
        error_response('Unsupported platform.', 422);
    }
    $locale = strtolower(trim((string)($_GET['locale'] ?? 'en')));
    $currentVersionCode = max(
        0,
        (int)($_GET['current_version_code'] ?? 0)
    );
    success_response(
        AppRelease::forClient($platform, $currentVersionCode, $locale)
    );
} catch (Throwable $error) {
    error_response($error->getMessage(), 500);
}
