<?php

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../helpers/datetime.php';

final class AppRelease
{
    public static function latest(string $platform): ?array
    {
        $releases = Database::table('app_releases');
        $stmt = Database::connection()->prepare(
            "SELECT * FROM {$releases}
             WHERE platform = ? AND is_active = 1 AND published_at <= NOW()
             ORDER BY version_code DESC, id DESC
             LIMIT 1"
        );
        $stmt->execute([$platform]);
        $release = $stmt->fetch();
        return $release ?: null;
    }

    public static function forClient(
        string $platform,
        int $currentVersionCode,
        string $locale
    ): array {
        $release = self::latest($platform);
        if (!$release) {
            return [
                'current_version_code' => $currentVersionCode,
                'update_available' => false,
                'force_update' => false,
                'release' => null,
            ];
        }

        $latestCode = (int)$release['version_code'];
        $updateAvailable = $latestCode > $currentVersionCode;
        $forceUpdate = $updateAvailable && (
            (bool)$release['is_required']
            || $currentVersionCode < (int)$release['min_supported_version_code']
        );
        return [
            'current_version_code' => $currentVersionCode,
            'update_available' => $updateAvailable,
            'force_update' => $forceUpdate,
            'release' => self::payload($release, $locale),
        ];
    }

    public static function publish(array $data, ?int $createdBy): array
    {
        $releases = Database::table('app_releases');
        $pdo = Database::connection();
        $pdo->beginTransaction();
        try {
            $deactivate = $pdo->prepare(
                "UPDATE {$releases} SET is_active = 0 WHERE platform = ?"
            );
            $deactivate->execute([$data['platform']]);

            $stmt = $pdo->prepare(
                "INSERT INTO {$releases} (
                    platform, version_name, version_code,
                    min_supported_version_code, download_url,
                    release_notes_uz, release_notes_en, release_notes_ru,
                    sha256, file_size_bytes, is_required, is_active,
                    published_at, created_by
                 ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, NOW(), ?)
                 ON DUPLICATE KEY UPDATE
                    version_name = VALUES(version_name),
                    min_supported_version_code = VALUES(min_supported_version_code),
                    download_url = VALUES(download_url),
                    release_notes_uz = VALUES(release_notes_uz),
                    release_notes_en = VALUES(release_notes_en),
                    release_notes_ru = VALUES(release_notes_ru),
                    sha256 = VALUES(sha256),
                    file_size_bytes = VALUES(file_size_bytes),
                    is_required = VALUES(is_required),
                    is_active = 1,
                    published_at = NOW(),
                    created_by = VALUES(created_by)"
            );
            $stmt->execute([
                $data['platform'],
                $data['version_name'],
                $data['version_code'],
                $data['min_supported_version_code'],
                $data['download_url'],
                $data['release_notes_uz'] ?? null,
                $data['release_notes_en'] ?? null,
                $data['release_notes_ru'] ?? null,
                $data['sha256'] ?? null,
                $data['file_size_bytes'] ?? null,
                !empty($data['is_required']) ? 1 : 0,
                $createdBy,
            ]);
            $pdo->commit();
        } catch (Throwable $error) {
            if ($pdo->inTransaction()) {
                $pdo->rollBack();
            }
            throw $error;
        }

        $release = self::latest($data['platform']);
        if (!$release) {
            throw new RuntimeException('Published release was not found.');
        }
        return self::payload($release, 'en');
    }

    public static function payload(array $release, string $locale): array
    {
        $language = in_array($locale, ['uz', 'en', 'ru'], true) ? $locale : 'en';
        $notes = trim((string)($release['release_notes_' . $language] ?? ''));
        if ($notes === '') {
            $notes = trim((string)($release['release_notes_en'] ?? ''));
        }
        return [
            'platform' => (string)$release['platform'],
            'version_name' => (string)$release['version_name'],
            'version_code' => (int)$release['version_code'],
            'min_supported_version_code' => (int)$release['min_supported_version_code'],
            'download_url' => (string)$release['download_url'],
            'release_notes' => $notes === '' ? null : $notes,
            'sha256' => $release['sha256'] ?: null,
            'file_size_bytes' => $release['file_size_bytes'] === null
                ? null
                : (int)$release['file_size_bytes'],
            'is_required' => (bool)$release['is_required'],
            'published_at' => api_iso_datetime($release['published_at'] ?? null),
        ];
    }
}
