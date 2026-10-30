<?php

require_once __DIR__ . '/../config/gemini.php';
require_once __DIR__ . '/response.php';

function ai_rate_limit(array $user, string $bucket, int $maxRequests = 12, int $windowSeconds = 60): void
{
    // AI usage limits are intentionally disabled for this product stage.
    return;
}

function gemini_json(string $prompt): array
{
    return gemini_json_parts([['text' => $prompt]]);
}

function gemini_json_with_image(string $prompt, string $imageBase64, string $mimeType): array
{
    return gemini_json_parts([
        ['text' => $prompt],
        [
            'inlineData' => [
                'mimeType' => $mimeType,
                'data' => $imageBase64,
            ],
        ],
    ]);
}

function gemini_json_parts(array $parts): array
{
    if (GEMINI_API_KEY === '') {
        error_response('Gemini API kaliti backendda sozlanmagan.', 503);
    }

    $url = 'https://generativelanguage.googleapis.com/v1beta/models/' . rawurlencode(GEMINI_MODEL) . ':generateContent?key=' . rawurlencode(GEMINI_API_KEY);
    $payload = [
        'contents' => [
            [
                'role' => 'user',
                'parts' => $parts,
            ],
        ],
        'generationConfig' => [
            'temperature' => 0.35,
            'responseMimeType' => 'application/json',
        ],
    ];

    $response = gemini_request($url, $payload);
    ai_log('gemini_response', [
        'model' => GEMINI_MODEL,
        'transport' => $response['transport'],
        'http_status' => $response['status'],
        'raw_preview' => substr((string)$response['body'], 0, 800),
    ]);

    $raw = (string)$response['body'];
    if ($raw === '' || trim($raw) === '') {
        ai_log('fallback_to_bazaarlink', ['reason' => 'Empty response from Gemini']);
        return bazaarlink_json_parts($parts);
    }

    $decoded = json_decode($raw, true);
    if (!is_array($decoded)) {
        ai_log('gemini_raw_json_error', [
            'json_error' => json_last_error_msg(),
            'raw_preview' => substr($raw, 0, 800),
        ]);
        error_response('AI servisidan notoʼgʼri javob keldi. Keyinroq qayta urinib koʼring.', 502);
    }
    if (isset($decoded['error']) && is_array($decoded['error'])) {
        $message = (string)($decoded['error']['message'] ?? 'Gemini API xatoligi.');
        $lower = strtolower($message);

        if (strpos($lower, 'quota') !== false || strpos($lower, 'rate') !== false || $response['status'] === 429) {
            ai_log('fallback_to_bazaarlink', ['reason' => $message]);
            return bazaarlink_json_parts($parts);
        }

        if (strpos($lower, 'not found') !== false || strpos($lower, 'not supported') !== false) {
            error_response('Gemini modeli bu API kalitida qoʼllab-quvvatlanmadi.', 502);
        }
        error_response('Gemini xizmatidan xatolik qaytdi. Keyinroq qayta urinib koʼring.', 502);
    }

    $text = $decoded['candidates'][0]['content']['parts'][0]['text'] ?? null;
    if (!is_string($text) || trim($text) === '') {
        ai_log('gemini_empty_text', [
            'decoded_keys' => implode(',', array_keys($decoded)),
            'raw_preview' => substr($raw, 0, 800),
        ]);
        error_response('AI javobi tushunarli formatda kelmadi.', 502);
    }

    $jsonText = extract_json_text($text);
    $result = json_decode($jsonText, true);
    if (!is_array($result)) {
        ai_log('gemini_content_json_error', [
            'json_error' => json_last_error_msg(),
            'text_preview' => substr($text, 0, 800),
            'clean_preview' => substr($jsonText, 0, 800),
        ]);
        error_response('AI JSON javobini oʼqib boʼlmadi.', 502);
    }
    return $result;
}

function gemini_request(string $url, array $payload): array
{
    $body = json_encode($payload, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    if (function_exists('curl_init')) {
        $curl = curl_init($url);
        curl_setopt_array($curl, [
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_POST => true,
            CURLOPT_POSTFIELDS => $body,
            CURLOPT_HTTPHEADER => ['Content-Type: application/json', 'Accept: application/json'],
            CURLOPT_TIMEOUT => 35,
        ]);
        $raw = curl_exec($curl);
        $status = (int)curl_getinfo($curl, CURLINFO_HTTP_CODE);
        $error = curl_error($curl);
        curl_close($curl);
        if ($raw === false) {
            ai_log('gemini_curl_error', ['error' => $error, 'http_status' => $status]);
            return ['status' => $status, 'body' => '', 'transport' => 'curl'];
        }
        return ['status' => $status, 'body' => (string)$raw, 'transport' => 'curl'];
    }

    $headers = "Content-Type: application/json\r\nAccept: application/json\r\n";
    $context = stream_context_create([
        'http' => [
            'method' => 'POST',
            'header' => $headers,
            'content' => $body,
            'timeout' => 35,
            'ignore_errors' => true,
        ],
        'ssl' => [
            'verify_peer' => true,
            'verify_peer_name' => true,
        ],
    ]);
    $raw = @file_get_contents($url, false, $context);
    $status = 0;
    if (isset($http_response_header) && is_array($http_response_header)) {
        foreach ($http_response_header as $header) {
            if (preg_match('/^HTTP\/\S+\s+(\d+)/', $header, $matches)) {
                $status = (int)$matches[1];
                break;
            }
        }
    }
    if ($raw === false) {
        $error = error_get_last();
        ai_log('gemini_stream_error', [
            'error' => is_array($error) ? ($error['message'] ?? '') : '',
            'http_status' => $status,
        ]);
        return ['status' => $status, 'body' => '', 'transport' => 'stream'];
    }
    return ['status' => $status, 'body' => (string)$raw, 'transport' => 'stream'];
}

function ai_environment_status(): array
{
    return [
        'model' => GEMINI_MODEL,
        'api_key_configured' => GEMINI_API_KEY !== '',
        'curl_available' => function_exists('curl_init'),
        'allow_url_fopen' => (bool)ini_get('allow_url_fopen'),
        'log_file' => ai_log_file(),
    ];
}

function ai_log(string $event, array $context = []): void
{
    $file = ai_log_file();
    $dir = dirname($file);
    if (!is_dir($dir)) {
        @mkdir($dir, 0755, true);
    }
    $context['event'] = $event;
    $context['time'] = date('c');
    unset($context['api_key']);
    @file_put_contents(
        $file,
        json_encode($context, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES) . PHP_EOL,
        FILE_APPEND
    );
}

function ai_log_file(): string
{
    return dirname(__DIR__) . '/logs/ai.log';
}

function extract_json_text(string $text): string
{
    $trimmed = trim($text);
    if (substr($trimmed, 0, 3) === '```') {
        $trimmed = preg_replace('/^```(?:json)?\\s*/i', '', $trimmed);
        $trimmed = preg_replace('/\\s*```$/', '', (string)$trimmed);
    }
    $trimmed = trim((string)$trimmed);
    $firstObject = strpos($trimmed, '{');
    $firstArray = strpos($trimmed, '[');
    $start = false;
    if ($firstObject !== false && $firstArray !== false) {
        $start = min($firstObject, $firstArray);
    } elseif ($firstObject !== false) {
        $start = $firstObject;
    } elseif ($firstArray !== false) {
        $start = $firstArray;
    }
    if ($start !== false && $start > 0) {
        $trimmed = substr($trimmed, $start);
    }
    return $trimmed;
}

function bazaarlink_json_parts(array $parts): array
{
    if (!defined('BAZAARLINK_API_KEY') || BAZAARLINK_API_KEY === '') {
        error_response('BazaarLink API kaliti sozlanmagan.', 503);
    }

    $content = [];
    foreach ($parts as $part) {
        if (isset($part['text'])) {
            $content[] = ['type' => 'text', 'text' => $part['text']];
        } elseif (isset($part['inlineData'])) {
            $content[] = [
                'type' => 'image_url',
                'image_url' => [
                    'url' => 'data:' . $part['inlineData']['mimeType'] . ';base64,' . $part['inlineData']['data']
                ]
            ];
        }
    }

    $payload = [
        'model' => GEMINI_MODEL, // e.g. google/gemini-2.5-flash
        'messages' => [
            [
                'role' => 'user',
                'content' => $content
            ]
        ],
        'temperature' => 0.35,
        'response_format' => ['type' => 'json_object']
    ];
    
    // Ensure model has 'google/' prefix for bazaarlink if missing
    if (strpos($payload['model'], '/') === false) {
        $payload['model'] = 'google/' . $payload['model'];
    }

    $url = 'https://api.bazaarlink.ai/v1/chat/completions';
    $headers = [
        'Content-Type: application/json',
        'Accept: application/json',
        'Authorization: Bearer ' . BAZAARLINK_API_KEY
    ];

    $body = json_encode($payload, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    
    $raw = '';
    $status = 0;
    if (function_exists('curl_init')) {
        $curl = curl_init($url);
        curl_setopt_array($curl, [
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_POST => true,
            CURLOPT_POSTFIELDS => $body,
            CURLOPT_HTTPHEADER => $headers,
            CURLOPT_TIMEOUT => 35,
        ]);
        $raw = curl_exec($curl);
        $status = (int)curl_getinfo($curl, CURLINFO_HTTP_CODE);
        curl_close($curl);
    } else {
        $context = stream_context_create([
            'http' => [
                'method' => 'POST',
                'header' => implode("\r\n", $headers) . "\r\n",
                'content' => $body,
                'timeout' => 35,
                'ignore_errors' => true,
            ]
        ]);
        $raw = @file_get_contents($url, false, $context);
    }

    if ($raw === '' || $raw === false) {
        error_response('BazaarLink AI xizmatidan javob kelmadi.', 502);
    }

    $decoded = json_decode($raw, true);
    if (!is_array($decoded)) {
        error_response('BazaarLink AI servisidan notoʼgʼri javob keldi.', 502);
    }
    
    if (isset($decoded['error'])) {
        error_response('BazaarLink xatoligi: ' . ($decoded['error']['message'] ?? 'Nomaʼlum xato'), 502);
    }

    $text = $decoded['choices'][0]['message']['content'] ?? null;
    if (!is_string($text) || trim($text) === '') {
        error_response('BazaarLink AI javobi tushunarli formatda kelmadi.', 502);
    }

    $jsonText = extract_json_text($text);
    $result = json_decode($jsonText, true);
    if (!is_array($result)) {
        error_response('BazaarLink AI JSON javobini oʼqib boʼlmadi.', 502);
    }
    return $result;
}
