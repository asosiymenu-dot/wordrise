<?php

require_once __DIR__ . '/../../helpers/response.php';
require_once __DIR__ . '/../../middleware/auth_middleware.php';
require_once __DIR__ . '/../../models/Word.php';

require_method('DELETE');

try {
    $user = auth_user();
    $data = request_json();
    $id = (int)($data['id'] ?? ($_GET['id'] ?? 0));
    if ($id <= 0) {
        error_response('id is required.', 422);
    }

    WordModel::delete($id, $user);
    success_response([], 'Word deleted.');
} catch (Throwable $error) {
    $status = $error instanceof LogicException ? 403 : 500;
    error_response($error->getMessage(), $status);
}
