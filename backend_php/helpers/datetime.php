<?php

function api_iso_datetime(?string $value): ?string
{
    $value = trim((string)$value);
    if ($value === '') {
        return null;
    }

    $timezone = new DateTimeZone(date_default_timezone_get());
    $date = DateTimeImmutable::createFromFormat('Y-m-d H:i:s', $value, $timezone);
    if (!$date) {
        try {
            $date = new DateTimeImmutable($value, $timezone);
        } catch (Throwable $error) {
            return null;
        }
    }

    return $date->format(DateTimeInterface::ATOM);
}

function api_is_online(?string $lastSeenAt, int $thresholdSeconds = 90): bool
{
    $lastSeenAt = trim((string)$lastSeenAt);
    if ($lastSeenAt === '') {
        return false;
    }

    try {
        $lastSeen = new DateTimeImmutable($lastSeenAt, new DateTimeZone(date_default_timezone_get()));
    } catch (Throwable $error) {
        return false;
    }

    return $lastSeen >= new DateTimeImmutable('-' . max(1, $thresholdSeconds) . ' seconds');
}

