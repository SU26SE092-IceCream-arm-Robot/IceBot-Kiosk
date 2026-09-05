<#
.SYNOPSIS
    Builds the IceBot Customer Kiosk Windows release bundle for production.

.DESCRIPTION
    Runs `flutter build windows --release` with the correct production dart-defines.

    Output executable: build\windows\x64\runner\Release\icebot_kiosk.exe
    The entire Release\ folder must be deployed together - the .exe alone is NOT
    sufficient. See the README for deployment details.

    The built app is linked to a kiosk at runtime through Manager login.

.PARAMETER ApiBaseUrl
    Optional. Production backend origin (no trailing slash, no path).
    Defaults to: https://api.icebot.io.vn

.PARAMETER PaymentMethodCode
    Optional. Payment method code registered in the backend.
    Defaults to: payos

.EXAMPLE
    .\scripts\build-production.ps1

.EXAMPLE
    .\scripts\build-production.ps1 `
        -ApiBaseUrl "https://api.icebot.io.vn"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ApiBaseUrl = "https://api.icebot.io.vn",

    [Parameter(Mandatory = $false)]
    [string]$PaymentMethodCode = "payos"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# --- Validation ---

if ([string]::IsNullOrWhiteSpace($ApiBaseUrl)) {
    Write-Error "ApiBaseUrl cannot be empty."
    exit 1
}

$uri = $null
try {
    $uri = [System.Uri]::new($ApiBaseUrl.Trim())
} catch {
    Write-Error "ApiBaseUrl is not a valid URI: $ApiBaseUrl"
    exit 1
}

if ($uri.Scheme -ne "https") {
    Write-Error "Production ApiBaseUrl must use HTTPS. Got: $($uri.Scheme). Refusing to build."
    exit 1
}

$loopbackHosts = @("localhost", "127.0.0.1", "::1")
if ($uri.Host -in $loopbackHosts -or $uri.Host -like "127.*") {
    Write-Error "Production ApiBaseUrl must not point to a loopback address. Got: $($uri.Host). Refusing to build."
    exit 1
}

if ($uri.AbsolutePath -notin @("", "/") -or $uri.Query -ne "" -or $uri.Fragment -ne "") {
    Write-Error "ApiBaseUrl must be a bare origin (scheme + host [+ port] only). Remove any path, query, or fragment."
    exit 1
}

$normalizedUrl = $ApiBaseUrl.Trim().TrimEnd("/")

# --- Summary ---

Write-Host ""
Write-Host "=== IceBot Kiosk - Production Windows Build ===" -ForegroundColor Cyan
Write-Host "  API Base URL : $normalizedUrl" -ForegroundColor Green
Write-Host "  Kiosk Setup  : Manager login at runtime" -ForegroundColor Green
Write-Host "  Demo Mode    : false" -ForegroundColor Green
Write-Host "  Payment Code : $PaymentMethodCode" -ForegroundColor Green
Write-Host ""

# --- Build ---

$repositoryRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$releaseDir = Join-Path $repositoryRoot "build\windows\x64\runner\Release"

Push-Location $repositoryRoot
try {
    & flutter build windows --release `
        "--dart-define=ICEBOT_API_BASE_URL=$normalizedUrl" `
        "--dart-define=ICEBOT_DEMO_MODE=false" `
        "--dart-define=ICEBOT_TTS_TEST_MODE=false" `
        "--dart-define=ICEBOT_PAYMENT_METHOD_CODE=$PaymentMethodCode"

    if ($LASTEXITCODE -ne 0) {
        Write-Error "flutter build windows failed with exit code $LASTEXITCODE."
        exit $LASTEXITCODE
    }
} finally {
    Pop-Location
}

& (Join-Path $PSScriptRoot "prepare-tts-model.ps1") -OutputDirectory $releaseDir

# --- Report output ---

$executable = Join-Path $releaseDir "icebot_kiosk.exe"
if (-not (Test-Path -LiteralPath $executable -PathType Leaf)) {
    Write-Error "Build succeeded but executable not found at expected path: $executable"
    exit 1
}

Write-Host ""
Write-Host "=== Build complete ===" -ForegroundColor Green
Write-Host ""
Write-Host "Output folder  : $releaseDir" -ForegroundColor Cyan
Write-Host "Executable     : icebot_kiosk.exe" -ForegroundColor Cyan
Write-Host ""
Write-Host "IMPORTANT - Deployment:" -ForegroundColor Yellow
Write-Host "  Deploy the ENTIRE Release\ folder to the kiosk machine." -ForegroundColor Yellow
Write-Host "  Do NOT copy only icebot_kiosk.exe - the app will crash without the" -ForegroundColor Yellow
Write-Host "  DLLs, flutter_assets\, and data\ subdirectory beside it." -ForegroundColor Yellow
Write-Host ""
Write-Host "  To start the kiosk on the target machine:" -ForegroundColor Yellow
Write-Host "    .\icebot_kiosk.exe" -ForegroundColor White
Write-Host ""
Write-Host "  To build an MSI installer from this release output, run:" -ForegroundColor Yellow
Write-Host "    .\installer\build-msi.ps1 -ApiBaseUrl '$normalizedUrl'" -ForegroundColor White
Write-Host ""
