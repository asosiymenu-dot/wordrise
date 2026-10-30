<?php

require_once __DIR__ . '/../../helpers/response.php';
require_once __DIR__ . '/../../middleware/auth_middleware.php';
require_once __DIR__ . '/../../helpers/ai.php';

require_method('POST');

try {
    $user = auth_user();
    require_role($user, ['admin']);

    $url = 'https://generativelanguage.googleapis.com/v1beta/models/' . rawurlencode(GEMINI_MODEL) . ':generateContent?key=' . rawurlencode(GEMINI_API_KEY);
    $response = gemini_request($url, [
        'contents' => [
            [
                'role' => 'user',
                'parts' => [['text' => 'Return JSON only: {"ok":true,"service":"gemini"}']],
            ],
        ],
        'generationConfig' => [
            'temperature' => 0.1,
            'responseMimeType' => 'application/json',
        ],
    ]);

    success_response([
        'environment' => ai_environment_status(),
        'http_status' => $response['status'],
        'transport' => $response['transport'],
        'raw_preview' => substr((string)$response['body'], 0, 1200),
    ]);
} catch (Throwable $error) {
    error_response($error->getMessage(), 500);
}
