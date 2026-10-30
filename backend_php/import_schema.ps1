param(
    [string]$User = 'root',
    [string]$Password = '',
    [string]$MySqlPath = ''
)

$ErrorActionPreference = 'Stop'

$schema = Resolve-Path (Join-Path $PSScriptRoot 'database\schema.sql')
$schemaForMysql = $schema.Path.Replace('\', '/')

function Find-MySql {
    param([string]$ExplicitPath)

    if ($ExplicitPath -and (Test-Path $ExplicitPath)) {
        return (Resolve-Path $ExplicitPath).Path
    }

    $command = Get-Command mysql -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    $candidates = @(
        (Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..')) 'tools\mariadb-12.3.2-winx64\bin\mysql.exe'),
        'C:\xampp\mysql\bin\mysql.exe',
        'C:\Program Files\MariaDB 12.3\bin\mysql.exe',
        'C:\Program Files\MariaDB 12.2\bin\mysql.exe',
        'C:\Program Files\MariaDB 11.8\bin\mysql.exe',
        'C:\Program Files\MySQL\MySQL Server 8.4\bin\mysql.exe',
        'C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe'
    )

    foreach ($candidate in $candidates) {
        if (Test-Path $candidate) {
            return $candidate
        }
    }

    throw "mysql.exe not found. Install/start MySQL or pass -MySqlPath `"C:\path\to\mysql.exe`"."
}

$mysql = Find-MySql -ExplicitPath $MySqlPath

Write-Host "Using mysql: $mysql"
Write-Host "Importing schema: $schemaForMysql"
if ($Password) {
    & $mysql -u $User "--password=$Password" -e "source $schemaForMysql"
} else {
    & $mysql -u $User "--password=" -e "source $schemaForMysql"
}


Write-Host "Schema import finished."
