<?php

define('FIREBASE_PROJECT_ID', trim((string)(getenv('FIREBASE_PROJECT_ID') ?: '')));
define('FIREBASE_CLIENT_EMAIL', trim((string)(getenv('FIREBASE_CLIENT_EMAIL') ?: '')));
define(
    'FIREBASE_PRIVATE_KEY',
    str_replace('\\n', "\n", (string)(getenv('FIREBASE_PRIVATE_KEY') ?: ''))
);

function firebase_configured(): bool
{
    return FIREBASE_PROJECT_ID !== ''
        && FIREBASE_CLIENT_EMAIL !== ''
        && FIREBASE_PRIVATE_KEY !== '';
}
