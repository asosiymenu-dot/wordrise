<?php

require_once __DIR__ . '/../../helpers/response.php';
require_once __DIR__ . '/../../middleware/auth_middleware.php';
require_once __DIR__ . '/../../helpers/ai.php';

require_method('POST');

try {
    $user = auth_user();
    ai_rate_limit($user, 'practice_feedback', 8, 60);
    $data = request_json();
    $sentence = trim((string)($data['sentence'] ?? ''));
    if ($sentence === '') {
        error_response('sentence is required.', 422);
    }

    $prompt = "Ingliz tilini o'rganayotgan o'zbek foydalanuvchi ushbu gapni yozdi: '{$sentence}'. Grammatik feedback ber. Faqat JSON qaytar. Schema: {\"corrected_sentence\":\"string\",\"is_correct\":true,\"explanation_uz\":\"string\",\"tips\":[\"string\"]}.";
    $result = gemini_json($prompt);
    success_response(['feedback' => $result]);
} catch (Throwable $error) {
    error_response($error->getMessage(), 500);
}
