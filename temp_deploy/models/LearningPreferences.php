<?php

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/AppNotification.php';

final class LearningPreferences
{
    public static function get(int $userId): array
    {
        $table = Database::table('user_learning_settings');
        $insert = Database::connection()->prepare(
            "INSERT IGNORE INTO {$table} (user_id, daily_goal_minutes, preferred_direction)
             VALUES (?, 10, 'mixed')"
        );
        $insert->execute([$userId]);
        $stmt = Database::connection()->prepare("SELECT * FROM {$table} WHERE user_id = ? LIMIT 1");
        $stmt->execute([$userId]);
        $row = $stmt->fetch();
        if (!$row) {
            throw new RuntimeException('Learning preferences could not be loaded.');
        }
        return self::publicData($row);
    }

    public static function update(int $userId, array $data): array
    {
        $current = self::get($userId);
        $reminderEnabled = array_key_exists('reminder_enabled', $data)
            ? filter_var($data['reminder_enabled'], FILTER_VALIDATE_BOOLEAN)
            : $current['reminder_enabled'];
        $riskEnabled = array_key_exists('streak_risk_enabled', $data)
            ? filter_var($data['streak_risk_enabled'], FILTER_VALIDATE_BOOLEAN)
            : $current['streak_risk_enabled'];
        $reminderHour = (int)($data['reminder_hour'] ?? $current['reminder_hour']);
        $reminderMinute = (int)($data['reminder_minute'] ?? $current['reminder_minute']);
        $riskHour = (int)($data['streak_risk_hour'] ?? $current['streak_risk_hour']);
        $riskMinute = (int)($data['streak_risk_minute'] ?? $current['streak_risk_minute']);
        $timezone = trim((string)($data['timezone'] ?? $current['timezone']));
        self::validateTime($reminderHour, $reminderMinute);
        self::validateTime($riskHour, $riskMinute);
        if (!in_array($timezone, timezone_identifiers_list(), true)) {
            throw new InvalidArgumentException('Invalid timezone.');
        }
        $table = Database::table('user_learning_settings');
        $stmt = Database::connection()->prepare(
            "UPDATE {$table}
             SET reminder_enabled = ?, reminder_hour = ?, reminder_minute = ?,
                 streak_risk_enabled = ?, streak_risk_hour = ?, streak_risk_minute = ?,
                 timezone = ?, updated_at = NOW()
             WHERE user_id = ?"
        );
        $stmt->execute([
            $reminderEnabled ? 1 : 0,
            $reminderHour,
            $reminderMinute,
            $riskEnabled ? 1 : 0,
            $riskHour,
            $riskMinute,
            $timezone,
            $userId,
        ]);
        return self::get($userId);
    }

    public static function dispatchDueReminders(): array
    {
        $users = Database::table('users');
        $settings = Database::table('user_learning_settings');
        $stmt = Database::connection()->query(
            "SELECT u.id, u.streak, u.last_active_date, s.*
             FROM {$users} u
             INNER JOIN {$settings} s ON s.user_id = u.id
             WHERE s.reminder_enabled = 1 OR s.streak_risk_enabled = 1"
        );
        $sent = 0;
        foreach ($stmt->fetchAll() as $row) {
            try {
                $timezone = new DateTimeZone((string)$row['timezone']);
                $now = new DateTimeImmutable('now', $timezone);
                $localDate = $now->format('Y-m-d');
                $studiedToday = (string)($row['last_active_date'] ?? '') === $localDate;
                if (!$studiedToday
                    && (int)$row['reminder_enabled'] === 1
                    && self::isDueTime($now, (int)$row['reminder_hour'], (int)$row['reminder_minute'])
                    && self::claimDispatch((int)$row['user_id'], 'daily_reminder', $localDate)
                ) {
                    AppNotification::create(
                        (int)$row['user_id'],
                        'daily_reminder',
                        'Bugungi mashgʼulot',
                        'Bugungi soʼzlarni bir necha daqiqada takrorlab oling.',
                        ['local_date' => $localDate]
                    );
                    $sent++;
                }
                if (!$studiedToday
                    && (int)$row['streak'] > 0
                    && (int)$row['streak_risk_enabled'] === 1
                    && self::isDueTime($now, (int)$row['streak_risk_hour'], (int)$row['streak_risk_minute'])
                    && self::claimDispatch((int)$row['user_id'], 'streak_risk', $localDate)
                ) {
                    AppNotification::create(
                        (int)$row['user_id'],
                        'streak_risk',
                        'Streak xavfda',
                        'Bugun mashq qiling yoki streak-freeze ishlatiladi.',
                        ['local_date' => $localDate, 'streak' => (int)$row['streak']]
                    );
                    $sent++;
                }
            } catch (Throwable $error) {
                error_log('[WordRise reminder] user=' . (int)$row['user_id'] . ' ' . $error->getMessage());
            }
        }
        return ['sent_count' => $sent];
    }

    private static function claimDispatch(int $userId, string $type, string $localDate): bool
    {
        $table = Database::table('notification_dispatch_log');
        $stmt = Database::connection()->prepare(
            "INSERT IGNORE INTO {$table} (user_id, notification_type, local_date) VALUES (?, ?, ?)"
        );
        $stmt->execute([$userId, $type, $localDate]);
        return $stmt->rowCount() === 1;
    }

    private static function isDueTime(DateTimeImmutable $now, int $hour, int $minute): bool
    {
        $target = $now->setTime($hour, $minute, 0);
        $difference = $now->getTimestamp() - $target->getTimestamp();
        return $difference >= 0 && $difference < 600;
    }

    private static function validateTime(int $hour, int $minute): void
    {
        if ($hour < 0 || $hour > 23 || $minute < 0 || $minute > 59) {
            throw new InvalidArgumentException('Invalid reminder time.');
        }
    }

    private static function publicData(array $row): array
    {
        return [
            'reminder_enabled' => (int)($row['reminder_enabled'] ?? 0) === 1,
            'reminder_hour' => (int)($row['reminder_hour'] ?? 19),
            'reminder_minute' => (int)($row['reminder_minute'] ?? 0),
            'streak_risk_enabled' => (int)($row['streak_risk_enabled'] ?? 1) === 1,
            'streak_risk_hour' => (int)($row['streak_risk_hour'] ?? 21),
            'streak_risk_minute' => (int)($row['streak_risk_minute'] ?? 0),
            'timezone' => (string)($row['timezone'] ?? 'Asia/Tashkent'),
        ];
    }
}
