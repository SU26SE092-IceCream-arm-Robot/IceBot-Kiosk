<#
.SYNOPSIS
    Smoke-tests the IceBot Customer Kiosk against the production backend.

.DESCRIPTION
    Runs the Kiosk in Flutter debug-device mode pointing at the production backend.
    Use this to verify a production Kiosk ID before cutting a release build.

    A real Kiosk ID must be obtained from the IceBot Admin Web production environment.
    The kiosk identity is selected at runtime after a Manager signs in.

.PARAMETER ApiBaseUrl
    Optional. Production backend origin (no trailing slash, no path).
    Defaults to: https://api.icebot.io.vn

.PARAMETER PaymentMethodCode
    Optional. Payment method code registered in the backend.
    Defaults to: payos

.EXAMPLE
    .\scripts\run-production.ps1

.EXAMPLE
    .\scripts\run-production.ps1 `
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
    Write-Error "Production ApiBaseUrl must use HTTPS. Got: $($uri.Scheme). Refusing to continue."
    exit 1
}

$loopbackHosts = @("localhost", "127.0.0.1", "::1")
if ($uri.Host -in $loopbackHosts -or $uri.Host -like "127.*") {
    Write-Error "Production ApiBaseUrl must not point to a loopback address. Got: $($uri.Host). Refusing to continue."
    exit 1
}

if ($uri.AbsolutePath -notin @("", "/") -or $uri.Query -ne "" -or $uri.Fragment -ne "") {
    Write-Error "ApiBaseUrl must be a bare origin (scheme + host [+ port] only). Remove any path, query, or fragment."
    exit 1
}

$normalizedUrl = $ApiBaseUrl.Trim().TrimEnd("/")

# --- Summary ---

Write-Host ""
Write-Host "=== IceBot Kiosk — Production Smoke Test ===" -ForegroundColor Cyan
Write-Host "  API Base URL : $normalizedUrl" -ForegroundColor Green
Write-Host "  Kiosk Setup  : Manager login at runtime" -ForegroundColor Green
Write-Host "  Demo Mode    : false" -ForegroundColor Green
Write-Host "  Payment Code : $PaymentMethodCode" -ForegroundColor Green
Write-Host ""
Write-Host "Starting flutter run (debug device, Windows). Press Ctrl+C or 'q' in the Flutter console to stop." -ForegroundColor Yellow
Write-Host ""

# --- Run ---

$repositoryRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Push-Location $repositoryRoot
try {
    & flutter run -d windows `
        "--dart-define=ICEBOT_API_BASE_URL=$normalizedUrl" `
        "--dart-define=ICEBOT_DEMO_MODE=false" `
        "--dart-define=ICEBOT_PAYMENT_METHOD_CODE=$PaymentMethodCode"

    if ($LASTEXITCODE -ne 0) {
        Write-Error "flutter run exited with code $LASTEXITCODE."
        exit $LASTEXITCODE
    }
} finally {
    Pop-Location
}
