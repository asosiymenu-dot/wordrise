<?php

$localGoogleOAuthConfig = __DIR__ . '/google_oauth.local.php';
if (is_file($localGoogleOAuthConfig)) {
    require_once $localGoogleOAuthConfig;
}

$configuredClientIds = getenv('GOOGLE_WEB_CLIENT_IDS')
    ?: (getenv('GOOGLE_WEB_CLIENT_ID') ?: '');
$googleWebClientIds = array_values(array_unique(array_filter(array_map(
    static function (string $value): string {
        return trim($value);
    },
    explode(',', (string)$configuredClientIds)
))));

if (!defined('GOOGLE_WEB_CLIENT_IDS')) {
    define('GOOGLE_WEB_CLIENT_IDS', $googleWebClientIds);
}

if (!defined('GOOGLE_OAUTH_CERTS_URL')) {
    define('GOOGLE_OAUTH_CERTS_URL', 'https://www.googleapis.com/oauth2/v1/certs');
}
