param([switch]$Describe,[switch]$ExecuteSource)
$ErrorActionPreference='Stop'
if($ExecuteSource -or !$Describe){Write-Output 'PRELAUNCH_SOURCE_HOLD';exit 78}
. (Join-Path $PSScriptRoot 'wiring.ps1')
Get-PrelaunchPlan|ConvertTo-Json -Depth 14
exit 0
