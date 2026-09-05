<#
.SYNOPSIS
    Downloads, verifies, and stages the pinned Vietnamese TTS model.

.DESCRIPTION
    The archive is cached under build\ and never downloaded by the installed
    kiosk. When OutputDirectory is supplied, the verified model is copied into
    <OutputDirectory>\tts so it becomes part of the portable/installer bundle.
#>
[CmdletBinding()]
param(
    [string]$OutputDirectory,
    [string]$CacheDirectory
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repositoryRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$modelName = "vits-piper-vi_VN-vais1000-medium"
$archiveName = "$modelName.tar.bz2"
$modelUrl = "https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/$archiveName"
$expectedSha256 = "FA1367710767D36ED5CF13B4A449E20C35FFD12791C2E47C2E64142BFA55551A"

if ([string]::IsNullOrWhiteSpace($CacheDirectory)) {
    $CacheDirectory = Join-Path $repositoryRoot "build\tts-model-cache"
}

New-Item -ItemType Directory -Path $CacheDirectory -Force | Out-Null
$archivePath = Join-Path $CacheDirectory $archiveName
$extractRoot = Join-Path $CacheDirectory "extracted"
$modelDirectory = Join-Path $extractRoot $modelName

if (-not (Test-Path -LiteralPath $archivePath -PathType Leaf)) {
    Write-Host "Downloading pinned Vietnamese TTS model..." -ForegroundColor Cyan
    Invoke-WebRequest -Uri $modelUrl -OutFile $archivePath
}

$actualSha256 = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToUpperInvariant()
if ($actualSha256 -ne $expectedSha256) {
    throw "TTS model checksum mismatch. Expected $expectedSha256 but received $actualSha256."
}

$requiredModel = Join-Path $modelDirectory "vi_VN-vais1000-medium.onnx"
$requiredTokens = Join-Path $modelDirectory "tokens.txt"
$requiredData = Join-Path $modelDirectory "espeak-ng-data"
if (-not (Test-Path -LiteralPath $requiredModel -PathType Leaf) -or
    -not (Test-Path -LiteralPath $requiredTokens -PathType Leaf) -or
    -not (Test-Path -LiteralPath $requiredData -PathType Container)) {
    New-Item -ItemType Directory -Path $extractRoot -Force | Out-Null
    & tar -xf $archivePath -C $extractRoot
    if ($LASTEXITCODE -ne 0) {
        throw "Could not extract the TTS model archive (exit code $LASTEXITCODE)."
    }
}

if (-not (Test-Path -LiteralPath $requiredModel -PathType Leaf) -or
    -not (Test-Path -LiteralPath $requiredTokens -PathType Leaf) -or
    -not (Test-Path -LiteralPath $requiredData -PathType Container)) {
    throw "The verified TTS archive does not contain the required model files."
}

if (-not [string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $ttsOutput = Join-Path $OutputDirectory "tts"
    $noticesSource = Join-Path $repositoryRoot "THIRD_PARTY_NOTICES.md"
    if (-not (Test-Path -LiteralPath $noticesSource -PathType Leaf)) {
        throw "THIRD_PARTY_NOTICES.md is required for the distributable TTS bundle."
    }
    New-Item -ItemType Directory -Path $ttsOutput -Force | Out-Null
    Copy-Item -LiteralPath $modelDirectory -Destination $ttsOutput -Recurse -Force
    Copy-Item -LiteralPath $noticesSource -Destination $OutputDirectory -Force
    $stagedModelDirectory = Join-Path $ttsOutput $modelName
    Write-Host "TTS model staged: $stagedModelDirectory" -ForegroundColor Green
}
else {
    Write-Host "TTS model ready: $modelDirectory" -ForegroundColor Green
}
