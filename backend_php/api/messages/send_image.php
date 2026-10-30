<?php

require_once __DIR__ . '/../../helpers/response.php';
require_once __DIR__ . '/../../helpers/message_rate_limit.php';
require_once __DIR__ . '/../../middleware/auth_middleware.php';
require_once __DIR__ . '/../../models/Message.php';

require_method('POST');

$storedFiles = [];

try {
    $user = auth_user();
    enforce_message_rate_limit((int)$user['id'], 'message_image', 8, 60);
    $receiverId = max(0, (int)($_POST['receiver_id'] ?? 0));
    $replyToMessageId = max(0, (int)($_POST['reply_to_message_id'] ?? 0));
    $clientMessageId = trim((string)($_POST['client_message_id'] ?? ''));
    $body = trim((string)($_POST['body'] ?? ''));
    if ($receiverId <= 0) {
        error_response('receiver_id is required.', 422);
    }
    if (!isset($_FILES['image']) || !is_array($_FILES['image'])) {
        error_response('image is required.', 422);
    }

    $file = $_FILES['image'];
    if ((int)($file['error'] ?? UPLOAD_ERR_NO_FILE) !== UPLOAD_ERR_OK) {
        error_response('Image upload failed.', 422);
    }
    $size = (int)($file['size'] ?? 0);
    $temporaryPath = (string)($file['tmp_name'] ?? '');
    if ($size <= 0 || $size > 2 * 1024 * 1024 || !is_uploaded_file($temporaryPath)) {
        error_response('Image is too large or invalid. Max size is 2MB.', 422);
    }

    $finfo = new finfo(FILEINFO_MIME_TYPE);
    $mime = strtolower((string)$finfo->file($temporaryPath));
    $allowed = [
        'image/jpeg' => 'jpg',
        'image/png' => 'png',
        'image/webp' => 'webp',
    ];
    if (!isset($allowed[$mime])) {
        error_response('Only JPEG, PNG and WebP images are allowed.', 422);
    }
    $imageInfo = @getimagesize($temporaryPath);
    if (!$imageInfo || !isset($imageInfo[0], $imageInfo[1])) {
        error_response('Invalid image data.', 422);
    }
    $width = (int)$imageInfo[0];
    $height = (int)$imageInfo[1];
    $detectedMime = strtolower((string)($imageInfo['mime'] ?? ''));
    if ($width <= 0 || $height <= 0 || $width > 12000 || $height > 12000 || $width * $height > 40000000) {
        error_response('Image dimensions are not supported.', 422);
    }
    if ($detectedMime !== '' && $detectedMime !== $mime) {
        error_response('Image MIME type does not match its content.', 422);
    }

    $uploadDir = dirname(__DIR__, 2) . '/uploads/messages';
    if (!is_dir($uploadDir) && !mkdir($uploadDir, 0755, true) && !is_dir($uploadDir)) {
        throw new RuntimeException('Could not create message upload directory.');
    }
    message_protect_upload_directory_20260718($uploadDir);

    $token = bin2hex(random_bytes(24));
    $canReencode = function_exists('imagecreatefromstring') && function_exists('imagejpeg');
    $extension = $canReencode ? 'jpg' : $allowed[$mime];
    $fileName = $token . '.' . $extension;
    $thumbnailName = $token . '_thumb.jpg';
    $storagePath = $uploadDir . '/' . $fileName;
    $thumbnailPath = $uploadDir . '/' . $thumbnailName;

    if ($canReencode) {
        $storedFiles = [$storagePath, $thumbnailPath];
        $canPreserveJpeg = $mime === 'image/jpeg'
            && max($width, $height) <= 1280
            && message_jpeg_orientation_20260718($temporaryPath, $mime) === 1;
        if ($canPreserveJpeg) {
            if (!move_uploaded_file($temporaryPath, $storagePath)) {
                throw new RuntimeException('Image could not be stored.');
            }
            message_create_thumbnail_20260718(
                $storagePath,
                $thumbnailPath,
                'image/jpeg'
            );
        } else {
            $result = message_reencode_image_20260718(
                $temporaryPath,
                $storagePath,
                $thumbnailPath,
                $mime,
                $width,
                $height
            );
            $width = $result['width'];
            $height = $result['height'];
        }
        $mime = 'image/jpeg';
    } else {
        if (!move_uploaded_file($temporaryPath, $storagePath)) {
            throw new RuntimeException('Image could not be stored.');
        }
        $thumbnailPath = $storagePath;
        $thumbnailName = $fileName;
        $storedFiles = [$storagePath];
    }

    $storedSize = (int)filesize($storagePath);
    if ($storedSize <= 0 || $storedSize > 2 * 1024 * 1024) {
        throw new RuntimeException('Processed image is too large.');
    }

    $result = Message::sendImage(
        (int)$user['id'],
        $receiverId,
        [
            'storage_path' => 'uploads/messages/' . $fileName,
            'thumbnail_path' => 'uploads/messages/' . $thumbnailName,
            'mime_type' => $mime,
            'width' => $width,
            'height' => $height,
            'size_bytes' => $storedSize,
        ],
        $clientMessageId === '' ? null : $clientMessageId,
        $replyToMessageId > 0 ? $replyToMessageId : null,
        $body
    );

    if (!$result['created']) {
        message_cleanup_files_20260718($storedFiles);
    }
    success_response(
        ['message' => Message::publicData($result['message'], (int)$user['id'])],
        'Image sent.',
        $result['created'] ? 201 : 200
    );
} catch (OverflowException $error) {
    message_cleanup_files_20260718($storedFiles);
    error_response($error->getMessage(), 429);
} catch (DomainException $error) {
    message_cleanup_files_20260718($storedFiles);
    error_response($error->getMessage(), 403);
} catch (LogicException $error) {
    message_cleanup_files_20260718($storedFiles);
    error_response($error->getMessage(), 422);
} catch (RuntimeException $error) {
    message_cleanup_files_20260718($storedFiles);
    error_response($error->getMessage(), 422);
} catch (Throwable $error) {
    message_cleanup_files_20260718($storedFiles);
    error_response($error->getMessage(), 500);
}

function message_reencode_image_20260718(
    string $sourcePath,
    string $storagePath,
    string $thumbnailPath,
    string $mime,
    int $sourceWidth,
    int $sourceHeight
): array {
    $bytes = file_get_contents($sourcePath);
    $source = $bytes === false ? false : @imagecreatefromstring($bytes);
    if ($source === false) {
        throw new RuntimeException('Image could not be decoded.');
    }

    $source = message_apply_orientation_20260718($source, $sourcePath, $mime);
    $sourceWidth = imagesx($source);
    $sourceHeight = imagesy($source);
    $scale = min(1, 1280 / max($sourceWidth, $sourceHeight));
    $width = max(1, (int)round($sourceWidth * $scale));
    $height = max(1, (int)round($sourceHeight * $scale));
    $canvas = imagecreatetruecolor($width, $height);
    $white = imagecolorallocate($canvas, 255, 255, 255);
    imagefill($canvas, 0, 0, $white);
    imagecopyresampled(
        $canvas,
        $source,
        0,
        0,
        0,
        0,
        $width,
        $height,
        $sourceWidth,
        $sourceHeight
    );
    imageinterlace($canvas, true);
    $encoded = false;
    foreach ([87, 84, 80] as $quality) {
        if (!imagejpeg($canvas, $storagePath, $quality)) {
            continue;
        }
        clearstatcache(true, $storagePath);
        $encoded = true;
        if ((int)filesize($storagePath) <= 2 * 1024 * 1024) {
            break;
        }
    }
    if (!$encoded) {
        imagedestroy($canvas);
        imagedestroy($source);
        throw new RuntimeException('Image could not be encoded.');
    }

    try {
        message_write_thumbnail_20260718(
            $canvas,
            $width,
            $height,
            $thumbnailPath
        );
    } catch (Throwable $error) {
        imagedestroy($canvas);
        imagedestroy($source);
        throw $error;
    }

    imagedestroy($canvas);
    imagedestroy($source);
    return ['width' => $width, 'height' => $height];
}

function message_create_thumbnail_20260718(
    string $sourcePath,
    string $thumbnailPath,
    string $mime
): void {
    $bytes = file_get_contents($sourcePath);
    $source = $bytes === false ? false : @imagecreatefromstring($bytes);
    if ($source === false) {
        throw new RuntimeException('Thumbnail source could not be decoded.');
    }
    $source = message_apply_orientation_20260718($source, $sourcePath, $mime);
    try {
        message_write_thumbnail_20260718(
            $source,
            imagesx($source),
            imagesy($source),
            $thumbnailPath
        );
    } finally {
        imagedestroy($source);
    }
}

function message_write_thumbnail_20260718(
    $source,
    int $sourceWidth,
    int $sourceHeight,
    string $thumbnailPath
): void {
    $thumbScale = min(1, 320 / max($sourceWidth, $sourceHeight));
    $thumbWidth = max(1, (int)round($sourceWidth * $thumbScale));
    $thumbHeight = max(1, (int)round($sourceHeight * $thumbScale));
    $thumb = imagecreatetruecolor($thumbWidth, $thumbHeight);
    $thumbWhite = imagecolorallocate($thumb, 255, 255, 255);
    imagefill($thumb, 0, 0, $thumbWhite);
    imagecopyresampled(
        $thumb,
        $source,
        0,
        0,
        0,
        0,
        $thumbWidth,
        $thumbHeight,
        $sourceWidth,
        $sourceHeight
    );
    imageinterlace($thumb, true);
    if (!imagejpeg($thumb, $thumbnailPath, 87)) {
        imagedestroy($thumb);
        throw new RuntimeException('Thumbnail could not be encoded.');
    }
    imagedestroy($thumb);
}

function message_jpeg_orientation_20260718(string $path, string $mime): int
{
    if ($mime !== 'image/jpeg' || !function_exists('exif_read_data')) {
        return 1;
    }
    $exif = @exif_read_data($path);
    return max(1, (int)($exif['Orientation'] ?? 1));
}

function message_apply_orientation_20260718($image, string $path, string $mime)
{
    if ($mime !== 'image/jpeg' || !function_exists('exif_read_data')) {
        return $image;
    }
    $exif = @exif_read_data($path);
    $orientation = (int)($exif['Orientation'] ?? 1);
    $angle = $orientation === 3 ? 180 : ($orientation === 6 ? -90 : ($orientation === 8 ? 90 : 0));
    if ($angle === 0) {
        return $image;
    }
    $rotated = imagerotate($image, $angle, 0);
    if ($rotated !== false) {
        imagedestroy($image);
        return $rotated;
    }
    return $image;
}

function message_protect_upload_directory_20260718(string $directory): void
{
    $path = $directory . '/.htaccess';
    if (!is_file($path)) {
        @file_put_contents(
            $path,
            "Options -Indexes\n<FilesMatch \"\\.(php|php[0-9]?|phtml|phar|cgi|pl|py|sh)$\">\nRequire all denied\n</FilesMatch>\n"
        );
    }
}

function message_cleanup_files_20260718(array $paths): void
{
    foreach (array_unique($paths) as $path) {
        if (is_string($path) && is_file($path)) {
            @unlink($path);
        }
    }
}
