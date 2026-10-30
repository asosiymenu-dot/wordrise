<?php

require_once __DIR__ . '/../../helpers/response.php';
require_once __DIR__ . '/../../middleware/auth_middleware.php';
require_once __DIR__ . '/../../helpers/ai.php';

require_method('POST');

try {
    $user = auth_user();
    ai_rate_limit($user, 'suggest_word', 15, 60);
    $data = request_json();
    $word = trim((string)($data['word'] ?? ($data['english_word'] ?? '')));
    if ($word === '') {
        error_response('word is required.', 422);
    }

    $prompt = "Inglizcha '{$word}' so'zi uchun o'zbek o'rganuvchiga mos lug'at ma'lumotini tayyorla. Faqat JSON qaytar, boshqa matn yozma. Schema: {\"english_word\":\"string\",\"uzbek_translation\":\"string\",\"example_sentence\":\"English sentence\",\"example_sentence_uz\":\"O'zbek tarjima\",\"pronunciation\":\"IPA yoki sodda talaffuz\",\"part_of_speech\":\"noun|verb|adjective|adverb|other\",\"synonyms\":[\"string\"],\"difficulty_level\":\"A1|A2|B1|B2|C1|C2\"}.";
    $result = gemini_json($prompt);
    success_response(['suggestion' => normalize_word_suggestion($result, $word)]);
} catch (Throwable $error) {
    error_response($error->getMessage(), 500);
}

function normalize_word_suggestion(array $data, string $fallbackWord): array
{
    return [
        'english_word' => trim((string)($data['english_word'] ?? $fallbackWord)),
        'uzbek_translation' => trim((string)($data['uzbek_translation'] ?? '')),
        'example_sentence' => trim((string)($data['example_sentence'] ?? '')),
        'example_sentence_uz' => trim((string)($data['example_sentence_uz'] ?? '')),
        'pronunciation' => trim((string)($data['pronunciation'] ?? '')),
        'part_of_speech' => trim((string)($data['part_of_speech'] ?? 'other')),
        'synonyms' => array_values(array_slice(array_map('strval', is_array($data['synonyms'] ?? null) ? $data['synonyms'] : []), 0, 3)),
        'difficulty_level' => trim((string)($data['difficulty_level'] ?? 'A1')),
    ];
}
