<?php
ini_set('display_errors', 1);
error_reporting(E_ALL);

$dir = __DIR__ . '/wordrise-api/';
$files = scandir($dir);

foreach ($files as $file) {
    if (strpos($file, '\\') !== false) {
        $oldPath = $dir . $file;
        $newPath = $dir . str_replace('\\', '/', $file);
        
        $targetDir = dirname($newPath);
        if (!is_dir($targetDir)) {
            mkdir($targetDir, 0777, true);
        }
        
        if (rename($oldPath, $newPath)) {
            echo "Renamed $file to $newPath\n";
        } else {
            echo "Failed to rename $file\n";
        }
    }
}
?>
