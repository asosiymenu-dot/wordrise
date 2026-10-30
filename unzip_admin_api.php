<?php
$zip = new ZipArchive;
$res = $zip->open('admin_api.zip');
if ($res === TRUE) {
    $zip->extractTo('wordrise-api/api/');
    $zip->close();
    echo 'ok';
} else {
    echo 'failed';
}
