param (
    [string]$ftpServer = "176.9.111.172",
    [string]$ftpUser = "69a7b993de9dc",
    [string]$ftpPass = 'd4)BX\Cv2q1y)P#aw!XP<vP^Bv1}uB9\',
    [string]$localDir = "backend_php",
    [string]$remoteDir = "www/69a7b993deaa3.goldxost.ru/wordrise-api"
)

function Upload-FtpDirectory {
    param (
        [string]$localPath,
        [string]$remotePath
    )

    # Ensure remote directory exists
    try {
        $request = [System.Net.FtpWebRequest]::Create("ftp://$ftpServer/$remotePath")
        $request.Method = [System.Net.WebRequestMethods+Ftp]::MakeDirectory
        $request.Credentials = New-Object System.Net.NetworkCredential($ftpUser, $ftpPass)
        $response = $request.GetResponse()
        $response.Close()
        Write-Host "Created remote directory: $remotePath"
    } catch {
        # Directory might already exist
    }

    $items = Get-ChildItem -Path $localPath
    foreach ($item in $items) {
        $remoteItemPath = "$remotePath/" + $item.Name
        if ($item.PSIsContainer) {
            Upload-FtpDirectory -localPath $item.FullName -remotePath $remoteItemPath
        } else {
            Write-Host "Uploading $($item.FullName) to $remoteItemPath"
            try {
                $request = [System.Net.FtpWebRequest]::Create("ftp://$ftpServer/$remoteItemPath")
                $request.Method = [System.Net.WebRequestMethods+Ftp]::UploadFile
                $request.Credentials = New-Object System.Net.NetworkCredential($ftpUser, $ftpPass)
                
                $fileBytes = [System.IO.File]::ReadAllBytes($item.FullName)
                $request.ContentLength = $fileBytes.Length
                $requestStream = $request.GetRequestStream()
                $requestStream.Write($fileBytes, 0, $fileBytes.Length)
                $requestStream.Close()

                $response = $request.GetResponse()
                $response.Close()
            } catch {
                Write-Host "Failed to upload $($item.FullName): $_"
            }
        }
    }
}

Write-Host "Starting upload..."
Upload-FtpDirectory -localPath $localDir -remotePath $remoteDir
Write-Host "Upload complete."
