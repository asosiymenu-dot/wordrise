<?php

require_once __DIR__ . '/../../helpers/response.php';
require_once __DIR__ . '/../../middleware/auth_middleware.php';
require_once __DIR__ . '/../../models/Word.php';

require_method('POST');

try {
    $user = auth_user();
    $data = request_json();
    $lessonId = (int)($data['lesson_id'] ?? 0);
    $items = $data['words'] ?? ($data['items'] ?? []);
    if ($lessonId <= 0 || !is_array($items)) {
        error_response('lesson_id and words are required.', 422);
    }

    $created = [];
    $skipped = [];
    foreach ($items as $item) {
        if (!is_array($item)) {
            continue;
        }

        $englishWord = first_non_empty($item, ['english_word', 'word', 'english']);
        $uzbekTranslation = first_non_empty($item, ['uzbek_translation', 'translation', 'uzbek']);
        $exampleSentence = first_non_empty($item, ['example_sentence', 'example', 'sentence']);
        $pronunciation = first_non_empty($item, ['pronunciation', 'pronounce']);

        if ($englishWord === null || $uzbekTranslation === null) {
            $skipped[] = $item;
            continue;
        }

        try {
            $created[] = WordModel::create(
                $lessonId,
                $user,
                limit_text($englishWord, 120, 'english_word'),
                limit_text($uzbekTranslation, 160, 'uzbek_translation'),
                $exampleSentence === null ? null : limit_text($exampleSentence, 255, 'example_sentence'),
                $pronunciation === null ? null : limit_text($pronunciation, 120, 'pronunciation')
            );
        } catch (PDOException $error) {
            if (($error->errorInfo[1] ?? null) === 1062) {
                $skipped[] = $item;
                continue;
            }
            throw $error;
        }
    }

    if (count($created) === 0 && count($skipped) === 0) {
        error_response('No valid words found. Use word/translation or english_word/uzbek_translation.', 422);
    }

    success_response([
        'words' => $created,
        'created_count' => count($created),
        'skipped_count' => count($skipped),
    ], 'Words created.', 201);
} catch (Throwable $error) {
    $status = $error instanceof LogicException ? 403 : 500;
    error_response($error->getMessage(), $status);
}

function first_non_empty(array $item, array $keys): ?string
{
    foreach ($keys as $key) {
        if (!array_key_exists($key, $item)) {
            continue;
        }
        $value = trim((string)$item[$key]);
        if ($value !== '') {
            return $value;
        }
    }
    return null;
}

function limit_text(string $value, int $max, string $field): string
{
    if (strlen($value) > $max) {
        error_response("{$field} is too long.", 422);
    }
    return $value;
}
