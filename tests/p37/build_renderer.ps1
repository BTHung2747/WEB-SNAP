# Compatibility entrypoint. Active lab code lives under labs/tiktok/renderer.
$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot '../../labs/tiktok/renderer/build_renderer.ps1') @args
exit $LASTEXITCODE
