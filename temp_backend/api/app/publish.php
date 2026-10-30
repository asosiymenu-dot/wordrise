<?php

require_once __DIR__ . '/../../helpers/response.php';
require_once __DIR__ . '/../../middleware/auth_middleware.php';
require_once __DIR__ . '/../../models/AppRelease.php';

require_method('POST');

try {
    $user = auth_user();
    if (($user['role'] ?? '') !== 'admin') {
        error_response('Admin access is required.', 403);
    }
    $data = request_json();
    $platform = strtolower(required_string($data, 'platform', 16));
    if (!in_array($platform, ['android', 'ios'], true)) {
        error_response('Unsupported platform.', 422);
    }
    $versionName = required_string($data, 'version_name', 32);
    if (!preg_match('/^[0-9]+(?:\.[0-9]+){1,3}(?:[-+][A-Za-z0-9.-]+)?$/', $versionName)) {
        error_response('Invalid version_name.', 422);
    }
    $versionCode = max(0, (int)($data['version_code'] ?? 0));
    $minimumCode = max(0, (int)($data['min_supported_version_code'] ?? 0));
    if ($versionCode <= 0 || $minimumCode <= 0 || $minimumCode > $versionCode) {
        error_response('Invalid version code.', 422);
    }
    $downloadUrl = required_string($data, 'download_url', 500);
    $uri = parse_url($downloadUrl);
    if (($uri['scheme'] ?? '') !== 'https' || empty($uri['host'])) {
        error_response('download_url must use HTTPS.', 422);
    }
    $sha256 = strtolower((string)(optional_string($data, 'sha256', 64) ?? ''));
    if ($sha256 !== '' && !preg_match('/^[a-f0-9]{64}$/', $sha256)) {
        error_response('Invalid sha256.', 422);
    }
    $fileSize = isset($data['file_size_bytes'])
        ? max(0, (int)$data['file_size_bytes'])
        : null;

    $release = AppRelease::publish([
        'platform' => $platform,
        'version_name' => $versionName,
        'version_code' => $versionCode,
        'min_supported_version_code' => $minimumCode,
        'download_url' => $downloadUrl,
        'release_notes_uz' => optional_string($data, 'release_notes_uz', 10000),
        'release_notes_en' => optional_string($data, 'release_notes_en', 10000),
        'release_notes_ru' => optional_string($data, 'release_notes_ru', 10000),
        'sha256' => $sha256 === '' ? null : $sha256,
        'file_size_bytes' => $fileSize === 0 ? null : $fileSize,
        'is_required' => filter_var(
            $data['is_required'] ?? true,
            FILTER_VALIDATE_BOOLEAN
        ),
    ], (int)$user['id']);
    success_response(['release' => $release], 'Release published.', 201);
} catch (Throwable $error) {
    error_response($error->getMessage(), 500);
}
