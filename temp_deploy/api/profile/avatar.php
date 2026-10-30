<?php

require_once __DIR__ . '/../../helpers/response.php';
require_once __DIR__ . '/../../middleware/auth_middleware.php';
require_once __DIR__ . '/../../models/User.php';

try {
    $user = auth_user();
    $method = strtoupper($_SERVER['REQUEST_METHOD'] ?? '');

    if ($method === 'DELETE') {
        $oldAvatar = $user['avatar'] ?? null;
        $updated = User::updateAvatar((int)$user['id'], '');
        delete_local_avatar($oldAvatar);
        success_response(['user' => User::publicData($updated)], 'Avatar removed.');
    }

    if ($method !== 'POST') {
        error_response('Method not allowed.', 405);
    }

    $data = request_json();
    $raw = trim((string)($data['image_base64'] ?? ''));
    $mime = strtolower(trim((string)($data['mime_type'] ?? 'image/jpeg')));

    if ($raw === '') {
        error_response('image_base64 is required.', 422);
    }
    if (strpos($raw, ',') !== false) {
        $raw = substr($raw, strpos($raw, ',') + 1);
    }

    $bytes = base64_decode($raw, true);
    if ($bytes === false || strlen($bytes) === 0) {
        error_response('Invalid image.', 422);
    }
    if (strlen($bytes) > 3 * 1024 * 1024) {
        error_response('Image is too large. Max size is 3MB.', 422);
    }

    switch ($mime) {
        case 'image/png':
            $extension = 'png';
            break;
        case 'image/webp':
            $extension = 'webp';
            break;
        default:
            $extension = 'jpg';
            break;
    }
    if (!in_array($extension, ['jpg', 'png', 'webp'], true)) {
        error_response('Unsupported image type.', 422);
    }

    $uploadDir = dirname(__DIR__, 2) . '/uploads/avatars';
    if (!is_dir($uploadDir) && !mkdir($uploadDir, 0755, true) && !is_dir($uploadDir)) {
        throw new RuntimeException('Could not create upload directory.');
    }

    $fileName = 'user_' . (int)$user['id'] . '_' . time() . '.' . $extension;
    $path = $uploadDir . '/' . $fileName;
    file_put_contents($path, $bytes);

    $scheme = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') ? 'https' : 'http';
    $host = $_SERVER['HTTP_HOST'] ?? 'localhost';
    $scriptName = $_SERVER['SCRIPT_NAME'] ?? '';
    $basePath = preg_replace('#/api/.*$#', '', $scriptName);
    $basePath = rtrim((string)$basePath, '/');
    $avatarUrl = $scheme . '://' . $host . $basePath . '/uploads/avatars/' . $fileName;

    $oldAvatar = $user['avatar'] ?? null;
    $updated = User::updateAvatar((int)$user['id'], $avatarUrl);
    delete_local_avatar($oldAvatar);
    success_response(['user' => User::publicData($updated)], 'Avatar updated.');
} catch (Throwable $error) {
    error_response($error->getMessage(), 500);
}

function delete_local_avatar(?string $avatar): void
{
    if ($avatar === null || $avatar === '') {
        return;
    }
    if (!preg_match('#/uploads/avatars/([^/]+)$#', $avatar, $matches)) {
        return;
    }
    $path = dirname(__DIR__, 2) . '/uploads/avatars/' . $matches[1];
    if (is_file($path)) {
        @unlink($path);
    }
}
