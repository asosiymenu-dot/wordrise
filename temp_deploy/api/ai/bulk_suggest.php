<?php

require_once __DIR__ . '/../../helpers/response.php';
require_once __DIR__ . '/../../middleware/auth_middleware.php';
require_once __DIR__ . '/../../helpers/ai.php';

require_method('POST');

try {
    $user = auth_user();
    ai_rate_limit($user, 'bulk_suggest', 5, 60);
    $data = request_json();
    $words = $data['words'] ?? [];
    if (is_string($words)) {
        $words = preg_split('/[\\r\\n,;]+/', $words);
    }
    if (!is_array($words)) {
        error_response('words array is required.', 422);
    }
    $words = array_values(array_filter(array_map(static function ($item): string {
        return trim((string)$item);
    }, $words)));
    if (count($words) === 0) {
        error_response('Kamida bitta soʼz kiriting.', 422);
    }

    $jsonWords = json_encode($words, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    $prompt = "Quyidagi inglizcha so'zlar uchun o'zbek lug'at ma'lumotlarini to'ldir. Faqat JSON qaytar. Input: {$jsonWords}. Schema: {\"words\":[{\"english_word\":\"string\",\"uzbek_translation\":\"string\",\"example_sentence\":\"English sentence\",\"example_sentence_uz\":\"O'zbek tarjima\",\"pronunciation\":\"IPA yoki sodda talaffuz\",\"part_of_speech\":\"string\",\"synonyms\":[\"string\"],\"difficulty_level\":\"A1|A2|B1|B2|C1|C2\"}]}";
    $result = gemini_json($prompt);
    $items = is_array($result['words'] ?? null) ? $result['words'] : $result;
    if (!is_array($items)) {
        error_response('AI soʼzlar roʼyxatini qaytarmadi.', 502);
    }

    $normalized = [];
    foreach ($items as $index => $item) {
        if (!is_array($item)) {
            continue;
        }
        $normalized[] = [
            'english_word' => trim((string)($item['english_word'] ?? ($words[$index] ?? ''))),
            'uzbek_translation' => trim((string)($item['uzbek_translation'] ?? '')),
            'example_sentence' => trim((string)($item['example_sentence'] ?? '')),
            'example_sentence_uz' => trim((string)($item['example_sentence_uz'] ?? '')),
            'pronunciation' => trim((string)($item['pronunciation'] ?? '')),
            'part_of_speech' => trim((string)($item['part_of_speech'] ?? 'other')),
            'synonyms' => array_values(array_slice(array_map('strval', is_array($item['synonyms'] ?? null) ? $item['synonyms'] : []), 0, 3)),
            'difficulty_level' => trim((string)($item['difficulty_level'] ?? 'A1')),
        ];
    }

    success_response(['words' => $normalized]);
} catch (Throwable $error) {
    error_response($error->getMessage(), 500);
}
