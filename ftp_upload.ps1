$ftpServer = "176.9.111.172"
$ftpUser = "69a7b993de9dc"
$ftpPass = 'd4)BX\Cv2q1y)P#aw!XP<vP^Bv1}uB9\'
$remotePath = "www/69a7b993deaa3.goldxost.ru/wordrise-api/"

function Upload-FtpFile {
    param(
        [string]$LocalFile,
        [string]$RemoteFileName
    )
    $uri = "ftp://$ftpServer/$remotePath$RemoteFileName"
    $webclient = New-Object System.Net.WebClient
    $webclient.Credentials = New-Object System.Net.NetworkCredential($ftpUser, $ftpPass)
    try {
        Write-Host "Uploading $LocalFile to $uri..."
        $webclient.UploadFile($uri, $LocalFile)
        Write-Host "Uploaded $RemoteFileName successfully."
    } catch {
        Write-Host "Failed to upload $RemoteFileName : $_"
    }
}

Upload-FtpFile "c:\Users\Abbosbek\Desktop\wordrisee\deploy.zip" "deploy.zip"
Upload-FtpFile "c:\Users\Abbosbek\Desktop\wordrisee\unzip.php" "unzip.php"
