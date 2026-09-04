[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ApiBaseUrl,

    [string]$PaymentMethodCode = "payos",
    [string]$Version = "1.0.0",
    [string]$OutputDirectory,
    [string]$WixPath,
    [switch]$DemoMode,
    [switch]$SkipFlutterBuild
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$installerDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$repositoryRoot = Split-Path -Parent $installerDirectory
$releaseDirectory = Join-Path $repositoryRoot "build\windows\x64\runner\Release"
$wixSource = Join-Path $installerDirectory "IceBotKiosk.wxs"

if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $repositoryRoot "dist\windows"
}

if (-not $DemoMode) {
    if ([string]::IsNullOrWhiteSpace($ApiBaseUrl)) {
        throw "ApiBaseUrl is required unless DemoMode is enabled."
    }
}

if ([string]::IsNullOrWhiteSpace($WixPath)) {
    $wixCommand = Get-Command wix -ErrorAction SilentlyContinue
    if ($null -ne $wixCommand) {
        $WixPath = $wixCommand.Source
    }
    else {
        $WixPath = Join-Path $env:LOCALAPPDATA "IceBot\Tools\wix\wix.exe"
    }
}

if (-not (Test-Path -LiteralPath $WixPath -PathType Leaf)) {
    throw @"
WiX was not found. Install the pinned local tool outside the repository:
dotnet tool install wix --tool-path `"$env:LOCALAPPDATA\IceBot\Tools\wix`" --version 6.0.2
"@
}

if (-not $SkipFlutterBuild) {
    $flutterArguments = @(
        "build",
        "windows",
        "--release",
        "--build-name=$Version",
        "--dart-define=ICEBOT_PAYMENT_METHOD_CODE=$PaymentMethodCode"
    )

    if ($DemoMode) {
        $flutterArguments += "--dart-define=ICEBOT_DEMO_MODE=true"
    }
    else {
        $flutterArguments += "--dart-define=ICEBOT_DEMO_MODE=false"
        $flutterArguments += "--dart-define=ICEBOT_API_BASE_URL=$ApiBaseUrl"
    }

    Push-Location $repositoryRoot
    try {
        & flutter @flutterArguments
        if ($LASTEXITCODE -ne 0) {
            throw "Flutter Windows build failed with exit code $LASTEXITCODE."
        }
    }
    finally {
        Pop-Location
    }
}

$executable = Join-Path $releaseDirectory "icebot_kiosk.exe"
if (-not (Test-Path -LiteralPath $executable -PathType Leaf)) {
    throw "Windows release output was not found at $releaseDirectory."
}

New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$resolvedOutputDirectory = (Resolve-Path -LiteralPath $OutputDirectory).Path
$msiPath = Join-Path $resolvedOutputDirectory "IceBot_Kiosk_$Version.msi"
$intermediateDirectory = Join-Path $resolvedOutputDirectory "wix-intermediate"

& $WixPath build `
    $wixSource `
    -arch x64 `
    -d "AppVersion=$Version" `
    -d "PublishDir=$releaseDirectory" `
    -intermediateFolder $intermediateDirectory `
    -pdbtype none `
    -out $msiPath

if ($LASTEXITCODE -ne 0) {
    throw "WiX MSI build failed with exit code $LASTEXITCODE."
}

if (-not (Test-Path -LiteralPath $msiPath -PathType Leaf)) {
    throw "WiX completed without producing $msiPath."
}

$msi = Get-Item -LiteralPath $msiPath
Write-Host "MSI created: $($msi.FullName)"
Write-Host "MSI size: $($msi.Length) bytes"
