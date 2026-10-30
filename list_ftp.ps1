$ftpServer = "176.9.111.172"
$ftpUser = "69a7b993de9dc"
$ftpPass = 'd4)BX\Cv2q1y)P#aw!XP<vP^Bv1}uB9\'

$req = [System.Net.FtpWebRequest]::Create("ftp://$ftpServer/www/69a7b993deaa3.goldxost.ru/")
$req.Method = [System.Net.WebRequestMethods+Ftp]::ListDirectoryDetails
$req.Credentials = New-Object System.Net.NetworkCredential($ftpUser, $ftpPass)
$res = $req.GetResponse()
$reader = New-Object System.IO.StreamReader($res.GetResponseStream())
$output = $reader.ReadToEnd()
$res.Close()

Write-Host "Domain root contents:"
Write-Host $output
