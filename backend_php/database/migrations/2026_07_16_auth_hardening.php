<?php

require_once __DIR__ . '/../../config/database.php';

$table = Database::table('auth_rate_limits');
Database::connection()->exec("CREATE TABLE IF NOT EXISTS {$table} (
  scope VARCHAR(32) NOT NULL,
  fingerprint CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  attempts SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  window_started_at DATETIME NOT NULL,
  blocked_until DATETIME NULL,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (scope, fingerprint),
  INDEX idx_auth_rate_blocked (blocked_until)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");

echo "2026_07_16_auth_hardening ok\n";
