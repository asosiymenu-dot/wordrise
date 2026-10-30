<?php
function rmdir_recursive($dir) {
    if (is_dir($dir)) {
        $objects = scandir($dir);
        foreach ($objects as $object) {
            if ($object != "." && $object != "..") {
                if (is_dir($dir. DIRECTORY_SEPARATOR .$object) && !is_link($dir."/".$object))
                    rmdir_recursive($dir. DIRECTORY_SEPARATOR .$object);
                else
                    unlink($dir. DIRECTORY_SEPARATOR .$object);
            }
        }
        rmdir($dir);
    }
}
rmdir_recursive('admin');
mkdir('admin', 0755, true);

$zip = new ZipArchive;
$res = $zip->open('admin.zip');
if ($res === TRUE) {
    $zip->extractTo('./admin/');
    $zip->close();
    echo 'ok';
} else {
    echo 'failed';
}
