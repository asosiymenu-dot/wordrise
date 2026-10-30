<?php

require_once __DIR__ . '/../../helpers/response.php';
require_once __DIR__ . '/../../middleware/auth_middleware.php';
require_once __DIR__ . '/../../helpers/ai.php';

require_method('POST');

try {
    $user = auth_user();
    ai_rate_limit($user, 'extract_words', 10, 60);
    $data = request_json();
    $mimeType = strtolower(trim((string)($data['mime_type'] ?? '')));
    $encoded = trim((string)($data['image_base64'] ?? ''));
    if (preg_match('/^data:[^;]+;base64,(.+)$/s', $encoded, $matches)) {
        $encoded = $matches[1];
    }
    if (!in_array($mimeType, ['image/jpeg', 'image/png', 'image/webp'], true)) {
        error_response('Unsupported image type.', 422);
    }
    if ($encoded === '' || strlen($encoded) > 8500000) {
        error_response('Image is empty or too large.', 422);
    }
    $binary = base64_decode($encoded, true);
    if ($binary === false || strlen($binary) < 32 || strlen($binary) > 6000000) {
        error_response('Invalid image data.', 422);
    }

    $prompt = 'Analyze the attached photo for an English learner. Extract up to 30 useful, unique English vocabulary words that are clearly visible in the text. Exclude names, URLs, isolated numbers, duplicates and obvious OCR noise. Return JSON only with this schema: {"words":[{"english_word":"string","uzbek_translation":"string","example_sentence":"short English example","pronunciation":"IPA or simple pronunciation"}]}. Keep translations natural Uzbek and preserve the dictionary form of each English word.';
    $result = gemini_json_with_image($prompt, base64_encode($binary), $mimeType);
    $items = isset($result['words']) && is_array($result['words'])
        ? $result['words']
        : (array_key_exists(0, $result) ? $result : []);
    $words = [];
    $seen = [];
    $stopWords = array_fill_keys([
        'a', 'an', 'the', 'and', 'or', 'to', 'of', 'in', 'on', 'at', 'is', 'are',
        'was', 'were', 'be', 'am', 'this', 'that', 'these', 'those', 'for', 'with',
        'from', 'as', 'it', 'its', 'my', 'your', 'our', 'their', 'i',
    ], true);
    foreach ($items as $item) {
        if (!is_array($item)) {
            continue;
        }
        $english = trim((string)($item['english_word'] ?? $item['word'] ?? ''));
        $translation = trim((string)($item['uzbek_translation'] ?? $item['translation'] ?? ''));
        $key = strtolower($english);
        if ($english === ''
            || strlen($english) < 2
            || $translation === ''
            || isset($seen[$key])
            || isset($stopWords[$key])
        ) {
            continue;
        }
        if (strlen($english) > 120 || !preg_match("/^[A-Za-z][A-Za-z' -]*$/", $english)) {
            continue;
        }
        if (preg_match('/^[A-Z][a-z]+$/', $english)) {
            $english = strtolower($english);
            $key = $english;
        }
        $seen[$key] = true;
        $words[] = [
            'english_word' => $english,
            'uzbek_translation' => substr($translation, 0, 160),
            'example_sentence' => substr(trim((string)($item['example_sentence'] ?? '')), 0, 255),
            'pronunciation' => substr(trim((string)($item['pronunciation'] ?? '')), 0, 120),
        ];
        if (count($words) >= 30) {
            break;
        }
    }
    success_response(['words' => $words, 'count' => count($words)]);
} catch (Throwable $error) {
    error_response($error->getMessage(), 500);
}
