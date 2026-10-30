<?php

$localGeminiConfig = __DIR__ . '/gemini.local.php';
if (is_file($localGeminiConfig)) {
    require_once $localGeminiConfig;
}

if (!defined('GEMINI_API_KEY')) {
    define('GEMINI_API_KEY', getenv('GEMINI_API_KEY') ?: '');
}

if (!defined('GEMINI_MODEL')) {
    define('GEMINI_MODEL', getenv('GEMINI_MODEL') ?: 'gemini-2.5-flash');
}

if (!defined('BAZAARLINK_API_KEY')) {
    define('BAZAARLINK_API_KEY', 'sk-bl-N60fdtmINzVuJzEJCKS8oC3CG3QK9DMPRvijXBt4--pXVTC9');
}
