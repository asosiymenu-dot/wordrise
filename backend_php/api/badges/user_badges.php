<?php

require_once __DIR__ . '/../../helpers/response.php';
require_once __DIR__ . '/../../middleware/auth_middleware.php';
require_once __DIR__ . '/../../models/Badge.php';

require_method('GET');

$user = auth_user();
success_response(['badges' => Badge::userBadges((int)$user['id'])]);
