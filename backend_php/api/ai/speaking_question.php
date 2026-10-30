<?php

require_once __DIR__ . '/../../helpers/response.php';
require_once __DIR__ . '/../../middleware/auth_middleware.php';
require_once __DIR__ . '/../../helpers/ai.php';

require_method('POST');

try {
    $user = auth_user();
    $data = request_json();
    $level = strtoupper(trim((string)($data['level'] ?? ($user['english_level'] ?? 'A1'))));
    $topic = trim((string)($data['topic'] ?? 'daily life'));
    $history = is_array($data['history'] ?? null) ? array_slice($data['history'], -6) : [];
    $historyJson = json_encode($history, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);

    $prompt = "You are a friendly English speaking coach for an Uzbek learner. Level: {$level}. Topic: {$topic}. Conversation history JSON: {$historyJson}. Ask ONE natural English speaking question. Keep it short for mobile voice chat. Return only JSON. Schema: {\"question\":\"string\",\"topic\":\"string\",\"level\":\"A1|A2|B1|B2|C1|C2\",\"hint_uz\":\"short Uzbek hint\",\"sample_answer\":\"short English sample\"}.";
    $result = gemini_json($prompt);

    success_response([
        'question' => trim((string)($result['question'] ?? 'What did you do today?')),
        'topic' => trim((string)($result['topic'] ?? $topic)),
        'level' => strtoupper(trim((string)($result['level'] ?? $level))),
        'hint_uz' => trim((string)($result['hint_uz'] ?? 'Oddiy va qisqa javob bering.')),
        'sample_answer' => trim((string)($result['sample_answer'] ?? 'I practiced English today.')),
    ]);
} catch (Throwable $error) {
    error_response($error->getMessage(), 500);
}
