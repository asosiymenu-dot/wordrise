<?php

require_once __DIR__ . '/../helpers/auth.php';

function auth_user(): array
{
    $token = bearer_token();
    if ($token === null) {
        error_response('Authorization token required.', 401);
    }

    $tokensTable = Database::table('api_tokens');
    $usersTable = Database::table('users');
    $stmt = Database::connection()->prepare(
        "SELECT u.*
         FROM {$tokensTable} t
         INNER JOIN {$usersTable} u ON u.id = t.user_id
         WHERE t.token_hash = ? AND t.expires_at > NOW()
         LIMIT 1"
    );
    $stmt->execute([token_hash($token)]);
    $user = $stmt->fetch();

    if (!$user) {
        error_response('Invalid or expired token.', 401);
    }

    return $user;
}

function require_role(array $user, array $roles): void
{
    if (!in_array($user['role'], $roles, true)) {
        error_response('Forbidden.', 403);
    }
}
