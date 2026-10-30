<?php
ini_set('display_errors', 1);
error_reporting(E_ALL);

require_once __DIR__ . '/config/database.php';
require_once __DIR__ . '/models/AppRelease.php';

try {
    $data = [
        'platform' => 'android',
        'version_name' => '4.0.2',
        'version_code' => 2,
        'min_supported_version_code' => 2,
        'download_url' => 'https://69a7b993deaa3.goldxost.ru/wordrise-api/app-release.apk',
        'release_notes_uz' => 'Majburiy yangilanish. Asosiy muammolar hal etildi va ilova tezligi oshirildi.',
        'release_notes_en' => 'Mandatory update. Critical bugs fixed and performance improved.',
        'release_notes_ru' => 'Обязательное обновление. Критические ошибки исправлены, производительность улучшена.',
        'sha256' => null,
        'file_size_bytes' => filesize(__DIR__ . '/app-release.apk'),
        'is_required' => 1,
    ];
    $result = AppRelease::publish($data, null);
    echo json_encode(['success' => true, 'result' => $result]);
} catch (Throwable $e) {
    echo json_encode(['success' => false, 'error' => $e->getMessage()]);
}
?>
