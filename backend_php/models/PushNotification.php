<?php

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../config/firebase.php';

final class PushNotification
{
    private static $accessToken = null;

    public static function registerDevice(
        int $userId,
        string $token,
        string $platform,
        string $locale
    ): array {
        $token = trim($token);
        if (strlen($token) < 20 || strlen($token) > 512) {
            throw new InvalidArgumentException('Invalid device token.');
        }
        if (!in_array($platform, ['android', 'ios', 'web', 'unknown'], true)) {
            $platform = 'unknown';
        }
        if (!in_array($locale, ['uz', 'en', 'ru'], true)) {
            $locale = 'uz';
        }
        $table = Database::table('device_tokens');
        $stmt = Database::connection()->prepare(
            "INSERT INTO {$table} (user_id, token, platform, locale, active, last_seen_at)
             VALUES (?, ?, ?, ?, 1, NOW())
             ON DUPLICATE KEY UPDATE user_id = VALUES(user_id), platform = VALUES(platform),
                 locale = VALUES(locale), active = 1, last_seen_at = NOW(), updated_at = NOW()"
        );
        $stmt->execute([$userId, $token, $platform, $locale]);
        return [
            'registered' => true,
            'push_configured' => firebase_configured(),
        ];
    }

    public static function unregisterDevice(int $userId, string $token): void
    {
        $table = Database::table('device_tokens');
        $stmt = Database::connection()->prepare(
            "UPDATE {$table} SET active = 0, updated_at = NOW() WHERE user_id = ? AND token = ?"
        );
        $stmt->execute([$userId, trim($token)]);
    }

    public static function sendToUser(
        int $userId,
        string $type,
        string $title,
        string $body,
        array $data = []
    ): array {
        if (!firebase_configured()) {
            return ['configured' => false, 'sent' => 0, 'failed' => 0];
        }
        $accessToken = self::accessToken();
        if ($accessToken === null) {
            return ['configured' => true, 'sent' => 0, 'failed' => 1];
        }
        $table = Database::table('device_tokens');
        $stmt = Database::connection()->prepare(
            "SELECT id, token, locale FROM {$table}
             WHERE user_id = ? AND active = 1 ORDER BY last_seen_at DESC LIMIT 10"
        );
        $stmt->execute([$userId]);
        $sent = 0;
        $failed = 0;
        foreach ($stmt->fetchAll() as $device) {
            $copy = self::localizedCopy(
                (string)$device['locale'],
                $type,
                $title,
                $body,
                $data
            );
            $result = self::sendToken(
                (string)$device['token'],
                $accessToken,
                $copy['title'],
                $copy['body'],
                array_merge($data, ['type' => $type])
            );
            if ($result['success']) {
                $sent++;
            } else {
                $failed++;
                if ($result['invalid_token']) {
                    $disable = Database::connection()->prepare(
                        "UPDATE {$table} SET active = 0, updated_at = NOW() WHERE id = ?"
                    );
                    $disable->execute([(int)$device['id']]);
                }
            }
        }
        return ['configured' => true, 'sent' => $sent, 'failed' => $failed];
    }

    private static function accessToken(): ?string
    {
        if (is_string(self::$accessToken) && self::$accessToken !== '') {
            return self::$accessToken;
        }
        if (!function_exists('openssl_sign') || !function_exists('curl_init')) {
            return null;
        }
        $now = time();
        $header = self::base64Url(json_encode(['alg' => 'RS256', 'typ' => 'JWT']));
        $claims = self::base64Url(json_encode([
            'iss' => FIREBASE_CLIENT_EMAIL,
            'scope' => 'https://www.googleapis.com/auth/firebase.messaging',
            'aud' => 'https://oauth2.googleapis.com/token',
            'iat' => $now,
            'exp' => $now + 3500,
        ]));
        $unsigned = $header . '.' . $claims;
        $signature = '';
        if (!openssl_sign($unsigned, $signature, FIREBASE_PRIVATE_KEY, OPENSSL_ALGO_SHA256)) {
            return null;
        }
        $assertion = $unsigned . '.' . self::base64Url($signature);
        $curl = curl_init('https://oauth2.googleapis.com/token');
        curl_setopt_array($curl, [
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_POST => true,
            CURLOPT_POSTFIELDS => http_build_query([
                'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
                'assertion' => $assertion,
            ]),
            CURLOPT_HTTPHEADER => ['Content-Type: application/x-www-form-urlencoded'],
            CURLOPT_TIMEOUT => 15,
        ]);
        $raw = curl_exec($curl);
        $status = (int)curl_getinfo($curl, CURLINFO_HTTP_CODE);
        curl_close($curl);
        if (!is_string($raw) || $status < 200 || $status >= 300) {
            return null;
        }
        $decoded = json_decode($raw, true);
        self::$accessToken = is_array($decoded) ? ($decoded['access_token'] ?? null) : null;
        return is_string(self::$accessToken) ? self::$accessToken : null;
    }

    private static function sendToken(
        string $token,
        string $accessToken,
        string $title,
        string $body,
        array $data
    ): array {
        $stringData = [];
        foreach ($data as $key => $value) {
            if ($value === null) {
                continue;
            }
            $stringData[(string)$key] = is_scalar($value)
                ? (string)$value
                : json_encode($value, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
        }
        $payload = [
            'message' => [
                'token' => $token,
                'notification' => ['title' => $title, 'body' => $body],
                'data' => $stringData,
                'android' => [
                    'priority' => 'high',
                    'notification' => [
                        'channel_id' => 'wordrise_activity',
                        'sound' => 'default',
                    ],
                ],
                'apns' => ['payload' => ['aps' => ['sound' => 'default']]],
            ],
        ];
        $url = 'https://fcm.googleapis.com/v1/projects/'
            . rawurlencode(FIREBASE_PROJECT_ID) . '/messages:send';
        $curl = curl_init($url);
        curl_setopt_array($curl, [
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_POST => true,
            CURLOPT_POSTFIELDS => json_encode($payload, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES),
            CURLOPT_HTTPHEADER => [
                'Authorization: Bearer ' . $accessToken,
                'Content-Type: application/json',
            ],
            CURLOPT_TIMEOUT => 15,
        ]);
        $raw = curl_exec($curl);
        $status = (int)curl_getinfo($curl, CURLINFO_HTTP_CODE);
        curl_close($curl);
        $success = is_string($raw) && $status >= 200 && $status < 300;
        $upper = strtoupper(is_string($raw) ? $raw : '');
        return [
            'success' => $success,
            'invalid_token' => !$success
                && (strpos($upper, 'UNREGISTERED') !== false || strpos($upper, 'INVALID_ARGUMENT') !== false),
        ];
    }

    private static function localizedCopy(
        string $locale,
        string $type,
        string $title,
        string $body,
        array $data
    ): array {
        $locale = in_array($locale, ['uz', 'en', 'ru'], true) ? $locale : 'uz';
        $name = trim((string)($data['sender_name'] ?? $data['responder_name'] ?? ''));
        $winner = trim((string)($data['winner_name'] ?? ''));
        $draw = filter_var($data['draw'] ?? false, FILTER_VALIDATE_BOOLEAN);
        $copy = [
            'uz' => [
                'battle_invite' => ['Yangi Battle taklifi', ($name ?: 'Doʼstingiz') . ' sizni Vocabulary Battleʼga taklif qildi.'],
                'battle_accepted' => ['Battle qabul qilindi', ($name ?: 'Raqib') . ' taklifingizni qabul qildi.'],
                'battle_declined' => ['Battle rad etildi', 'Raqib battle taklifini rad etdi.'],
                'battle_cancelled' => ['Battle bekor qilindi', 'Battle taklifi bekor qilindi.'],
                'battle_result' => ['Battle yakunlandi', $draw ? 'Battle durang bilan yakunlandi.' : 'Gʼolib: ' . ($winner ?: 'aniqlanmadi')],
                'daily_reminder' => ['Bugungi mashgʼulot', 'Bugungi soʼzlarni bir necha daqiqada takrorlab oling.'],
                'streak_risk' => ['Streak xavfda', 'Bugun mashq qiling yoki streak-freeze ishlatiladi.'],
                'message' => [$name ?: 'Yangi xabar', $body],
                'admin_message' => ['@admin', $body],
            ],
            'en' => [
                'battle_invite' => ['New battle invite', ($name ?: 'A friend') . ' invited you to a Vocabulary Battle.'],
                'battle_accepted' => ['Battle accepted', ($name ?: 'Your opponent') . ' accepted your invite.'],
                'battle_declined' => ['Battle declined', 'Your opponent declined the battle invite.'],
                'battle_cancelled' => ['Battle cancelled', 'The battle invite was cancelled.'],
                'battle_result' => ['Battle finished', $draw ? 'The battle ended in a draw.' : 'Winner: ' . ($winner ?: 'unknown')],
                'daily_reminder' => ["Today's practice", 'Review today\'s words in just a few minutes.'],
                'streak_risk' => ['Your streak is at risk', 'Practice today or a streak freeze will be used.'],
                'message' => [$name ?: 'New message', $body],
                'admin_message' => ['@admin', $body],
            ],
            'ru' => [
                'battle_invite' => ['Новое приглашение на Battle', ($name ?: 'Друг') . ' приглашает вас на Vocabulary Battle.'],
                'battle_accepted' => ['Battle принят', ($name ?: 'Соперник') . ' принял ваше приглашение.'],
                'battle_declined' => ['Battle отклонен', 'Соперник отклонил приглашение.'],
                'battle_cancelled' => ['Battle отменен', 'Приглашение на Battle отменено.'],
                'battle_result' => ['Battle завершен', $draw ? 'Battle завершился вничью.' : 'Победитель: ' . ($winner ?: 'не определен')],
                'daily_reminder' => ['Сегодняшняя тренировка', 'Повторите сегодняшние слова за несколько минут.'],
                'streak_risk' => ['Streak под угрозой', 'Позанимайтесь сегодня, иначе будет использована заморозка.'],
                'message' => [$name ?: 'Новое сообщение', $body],
                'admin_message' => ['@admin', $body],
            ],
        ];
        if (!isset($copy[$locale][$type])) {
            return ['title' => $title, 'body' => $body];
        }
        return [
            'title' => $copy[$locale][$type][0],
            'body' => $copy[$locale][$type][1],
        ];
    }

    private static function base64Url(string $value): string
    {
        return rtrim(strtr(base64_encode($value), '+/', '-_'), '=');
    }
}
