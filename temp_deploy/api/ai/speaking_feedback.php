<?php

require_once __DIR__ . '/../../helpers/response.php';
require_once __DIR__ . '/../../middleware/auth_middleware.php';
require_once __DIR__ . '/../../helpers/ai.php';

require_method('POST');

try {
    $user = auth_user();
    $data = request_json();
    $question = trim((string)($data['question'] ?? ''));
    $answer = trim((string)($data['answer'] ?? ''));
    $level = strtoupper(trim((string)($data['level'] ?? ($user['english_level'] ?? 'A1'))));
    if ($question === '' || $answer === '') {
        error_response('question and answer are required.', 422);
    }

    $prompt = "Evaluate this spoken English answer from an Uzbek learner. Level: {$level}. Question: {$question}. Answer transcript: {$answer}. Give practical feedback in Uzbek and one improved English version. Return only JSON. Schema: {\"score\":0,\"is_clear\":true,\"corrected_answer\":\"string\",\"feedback_uz\":\"string\",\"pronunciation_tip_uz\":\"string\",\"grammar_tip_uz\":\"string\",\"next_question\":\"string\"}. Score 0-100.";
    $result = gemini_json($prompt);

    success_response(['feedback' => [
        'score' => max(0, min(100, (int)($result['score'] ?? 0))),
        'is_clear' => (bool)($result['is_clear'] ?? true),
        'corrected_answer' => trim((string)($result['corrected_answer'] ?? $answer)),
        'feedback_uz' => trim((string)($result['feedback_uz'] ?? 'Yaxshi urinish. Javobingizni biroz aniqroq qiling.')),
        'pronunciation_tip_uz' => trim((string)($result['pronunciation_tip_uz'] ?? 'Sekinroq va ravonroq aytishga harakat qiling.')),
        'grammar_tip_uz' => trim((string)($result['grammar_tip_uz'] ?? 'Gap tuzilishiga eʼtibor bering.')),
        'next_question' => trim((string)($result['next_question'] ?? 'Can you tell me more about it?')),
    ]]);
} catch (Throwable $error) {
    error_response($error->getMessage(), 500);
}
