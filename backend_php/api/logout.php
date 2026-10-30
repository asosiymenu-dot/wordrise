<?php

require_once __DIR__ . '/../helpers/response.php';
require_once __DIR__ . '/../middleware/auth_middleware.php';

require_method('POST');

auth_user();
revoke_current_token();
success_response([], 'Logged out.');
