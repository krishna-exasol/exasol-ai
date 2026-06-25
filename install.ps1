param(
    [string] $InstallDir = "$HOME\.exasol-ai",
    [string] $NanoImage = "",
    [string] $JsonTablesRef = "",
    [string] $McpServerVersion = "",
    [string] $BaseUrl = "",
    [string] $Ref = "main",
    [switch] $SkipBuildTools
)

$ErrorActionPreference = "Stop"

# Resolve where supporting assets are downloaded from when this script is run
# without a local copy (for example via: irm <url>/install.ps1 | iex).
if (-not $BaseUrl) {
    $BaseUrl = $env:EXASOL_AI_BASE_URL
}
if (-not $BaseUrl) {
    $BaseUrl = "https://raw.githubusercontent.com/krishna-exasol/exasol-ai/$Ref"
}
$script:BaseUrl = $BaseUrl

# ---------------------------------------------------------------------------
# Pretty output helpers
# ---------------------------------------------------------------------------
$script:TotalPhases = 5
$script:Phase = 0

function Write-Banner {
    Write-Host ""
    Write-Host "  ███████╗██╗  ██╗ █████╗ ███████╗ ██████╗ ██╗" -ForegroundColor Cyan
    Write-Host "  ██╔════╝╚██╗██╔╝██╔══██╗██╔════╝██╔═══██╗██║" -ForegroundColor Cyan
    Write-Host "  █████╗   ╚███╔╝ ███████║███████╗██║   ██║██║" -ForegroundColor Cyan
    Write-Host "  ██╔══╝   ██╔██╗ ██╔══██║╚════██║██║   ██║██║" -ForegroundColor Cyan
    Write-Host "  ███████╗██╔╝ ██╗██║  ██║███████║╚██████╔╝███████╗" -ForegroundColor Cyan
    Write-Host "  ╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝ ╚═════╝ ╚══════╝" -ForegroundColor Cyan
    Write-Host "  Exasol AI Installer" -ForegroundColor White
    Write-Host "  Nano  +  JSON Tables  +  MCP Server" -ForegroundColor DarkGray
    Write-Host ""
}

function Write-Phase {
    param([string] $Message)
    $script:Phase++
    Write-Host ""
    Write-Host ("  [{0}/{1}] " -f $script:Phase, $script:TotalPhases) -ForegroundColor Cyan -NoNewline
    Write-Host $Message -ForegroundColor White
}

function Write-Ok {
    param([string] $Message)
    Write-Host "      " -NoNewline
    Write-Host ([char]0x2713) -ForegroundColor Green -NoNewline
    Write-Host " $Message" -ForegroundColor Gray
}

function Write-Info {
    param([string] $Message)
    Write-Host "        $Message" -ForegroundColor DarkGray
}

function Write-Warn {
    param([string] $Message)
    Write-Host "      ! " -ForegroundColor Yellow -NoNewline
    Write-Host $Message -ForegroundColor Yellow
}

function Require-Command {
    param([string] $Name, [string] $Hint)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "$Name is required. $Hint"
    }
}

function Copy-Or-DownloadAsset {
    param(
        [string] $Name,
        [string] $Destination
    )

    # $PSScriptRoot is empty when this script is piped to iex (irm ... | iex).
    # Guard before Join-Path, which throws on an empty -Path.
    if ($PSScriptRoot) {
        $localPath = Join-Path $PSScriptRoot $Name
        if (Test-Path -LiteralPath $localPath) {
            Copy-Item -LiteralPath $localPath -Destination $Destination -Force
            Write-Ok "$Name (local)"
            return
        }
    }

    if (-not $script:BaseUrl) {
        throw "Cannot find local asset $Name and no download base URL is set."
    }
    Invoke-WebRequest -Uri "$script:BaseUrl/$Name" -OutFile $Destination
    Write-Ok $Name
}

# ---------------------------------------------------------------------------
# Install
# ---------------------------------------------------------------------------
Write-Banner

Write-Phase "Checking prerequisites"
Require-Command docker "Install Docker Desktop and start the Docker engine."
Write-Ok "docker found"
docker info *> $null
if ($LASTEXITCODE -ne 0) {
    throw "Docker is installed but the Docker engine is not running. Start Docker Desktop and re-run."
}
Write-Ok "Docker engine is running"

Write-Phase "Downloading stack files"
Write-Info "into $InstallDir"
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $InstallDir "workspace") | Out-Null

$assets = @(
    "compose.yaml",
    "Dockerfile.mcp",
    "Dockerfile.json-tables",
    "mcp-settings.json",
    "manifest.json",
    "uninstall.ps1"
)

foreach ($asset in $assets) {
    Copy-Or-DownloadAsset -Name $asset -Destination (Join-Path $InstallDir $asset)
}

Write-Phase "Configuring"
$manifestPath = Join-Path $InstallDir "manifest.json"
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json

if (-not $NanoImage) {
    $NanoImage = $manifest.nano.image
}
if (-not $JsonTablesRef) {
    $JsonTablesRef = $manifest.jsonTables.ref
}
if (-not $McpServerVersion) {
    $McpServerVersion = $manifest.mcpServer.version
}

$envPath = Join-Path $InstallDir ".env"
@(
    "EXASOL_NANO_IMAGE=$NanoImage",
    "EXASOL_JSON_TABLES_REF=$JsonTablesRef",
    "EXASOL_MCP_SERVER_VERSION=$McpServerVersion",
    "EXASOL_SQL_PORT=$($manifest.ports.sql)",
    "EXASOL_WEB_PORT=$($manifest.ports.web)",
    "EXASOL_MCP_PORT=$($manifest.ports.mcp)"
) | Set-Content -LiteralPath $envPath -Encoding utf8
Write-Ok "Nano image:   $NanoImage"
Write-Ok "JSON Tables:  $JsonTablesRef"
Write-Ok "MCP Server:   $McpServerVersion"
if ($NanoImage -match ":latest$") {
    Write-Warn "Nano image uses 'latest'. For a release, pin a tested tag or sha256 digest."
}
if ($JsonTablesRef -eq "main") {
    Write-Warn "JSON Tables ref is 'main'. For a release, pin a tested tag or commit."
}

Push-Location $InstallDir
try {
    Write-Phase "Building & starting containers"
    Write-Info "First run pulls images and compiles the JSON Tables engine - this can take a few minutes."
    if ($SkipBuildTools) {
        docker compose --env-file .env -f compose.yaml up -d --build nano mcp-server
    } else {
        docker compose --env-file .env -f compose.yaml up -d --build
    }
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to start the Exasol AI stack (docker compose exited $LASTEXITCODE)."
    }
    Write-Ok "containers started"

    Write-Phase "Finalizing"
    $runnerPath = Join-Path $InstallDir "run-json-tables.ps1"
    @'
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]] $JsonTablesArgs
)
$ErrorActionPreference = "Stop"
$installDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Push-Location $installDir
try {
    # json-tables runs as a standing container; exec the CLI into it.
    docker compose --env-file .env -f compose.yaml exec json-tables exasol-json-tables @JsonTablesArgs
} finally {
    Pop-Location
}
'@ | Set-Content -LiteralPath $runnerPath -Encoding utf8
    Write-Ok "created run-json-tables.ps1 helper"
    docker compose --env-file .env -f compose.yaml ps
    Write-Ok "health check complete"
}
finally {
    Pop-Location
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
$sql = "127.0.0.1:$($manifest.ports.sql)"
$web = "https://127.0.0.1:$($manifest.ports.web)"
$mcp = "http://127.0.0.1:$($manifest.ports.mcp)/mcp"

Write-Host ""
Write-Host "  ===================================================" -ForegroundColor Green
Write-Host "   " -NoNewline
Write-Host ([char]0x2713) -ForegroundColor Green -NoNewline
Write-Host " Exasol AI is installed and running" -ForegroundColor White
Write-Host "  ===================================================" -ForegroundColor Green
Write-Host ""
Write-Host "   Install dir " -ForegroundColor DarkGray -NoNewline; Write-Host $InstallDir -ForegroundColor Gray
Write-Host "   SQL         " -ForegroundColor DarkGray -NoNewline; Write-Host $sql -ForegroundColor Gray
Write-Host "   Web UI      " -ForegroundColor DarkGray -NoNewline; Write-Host $web -ForegroundColor Gray
Write-Host "   MCP         " -ForegroundColor DarkGray -NoNewline; Write-Host $mcp -ForegroundColor Gray
Write-Host ""
Write-Host "   Next steps" -ForegroundColor Cyan
Write-Host "     - JSON Tables CLI : " -ForegroundColor DarkGray -NoNewline; Write-Host "$InstallDir\run-json-tables.ps1 --help" -ForegroundColor Gray
Write-Host "     - Connect an MCP client to the MCP URL above" -ForegroundColor DarkGray
Write-Host "     - Uninstall       : " -ForegroundColor DarkGray -NoNewline; Write-Host "$InstallDir\uninstall.ps1" -ForegroundColor Gray
Write-Host ""
