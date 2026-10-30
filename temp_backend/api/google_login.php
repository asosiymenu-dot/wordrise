<?php

require_once __DIR__ . '/../helpers/response.php';
require_once __DIR__ . '/../helpers/auth.php';
require_once __DIR__ . '/../helpers/google_id_token_verifier.php';
require_once __DIR__ . '/../models/User.php';

require_method('POST');

$rateLimitIdentifier = 'google';

try {
    $data = request_json();
    $idToken = required_string($data, 'id_token', 16384);
    enforce_login_rate_limit($rateLimitIdentifier);

    $identity = (new GoogleIdTokenVerifier())->verify($idToken);
    $user = User::loginOrCreateGoogle($identity);
    clear_login_failures($rateLimitIdentifier);
    $token = issue_token((int)$user['id']);

    success_response([
        'user' => User::publicData($user),
        'token' => $token['token'],
        'expires_at' => $token['expires_at'],
    ], 'Logged in with Google.');
} catch (GoogleTokenValidationException $error) {
    record_login_failure($rateLimitIdentifier, 10, 900, 900);
    error_response('Google sign-in could not be verified.', 401);
} catch (GoogleOAuthConfigurationException $error) {
    error_response($error->getMessage(), 503);
} catch (LogicException $error) {
    error_response($error->getMessage(), 409);
} catch (Throwable $error) {
    error_response($error->getMessage(), 500);
}
