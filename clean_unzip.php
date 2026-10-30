<?php
$zip = new ZipArchive;
if ($zip->open('backend_ws_session.zip') === TRUE) {
    $zip->extractTo('wordrise-api/');
    $zip->close();
    echo 'unzipped successfully';
} else {
    echo 'failed to open zip';
}
?>
