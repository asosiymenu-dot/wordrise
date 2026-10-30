<?php

require_once __DIR__ . '/../../helpers/response.php';
require_once __DIR__ . '/../../middleware/auth_middleware.php';
require_once __DIR__ . '/../../models/Battle.php';

require_method('POST');

try {
    $user = auth_user();
    $data = request_json();
    $roomCode = trim((string)($data['room_code'] ?? ''));

    $battle = Battle::join($user, $roomCode);
    success_response(['battle' => $battle], 'Battle boshlandi.');
} catch (InvalidArgumentException $error) {
    error_response($error->getMessage(), 422);
} catch (LogicException $error) {
    error_response($error->getMessage(), 403);
} catch (RuntimeException $error) {
    error_response($error->getMessage(), 409);
} catch (Throwable $error) {
    error_response($error->getMessage(), 500);
}
