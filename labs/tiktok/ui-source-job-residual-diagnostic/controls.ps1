. (Join-Path $PSScriptRoot 'common.ps1')
$before=Check-Baseline
Save-New (Join-Path $script:EvidenceRoot 'phase-a-once.json') @{maxNativeCalls=3;sourcePins=(Diagnostic-SourcePins);baseline=$before;utc=[DateTimeOffset]::UtcNow.ToString('o')}
$engine=Load-Diagnostic
$node=(Get-Command node -CommandType Application -ErrorAction Stop|Select-Object -First 1).Source
$fixture=(Resolve-Path labs/tiktok/ui-source-owner-native/child.cjs).Path
$pins=@(@{path=$node;sha256=(Get-FileHash $node).Hash.ToLowerInvariant()},@{path=$fixture;sha256=(Get-FileHash $fixture).Hash.ToLowerInvariant()})
Save-New (Join-Path $script:EvidenceRoot 'fixture-pins.json') $pins
$rows=[Collections.Generic.List[object]]::new();$nativeCount=0
function Expect([bool]$Condition,[string]$Case){if(!$Condition){throw ('CONTROL_'+$Case)};$rows.Add(@{case=$Case;status='PASS_CONTROL'})}
function Buffer([uint32]$Assigned,[uint32]$Count,[UInt64[]]$PIDs){
 $b=[byte[]]::new(136);[BitConverter]::GetBytes($Assigned).CopyTo($b,0);[BitConverter]::GetBytes($Count).CopyTo($b,4);for($i=0;$i -lt $PIDs.Count -and $i -lt 16;$i++){[BitConverter]::GetBytes($PIDs[$i]).CopyTo($b,8+8*$i)};return ,$b
}
try{
 foreach($v in @(@{n='FAIL234_NO_BUFFER_READ';ok=$false;e=234;l=136;b=$null},@{n='FAIL5_NO_BUFFER_READ';ok=$false;e=5;l=136;b=$null},@{n='SHORT_HEADER';ok=$true;e=0;l=7;b=(Buffer 0 0 @())},@{n='LENGTH_OVER_CAP';ok=$true;e=0;l=137;b=(Buffer 0 0 @())},@{n='ASSIGNED_OVER_CAP';ok=$true;e=0;l=136;b=(Buffer 17 16 @(1))},@{n='COUNT_OVER_CAP';ok=$true;e=0;l=136;b=(Buffer 17 17 @(1))},@{n='COUNT_MISMATCH';ok=$true;e=0;l=136;b=(Buffer 2 1 @(1))},@{n='SHORT_PID_BYTES';ok=$true;e=0;l=16;b=(Buffer 2 2 @(1,2))},@{n='DUPLICATE_PID';ok=$true;e=0;l=24;b=(Buffer 2 2 @(1,1))},@{n='ZERO_PID';ok=$true;e=0;l=16;b=(Buffer 1 1 @(0))},@{n='PID_UPPER_BITS';ok=$true;e=0;l=16;b=(Buffer 1 1 @(4294967296))})){
  $o=[WedJobDiagnostic.Collector]::Decode($v.ok,$v.e,$v.l,$v.b);Expect (!$o.Complete -and $o.PIDs.Count -eq 0) $v.n
 }
 $o=[WedJobDiagnostic.Collector]::Decode($true,0,8,(Buffer 0 0 @()));Expect ($o.Complete -and $o.PIDs.Count -eq 0) 'EMPTY_BOUNDED_LIST'
 $o=[WedJobDiagnostic.Collector]::Decode($true,0,136,(Buffer 16 16 @(1..16)));Expect ($o.Complete -and $o.PIDs.Count -eq 16) 'MAX16_BOUNDED_LIST'
 Expect ([WedJobDiagnostic.Collector]::IdentityCode(1,1,$true,10,10) -ceq 'OWN_IDENTITY_OBSERVED') 'IDENTITY_VALID_PURE'
 Expect ([WedJobDiagnostic.Collector]::IdentityCode(1,1,$true,11,10) -ceq 'CREATION_CHANGED') 'IDENTITY_REUSE_PURE'
 Expect ([WedJobDiagnostic.Collector]::IdentityCode(1,1,$false,10,$null) -ceq 'NOT_IN_OWN_JOB') 'MEMBERSHIP_DENIED_PURE'
 Expect ([WedJobDiagnostic.Collector]::IdentityCode(0,0,$true,10,$null) -ceq 'PID_MISMATCH') 'MISSING_PID_PURE'
 Expect ([WedJobDiagnostic.Collector]::IdentityCode(1,2,$true,10,$null) -ceq 'PID_MISMATCH') 'PID_CHANGED_PURE'
 foreach($case in @(@{n='root-no-child';arg='pass';fault='None'},@{n='intentional-orphan';arg='orphan';fault='None'},@{n='orphan-collector-error';arg='orphan';fault='DIAG_THROW'})){
  Assert-Pins $pins;$nativeCount++
  $r=$engine::Run($node,[string[]]@('--max-old-space-size=32',$fixture,$case.arg),(Get-Location).Path,15000,65536,$case.fault,$null)
  $receipt=Persist-Operation ('control-'+$nativeCount) $r 'ACTUAL_SYNTHETIC_NATIVE_NOT_DOCKER'
  Expect ($r.CleanupClosed -and $r.TreeClosed -and $r.FinalActive -eq 0 -and $r.LiveHandles -eq 0 -and $r.LiveBuffers -eq 0 -and $r.BackgroundReaders -eq 0 -and $r.PipesEOF -and !$r.Timeout -and !$r.ByteCapExceeded) ($case.n+'_CLOSURE')
  Expect ($r.Diagnostics.SnapshotAttempts -le 3 -and @($r.Diagnostics.Snapshots|Where-Object{$_.Rows.Count -gt 16}).Count -eq 0) ($case.n+'_DIAGNOSTIC_BOUNDS')
  if($case.arg -ceq 'pass'){
   Expect ($r.RootExit -eq 0 -and $r.Status -ceq 'PASS' -and !$r.TerminationRequested) 'NO_CHILD_NATIVE_PASS'
   Expect (@($r.Diagnostics.Snapshots|ForEach-Object Rows|Where-Object{$_.RootNumericMatch -and $_.Identity -eq $true -and $_.Member -eq $true -and $_.Wait -eq 0}).Count -gt 0) 'ROOT_BORROWED_HANDLE_IDENTITY'
  }else{
   Expect ($r.RootExit -eq 0 -and $r.Status -ceq 'FAIL' -and $r.TerminationRequested) ($case.n+'_EXPECTED_NATIVE_FAIL')
   if($case.fault -ceq 'None'){
    $child=ConvertFrom-Json -InputObject $r.RawOut.Trim()
    Expect (@($r.Diagnostics.Snapshots|ForEach-Object Rows|Where-Object{$_.PID -eq $child.childPID -and !$_.RootNumericMatch -and $_.Identity -eq $true -and $_.Member -eq $true -and $_.Wait -eq 258}).Count -gt 0) 'ACTUAL_OWN_CHILD_IDENTITY_RUNNING'
   }else{Expect (!$r.Diagnostics.Complete -and @($r.Diagnostics.Snapshots|Where-Object Code -EQ 'COLLECTOR_ERROR_NO_MESSAGE').Count -gt 0) 'COLLECTOR_ERROR_DID_NOT_BLOCK_STOP'}
  }
 }
 $after=Check-Baseline
 Save-New (Join-Path $script:EvidenceRoot 'phase-a-result.json') @{status='CONTROLS_PASS_EXPECTED_ORPHAN_NATIVE_FAIL';caseCount=$rows.Count;cases=$rows.ToArray();nativeOperations=$nativeCount;daemonCalls=0;sourcePins=(Diagnostic-SourcePins);baseline=$after;scope='THREE_ONE_SHOTS_MAX_ROOT_PLUS_ONE_CHILD_NO_RACE_HUNT';utc=[DateTimeOffset]::UtcNow.ToString('o')}
 Write-Output ('PHASE_A_CONTROLS_PASS_'+$rows.Count+'_NATIVE_'+$nativeCount)
}catch{
 Save-New (Join-Path $script:EvidenceRoot 'phase-a-failure.json') @{code=$(if($_.Exception.Message -match '^CONTROL_[A-Z0-9_-]{1,80}$'){$_.Exception.Message}else{'CONTROL_ERROR_NO_MESSAGE'});completed=$rows.Count;nativeOperations=$nativeCount;phaseBAllowed=$false;utc=[DateTimeOffset]::UtcNow.ToString('o')};throw
}
