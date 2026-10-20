param([Parameter(Mandatory)][string]$Root,[ValidateSet('A','B')][string]$Tag)
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'Owner.psm1') -Force -DisableNameChecking
try{
 $context=New-OfflineNativeTestContext $Root
 [IO.File]::WriteAllText((Join-Path $context.Root ('ready-'+$Tag)),(@{mode='OFFLINE_TEST_ONLY';pid=$PID;startUTC=(Get-Process -Id $PID).StartTime.ToUniversalTime().ToString('o')}|ConvertTo-Json -Compress))
 $timer=[Diagnostics.Stopwatch]::StartNew()
 while(!(Test-Path (Join-Path $context.Root 'go'))){if($timer.ElapsedMilliseconds -gt 5000){throw 'OFFLINE_BARRIER_TIMEOUT'};Start-Sleep -Milliseconds 5}
 Test-ApprovalConsumer (Join-Path $Root ($Tag+'.json')) (Join-Path $Root 'anchor.json') (Join-Path $Root 'ledger')|Out-Null
 Write-Output 'OFFLINE_TEST_ONLY_ADMITTED';exit 0
}catch{Write-Output 'OFFLINE_TEST_ONLY_DENIED';exit 23}
