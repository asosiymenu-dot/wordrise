$ErrorActionPreference = 'Stop'

$projectRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$phpCommand = Get-Command php -ErrorAction SilentlyContinue

if ($phpCommand) {
    $php = $phpCommand.Source
    $phpRoot = Split-Path $php
} else {
    $phpRoot = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages\PHP.PHP.8.4_Microsoft.Winget.Source_8wekyb3d8bbwe'
    $php = Join-Path $phpRoot 'php.exe'
}

if (-not (Test-Path $php)) {
    throw "php.exe not found. Install PHP first."
}

$port = if ($env:PORT) { [int]$env:PORT } else { 8000 }
$hostName = if ($env:HOST) { $env:HOST } else { '0.0.0.0' }
$docRoot = Join-Path $projectRoot 'backend_php'

Write-Host "Starting WordRise PHP API..."
Write-Host "Local URL: http://127.0.0.1:$port/api"
Write-Host "Network URL: http://<your-wifi-ip>:$port/api"

& $php `
    -d "extension_dir=$phpRoot\ext" `
    -d extension=pdo_mysql `
    -d extension=mysqli `
    -S "${hostName}:$port" `
    -t $docRoot
