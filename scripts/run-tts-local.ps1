<#
.SYNOPSIS
    Starts the local Windows TTS diagnostics without Manager setup or backend.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repositoryRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$prepareScript = Join-Path $PSScriptRoot "prepare-tts-model.ps1"
$modelDirectory = Join-Path $repositoryRoot "build\tts-model-cache\extracted\vits-piper-vi_VN-vais1000-medium"

& $prepareScript

Push-Location $repositoryRoot
try {
    & flutter run -d windows `
        "--dart-define=ICEBOT_TTS_TEST_MODE=true" `
        "--dart-define=ICEBOT_DEMO_MODE=false" `
        "--dart-define=ICEBOT_TTS_MODEL_DIR=$modelDirectory"

    if ($LASTEXITCODE -ne 0) {
        throw "Local TTS diagnostics exited with code $LASTEXITCODE."
    }
}
finally {
    Pop-Location
}
