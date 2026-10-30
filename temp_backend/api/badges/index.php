<?php

require_once __DIR__ . '/../../helpers/response.php';
require_once __DIR__ . '/../../middleware/auth_middleware.php';
require_once __DIR__ . '/../../models/Badge.php';

require_method('GET');

auth_user();
success_response(['badges' => Badge::all()]);
