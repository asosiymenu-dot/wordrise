<?php
\ = new ZipArchive;
if (\->open('backend_ws.zip') === TRUE) {
    \->extractTo('wordrise-api/');
    \->close();
    echo 'ok';
} else {
    echo 'failed';
}
?>
