<?php

require_once __DIR__ . '/../../helpers/response.php';
require_once __DIR__ . '/../../middleware/auth_middleware.php';
require_once __DIR__ . '/../../helpers/ai.php';

require_method('POST');

try {
    $user = auth_user();
    ai_rate_limit($user, 'generate_lesson', 4, 60);
    $data = request_json();
    $topic = trim((string)($data['topic'] ?? ''));
    $count = max(1, (int)($data['count'] ?? 12));
    if ($topic === '') {
        error_response('topic is required.', 422);
    }

    $prompt = "O'zbek foydalanuvchi ingliz tili o'rganmoqda. '{$topic}' mavzusi bo'yicha {$count} ta foydali inglizcha so'zdan iborat dars taklif qil. Faqat JSON qaytar, boshqa matn yozma. Schema: {\"lesson\":{\"title\":\"string\",\"description\":\"string\",\"category\":\"string\"},\"words\":[{\"english_word\":\"string\",\"uzbek_translation\":\"string\",\"example_sentence\":\"English sentence\",\"example_sentence_uz\":\"O'zbek tarjima\",\"pronunciation\":\"IPA yoki sodda talaffuz\",\"part_of_speech\":\"string\",\"synonyms\":[\"string\"],\"difficulty_level\":\"A1|A2|B1|B2|C1|C2\"}]}";
    $result = gemini_json($prompt);
    $lesson = is_array($result['lesson'] ?? null) ? $result['lesson'] : [];
    $words = is_array($result['words'] ?? null) ? $result['words'] : [];

    success_response([
        'lesson' => [
            'title' => trim((string)($lesson['title'] ?? $topic)),
            'description' => trim((string)($lesson['description'] ?? 'AI yordamida tayyorlangan dars')),
            'category' => trim((string)($lesson['category'] ?? 'AI')),
        ],
        'words' => array_values(array_map(static function ($item): array {
            $item = is_array($item) ? $item : [];
            return [
                'english_word' => trim((string)($item['english_word'] ?? '')),
                'uzbek_translation' => trim((string)($item['uzbek_translation'] ?? '')),
                'example_sentence' => trim((string)($item['example_sentence'] ?? '')),
                'example_sentence_uz' => trim((string)($item['example_sentence_uz'] ?? '')),
                'pronunciation' => trim((string)($item['pronunciation'] ?? '')),
                'part_of_speech' => trim((string)($item['part_of_speech'] ?? 'other')),
                'synonyms' => array_values(array_slice(array_map('strval', is_array($item['synonyms'] ?? null) ? $item['synonyms'] : []), 0, 3)),
                'difficulty_level' => trim((string)($item['difficulty_level'] ?? 'A1')),
            ];
        }, $words)),
    ]);
} catch (Throwable $error) {
    error_response($error->getMessage(), 500);
}
