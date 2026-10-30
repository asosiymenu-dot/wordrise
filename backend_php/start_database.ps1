$ErrorActionPreference = 'Stop'

$projectRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$mariaRoot = Join-Path $projectRoot 'tools\mariadb-12.3.2-winx64'
$dataDir = Join-Path $projectRoot 'tools\mariadb-data'
$mariadbd = Join-Path $mariaRoot 'bin\mariadbd.exe'
$installDb = Join-Path $mariaRoot 'bin\mariadb-install-db.exe'
$defaultsFile = Join-Path $dataDir 'my.ini'

if (-not (Test-Path $mariadbd)) {
    throw "Portable MariaDB not found at $mariaRoot"
}

if (-not (Test-Path $dataDir)) {
    Write-Host "Initializing MariaDB data directory..."
    & $installDb --datadir=$dataDir --port=3306
}

if (Get-NetTCPConnection -LocalPort 3306 -ErrorAction SilentlyContinue) {
    Write-Host "MariaDB already listens on port 3306."
    exit 0
}

Write-Host "Starting portable MariaDB on 127.0.0.1:3306..."
Start-Process `
    -FilePath $mariadbd `
    -ArgumentList @("--defaults-file=$defaultsFile", "--console") `
    -WorkingDirectory (Join-Path $mariaRoot 'bin') `
    -WindowStyle Hidden

Start-Sleep -Seconds 4
Get-NetTCPConnection -LocalPort 3306 -ErrorAction Stop | Out-Null
Write-Host "MariaDB started."
