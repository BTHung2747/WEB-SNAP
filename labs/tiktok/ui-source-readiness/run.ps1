param([switch]$Describe,[switch]$ExecuteSource)
$ErrorActionPreference='Stop'
# Even supplied authority cannot activate this preparation-only entry point.
if ($ExecuteSource -or !$Describe) {
    Write-Output 'SOURCE_DISABLED_READINESS_ONLY'
    exit 78
}
. (Join-Path $PSScriptRoot 'plan.ps1')
$plan=Get-SourceReadinessPlan
Assert-SourceReadinessPlan $plan
$plan | ConvertTo-Json -Depth 8
exit 0
