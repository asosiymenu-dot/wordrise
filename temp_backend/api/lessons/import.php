<?php

require_once __DIR__ . '/../../helpers/response.php';
require_once __DIR__ . '/../../middleware/auth_middleware.php';
require_once __DIR__ . '/../../models/Lesson.php';
require_once __DIR__ . '/../../models/Word.php';

require_method('POST');

try {
    $user = auth_user();
    $data = request_json();
    $shareCode = trim((string)($data['share_code'] ?? ''));
    $sourceLessonId = null;

    if ($shareCode !== '') {
        $sourceLesson = Lesson::findByShareCode($shareCode);
        if (!$sourceLesson) {
            error_response('Ulashilgan dars topilmadi.', 404);
        }
        $sourceLessonId = (int)$sourceLesson['id'];
        if ((int)$sourceLesson['user_id'] === (int)$user['id']) {
            error_response('Oʼzingiz yaratgan darsni qayta import qilish shart emas.', 422);
        }
        $existingImport = Lesson::findImportedSource((int)$user['id'], $sourceLessonId);
        if ($existingImport) {
            success_response([
                'lesson' => $existingImport,
                'created_count' => 0,
                'skipped_count' => 0,
                'already_imported' => true,
            ], 'Dars avval import qilingan.');
        }
        $lessonData = [
            'title' => $sourceLesson['title'],
            'description' => $sourceLesson['description'],
            'category' => $sourceLesson['category'],
        ];
        $words = Lesson::wordsForSharedLesson($sourceLessonId);
    } else {
        $lessonData = is_array($data['lesson'] ?? null) ? $data['lesson'] : $data;
        $words = is_array($data['words'] ?? null) ? $data['words'] : [];
    }

    $title = limit_text(first_non_empty($lessonData, ['title', 'name']) ?? '', 160, 'title');
    if ($title === '') {
        error_response('title is required.', 422);
    }
    $description = first_non_empty($lessonData, ['description', 'desc']) ?? '';
    $category = first_non_empty($lessonData, ['category', 'topic']) ?? 'Imported';

    $lesson = Lesson::create(
        (int)$user['id'],
        $title,
        limit_text($description, 1000, 'description'),
        limit_text($category, 100, 'category'),
        $sourceLessonId
    );

    $created = [];
    $skipped = [];
    foreach ($words as $item) {
        if (!is_array($item)) {
            $skipped[] = $item;
            continue;
        }

        $englishWord = first_non_empty($item, ['english_word', 'word', 'english']);
        $uzbekTranslation = first_non_empty($item, ['uzbek_translation', 'translation', 'uzbek']);
        if ($englishWord === null || $uzbekTranslation === null) {
            $skipped[] = $item;
            continue;
        }

        try {
            $created[] = WordModel::create(
                (int)$lesson['id'],
                $user,
                limit_text($englishWord, 120, 'english_word'),
                limit_text($uzbekTranslation, 160, 'uzbek_translation'),
                nullable_limited(first_non_empty($item, ['example_sentence', 'example', 'sentence']), 255, 'example_sentence'),
                nullable_limited(first_non_empty($item, ['pronunciation', 'pronounce']), 120, 'pronunciation')
            );
        } catch (Throwable $error) {
            $skipped[] = $item;
        }
    }

    if ($sourceLessonId !== null) {
        Lesson::incrementImportCount($sourceLessonId);
    }

    success_response([
        'lesson' => Lesson::findById((int)$lesson['id']),
        'created_count' => count($created),
        'skipped_count' => count($skipped),
        'already_imported' => false,
    ], 'Lesson imported.', 201);
} catch (Throwable $error) {
    error_response($error->getMessage(), 500);
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

function nullable_limited(?string $value, int $max, string $field): ?string
{
    if ($value === null) {
        return null;
    }
    return limit_text($value, $max, $field);
}
