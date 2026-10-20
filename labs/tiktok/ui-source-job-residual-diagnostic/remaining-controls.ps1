# Resume only the two still-unexecuted controls. Never rerun root-no-child.
. (Join-Path $PSScriptRoot 'common.ps1')
$first=Get-Content (Join-Path $script:EvidenceRoot 'control-1.json') -Raw|ConvertFrom-Json
$fail=Get-Content (Join-Path $script:EvidenceRoot 'phase-a-failure.json') -Raw|ConvertFrom-Json
$initial=Get-Content (Join-Path $script:EvidenceRoot 'phase-a-once.json') -Raw|ConvertFrom-Json
Assert-Pins $initial.sourcePins
if($fail.code -cne 'CONTROL_ROOT_BORROWED_HANDLE_IDENTITY' -or $fail.nativeOperations -ne 1 -or $fail.completed -ne 21 -or $first.nativeStatus -cne 'PASS' -or !$first.cleanupClosed -or !$first.treeClosed -or $first.jobFinal -ne 0 -or !$first.diagnostics.Complete -or @($first.diagnostics.Snapshots|Where-Object{$_.List.Count -ne 0 -or !$_.List.Complete}).Count){throw 'UNEXPECTED_CONTROL_STATE_STOP'}
Save-New (Join-Path $script:EvidenceRoot 'phase-a-continuation-once.json') @{reason='FIX_OVERSTRICT_TEST_EXPECTATION_EMPTY_LIST_IS_VALID';reuseNativeReceipt='control-1.json';nativeCallsAlready=1;remainingCalls=2;noNativeRootRerun=$true;sourcePins=(Diagnostic-SourcePins);utc=[DateTimeOffset]::UtcNow.ToString('o')}
$engine=Load-Diagnostic
$pins=Get-Content (Join-Path $script:EvidenceRoot 'fixture-pins.json') -Raw|ConvertFrom-Json
Assert-Pins $pins;$node=$pins[0].path;$fixture=$pins[1].path
$rows=[Collections.Generic.List[object]]::new();$nativeCount=1
function Expect([bool]$Condition,[string]$Case){if(!$Condition){throw ('CONTROL_'+$Case)};$rows.Add(@{case=$Case;status='PASS_CONTROL'})}
try{
 Expect ($first.rootInOwnJob -and $first.rootPID -gt 0 -and $first.rootCreation -gt 0 -and $first.rootExit -eq 0 -and !$first.forced -and $first.EOF) 'NO_CHILD_ORIGINAL_RECEIPT_EMPTY_LIST_VALID'
 foreach($case in @(@{n='intentional-orphan';fault='None'},@{n='orphan-collector-error';fault='DIAG_THROW'})){
  Assert-Pins $pins;$nativeCount++
  $r=$engine::Run($node,[string[]]@('--max-old-space-size=32',$fixture,'orphan'),(Get-Location).Path,15000,65536,$case.fault,$null)
  $null=Persist-Operation ('control-'+$nativeCount) $r 'ACTUAL_SYNTHETIC_NATIVE_NOT_DOCKER'
  Expect ($r.CleanupClosed -and $r.TreeClosed -and $r.FinalActive -eq 0 -and $r.LiveHandles -eq 0 -and $r.LiveBuffers -eq 0 -and $r.BackgroundReaders -eq 0 -and $r.PipesEOF -and !$r.Timeout -and !$r.ByteCapExceeded) ($case.n+'_CLOSURE')
  Expect ($r.Diagnostics.SnapshotAttempts -le 3 -and @($r.Diagnostics.Snapshots|Where-Object{$_.Rows.Count -gt 16}).Count -eq 0) ($case.n+'_DIAGNOSTIC_BOUNDS')
  Expect ($r.RootExit -eq 0 -and $r.Status -ceq 'FAIL' -and $r.TerminationRequested) ($case.n+'_EXPECTED_NATIVE_FAIL')
  if($case.fault -ceq 'None'){
   $child=ConvertFrom-Json -InputObject $r.RawOut.Trim()
   Expect (@($r.Diagnostics.Snapshots|ForEach-Object Rows|Where-Object{$_.PID -eq $child.childPID -and !$_.RootNumericMatch -and $_.Identity -eq $true -and $_.Member -eq $true -and $_.Wait -eq 258}).Count -gt 0) 'ACTUAL_OWN_CHILD_IDENTITY_RUNNING'
  }else{Expect (!$r.Diagnostics.Complete -and @($r.Diagnostics.Snapshots|Where-Object Code -EQ 'COLLECTOR_ERROR_NO_MESSAGE').Count -gt 0) 'COLLECTOR_ERROR_DID_NOT_BLOCK_STOP'}
 }
 $after=Check-Baseline
 Save-New (Join-Path $script:EvidenceRoot 'phase-a-result.json') @{status='CONTROLS_PASS_EXPECTED_ORPHAN_NATIVE_FAIL';initialAssertionFailurePreserved=$true;initialCompletedChecks=21;initialPureChecks=18;continuationChecks=$rows.Count;cases=$rows.ToArray();nativeOperations=$nativeCount;nativeRootReruns=0;daemonCalls=0;sourcePins=(Diagnostic-SourcePins);baseline=$after;scope='THREE_ONE_SHOTS_MAX_ROOT_PLUS_ONE_FIXTURE_CHILD_NO_RACE_HUNT';utc=[DateTimeOffset]::UtcNow.ToString('o')}
 Write-Output ('PHASE_A_COMPLETE_NATIVE_'+$nativeCount+'_CONTINUATION_CHECKS_'+$rows.Count)
}catch{
 Save-New (Join-Path $script:EvidenceRoot 'phase-a-continuation-failure.json') @{code=$(if($_.Exception.Message -match '^CONTROL_[A-Z0-9_-]{1,80}$'){$_.Exception.Message}else{'CONTROL_ERROR_NO_MESSAGE'});completed=$rows.Count;nativeOperations=$nativeCount;phaseBAllowed=$false;utc=[DateTimeOffset]::UtcNow.ToString('o')};throw
}
