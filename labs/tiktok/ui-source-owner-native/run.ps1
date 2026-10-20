param([switch]$ExecuteSource,[string]$Approval,[Alias('offline-test-only')][switch]$OfflineTestOnly)
$ErrorActionPreference='Stop'
if($OfflineTestOnly -or !$ExecuteSource -or [string]::IsNullOrWhiteSpace($Approval)){Write-Output 'NEW_SIGNED_HUMAN_SOURCE_APPROVAL_REQUIRED';exit 78}
try{Import-Module (Join-Path $PSScriptRoot 'Owner.psm1') -Force -DisableNameChecking;Invoke-SourceOwner $Approval|ConvertTo-Json -Depth 5;exit 0}catch{Write-Output 'SOURCE_OWNER_REJECTED_OR_FAILED';exit 78}
