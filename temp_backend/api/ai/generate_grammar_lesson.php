<?php

require_once __DIR__ . '/../../helpers/response.php';
require_once __DIR__ . '/../../middleware/auth_middleware.php';
require_once __DIR__ . '/../../helpers/ai.php';

require_method('POST');

try {
    $user = auth_user();
    require_role($user, ['admin', 'teacher']);
    ai_rate_limit($user, 'generate_grammar_lesson', 4, 60);

    $data = request_json();
    $level = strtoupper(trim((string)($data['level'] ?? 'A1')));
    $topic = trim((string)($data['topic'] ?? ''));
    if ($topic === '') {
        error_response('topic is required.', 422);
    }

    $prompt = "O'zbek tilida so'zlashuvchi ingliz tili o'rganuvchilar uchun {$level} darajadagi '{$topic}' grammatika darsini tayyorla. Faqat JSON qaytar, boshqa matn yozma. Schema: {\"level\":\"A1|A2|B1|B2|C1|C2\",\"topic\":\"string\",\"icon\":\"school\",\"duration_minutes\":10,\"lesson\":{\"title\":\"string\",\"explanation_uz\":\"sodda va aniq o'zbekcha qoida tushuntirish\",\"examples\":[{\"en\":\"English sentence\",\"uz\":\"O'zbek tarjima\"}],\"common_mistakes\":\"Uzbek tilida so'zlashuvchilar ko'p qiladigan xatolar\"},\"exercises\":[{\"type\":\"fill_blank|multiple_choice|reorder_words|error_correction|translate\",\"question\":\"string\",\"options\":[\"string\"],\"correct_answer\":\"string\",\"correct_answers\":[\"string\"],\"explanation\":\"nega bu javob to'g'ri\"}]}. 5 ta example va 8-10 ta aralash mashq ber. A1 juda sodda, C1 murakkab bo'lsin.";
    $result = gemini_json($prompt);

    success_response(normalize_grammar_generation($result, $level, $topic));
} catch (Throwable $error) {
    error_response($error->getMessage(), $error instanceof LogicException ? 403 : 500);
}

function normalize_grammar_generation(array $data, string $level, string $topic): array
{
    $lesson = is_array($data['lesson'] ?? null) ? $data['lesson'] : [];
    $exercises = is_array($data['exercises'] ?? null) ? $data['exercises'] : [];
    return [
        'level' => strtoupper(trim((string)($data['level'] ?? $level))),
        'topic' => trim((string)($data['topic'] ?? $topic)),
        'icon' => trim((string)($data['icon'] ?? 'school')),
        'duration_minutes' => max(5, min((int)($data['duration_minutes'] ?? 10), 40)),
        'lesson' => [
            'title' => trim((string)($lesson['title'] ?? $topic)),
            'explanation_uz' => trim((string)($lesson['explanation_uz'] ?? ($lesson['content'] ?? ''))),
            'examples' => array_values(array_slice(is_array($lesson['examples'] ?? null) ? $lesson['examples'] : [], 0, 5)),
            'common_mistakes' => trim((string)($lesson['common_mistakes'] ?? '')),
        ],
        'exercises' => array_values(array_slice(array_map('normalize_generated_exercise', $exercises), 0, 10)),
    ];
}

function normalize_generated_exercise($item): array
{
    $item = is_array($item) ? $item : [];
    $correct = trim((string)($item['correct_answer'] ?? ($item['answer'] ?? '')));
    $answers = is_array($item['correct_answers'] ?? null) ? $item['correct_answers'] : [$correct];
    return [
        'type' => trim((string)($item['type'] ?? ($item['exercise_type'] ?? 'multiple_choice'))),
        'question' => trim((string)($item['question'] ?? '')),
        'options' => array_values(array_slice(is_array($item['options'] ?? null) ? $item['options'] : [], 0, 6)),
        'correct_answer' => $correct,
        'correct_answers' => array_values(array_map('strval', $answers)),
        'explanation' => trim((string)($item['explanation'] ?? '')),
    ];
}
