<?php

$origin = trim((string)($_SERVER['HTTP_ORIGIN'] ?? ''));
$host = trim((string)($_SERVER['HTTP_HOST'] ?? ''));
$configuredOrigins = array_values(array_filter(array_map(
    'trim',
    explode(',', (string)(getenv('CORS_ALLOWED_ORIGINS') ?: ''))
)));
$applicationOrigins = [
    'https://wordrise.netlify.app',
];
$sameHostOrigins = $host === '' ? [] : ["https://{$host}", "http://{$host}"];
$isLocalOrigin = preg_match(
    '#^https?://(localhost|127\.0\.0\.1|\[::1\])(?::\d{1,5})?$#i',
    $origin
) === 1;
$originAllowed = $origin === ''
    || in_array($origin, $configuredOrigins, true)
    || in_array($origin, $applicationOrigins, true)
    || in_array($origin, $sameHostOrigins, true)
    || $isLocalOrigin;

header('Vary: Origin');
header('X-Content-Type-Options: nosniff');
header('Referrer-Policy: no-referrer');
header('X-Frame-Options: DENY');
header('Cache-Control: no-store');
header('Content-Type: application/json; charset=utf-8');

if ($origin !== '' && $originAllowed) {
    header("Access-Control-Allow-Origin: {$origin}");
    header('Access-Control-Allow-Credentials: true');
}

header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
header('Access-Control-Max-Age: 600');

if (!$originAllowed) {
    http_response_code(403);
    echo json_encode([
        'success' => false,
        'message' => 'Origin is not allowed.',
        'errors' => [],
    ], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    exit;
}

if (($_SERVER['REQUEST_METHOD'] ?? '') === 'OPTIONS') {
    http_response_code(204);
    exit;
}
