<?php

require_once __DIR__ . '/../config/cors.php';

function json_response(array $payload, int $status = 200): void
{
    http_response_code($status);
    echo json_encode($payload, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    exit;
}

function success_response(array $data = [], string $message = 'OK', int $status = 200): void
{
    json_response([
        'success' => true,
        'message' => $message,
        'data' => $data,
    ], $status);
}

function error_response(string $message, int $status = 400, array $errors = []): void
{
    if ($status >= 500) {
        @file_put_contents(__DIR__ . '/../error.log', date('Y-m-d H:i:s') . " [500] " . $message . "\n", FILE_APPEND);
        error_log('[WordRise API 500] ' . $message);
        if (getenv('APP_DEBUG') !== '1') {
            $message = 'Serverda xatolik yuz berdi: ' . $message;
        }
    }
    json_response([
        'success' => false,
        'message' => $message,
        'errors' => $errors,
    ], $status);
}

function request_json(): array
{
    $raw = file_get_contents('php://input');
    if ($raw === false || trim($raw) === '') {
        return [];
    }

    $decoded = json_decode($raw, true);
    if (!is_array($decoded)) {
        error_response('Invalid JSON body.', 422);
    }

    return $decoded;
}

function require_method(string $method): void
{
    if (($_SERVER['REQUEST_METHOD'] ?? '') !== strtoupper($method)) {
        error_response('Method not allowed.', 405);
    }
}

function required_string(array $data, string $key, int $max = 255): string
{
    $value = trim((string)($data[$key] ?? ''));
    if ($value === '') {
        error_response("{$key} is required.", 422);
    }
    if (strlen($value) > $max) {
        error_response("{$key} is too long.", 422);
    }
    return $value;
}

function optional_string(array $data, string $key, int $max = 255): ?string
{
    if (!array_key_exists($key, $data)) {
        return null;
    }
    $value = trim((string)$data[$key]);
    if ($value === '') {
        return null;
    }
    if (strlen($value) > $max) {
        error_response("{$key} is too long.", 422);
    }
    return $value;
}
