param(
    [string] $InstallDir = "$HOME\.exasol-ai",
    [switch] $RemoveData
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $InstallDir)) {
    Write-Host "Install directory not found: $InstallDir"
    return
}

$composePath = Join-Path $InstallDir "compose.yaml"
$envPath = Join-Path $InstallDir ".env"

if (Test-Path -LiteralPath $composePath) {
    Push-Location $InstallDir
    try {
        if ($RemoveData) {
            docker compose --env-file .env -f compose.yaml down --volumes
        } else {
            docker compose --env-file .env -f compose.yaml down
        }
    }
    finally {
        Pop-Location
    }
}

Remove-Item -LiteralPath $InstallDir -Recurse -Force

if ($RemoveData) {
    Write-Host "Exasol AI MVP removed, including Docker volume data."
} else {
    Write-Host "Exasol AI MVP removed. Docker volume data was preserved."
    Write-Host "Run with -RemoveData to remove persisted Nano data."
}
