<?php

require_once __DIR__ . '/cors.php';

$envFile = __DIR__ . '/env.php';
if (is_file($envFile)) {
    require_once $envFile;
}

$appTimezone = getenv('APP_TIMEZONE') ?: 'Asia/Tashkent';
if (!in_array($appTimezone, timezone_identifiers_list(), true)) {
    throw new RuntimeException('Invalid APP_TIMEZONE.');
}
date_default_timezone_set($appTimezone);

final class Database
{
    private static $connection = null;

    public static function table(string $name): string
    {
        $prefix = getenv('DB_PREFIX') ?: '';
        if ($prefix !== '' && !preg_match('/^[A-Za-z0-9_]+$/', $prefix)) {
            throw new RuntimeException('Invalid DB_PREFIX.');
        }
        if (!preg_match('/^[A-Za-z0-9_]+$/', $name)) {
            throw new RuntimeException('Invalid table name.');
        }
        return $prefix . $name;
    }

    public static function connection(): PDO
    {
        if (self::$connection instanceof PDO) {
            return self::$connection;
        }

        $host = getenv('DB_HOST') ?: '127.0.0.1';
        $port = getenv('DB_PORT') ?: '3306';
        $database = getenv('DB_NAME') ?: 'wordrise';
        $username = getenv('DB_USER') ?: 'root';
        $password = getenv('DB_PASS') ?: '';

        $dsn = "mysql:host={$host};port={$port};dbname={$database};charset=utf8mb4";

        self::$connection = new PDO($dsn, $username, $password, [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES => false,
        ]);
        $timezoneOffset = (new DateTimeImmutable())->format('P');
        self::$connection->exec(
            'SET time_zone = ' . self::$connection->quote($timezoneOffset)
        );

        return self::$connection;
    }
}
