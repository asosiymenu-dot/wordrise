param(
    [string]$localFile,
    [string]$remoteRelPath
)
$ftpServer = "176.9.111.172"
$ftpUser = "69a7b993de9dc"
$ftpPass = 'd4)BX\Cv2q1y)P#aw!XP<vP^Bv1}uB9\'
$remotePath = "www/69a7b993deaa3.goldxost.ru/wordrise-api/$remoteRelPath"

$uri = "ftp://$ftpServer/$remotePath"
$request = [System.Net.FtpWebRequest]::Create($uri)
$request.Method = [System.Net.WebRequestMethods+Ftp]::UploadFile
$request.Credentials = New-Object System.Net.NetworkCredential($ftpUser, $ftpPass)
$request.UseBinary = $true
$request.KeepAlive = $false

$fileBytes = [System.IO.File]::ReadAllBytes((Resolve-Path $localFile))
$request.ContentLength = $fileBytes.Length

$requestStream = $request.GetRequestStream()
$requestStream.Write($fileBytes, 0, $fileBytes.Length)
$requestStream.Close()

$response = $request.GetResponse()
$response.Close()
Write-Host "Uploaded $localFile to $uri successfully!"
