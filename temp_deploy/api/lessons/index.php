<?php

require_once __DIR__ . '/../../helpers/response.php';
require_once __DIR__ . '/../../middleware/auth_middleware.php';
require_once __DIR__ . '/../../models/Lesson.php';

require_method('GET');

$user = auth_user();
success_response(['lessons' => Lesson::allForUser($user)]);
