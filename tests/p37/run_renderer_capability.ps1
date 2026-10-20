# Compatibility entrypoint. Active lab code lives under labs/tiktok/renderer.
$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot '../../labs/tiktok/renderer/run_renderer_capability.ps1') @args
exit $LASTEXITCODE
