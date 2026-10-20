param([Parameter(Mandatory)][ValidatePattern('^[a-z0-9-]{1,40}$')][string]$Namespace,[Parameter(Mandatory)][ValidatePattern('^[a-z0-9-]{1,40}$')][string]$PreparedNamespace)
. (Join-Path $PSScriptRoot 'wiring.ps1')
. (Join-Path $PSScriptRoot 'fake.ps1')
$root=Join-Path (Get-Location).Path ('docs/evidence/ui-source-diagnostic-runtime-20261019/backend/'+$Namespace)
if(Test-Path $root){throw 'FRESH_TEST_NAMESPACE'};New-Item -ItemType Directory -Path $root|Out-Null
$base=Get-Content ('docs/evidence/ui-source-diagnostic-runtime-20261019/backend/'+$PreparedNamespace+'/plan.json') -Raw|ConvertFrom-Json -AsHashtable -Depth 64
$before=Verify-Dependencies
Save-New (Join-Path $root 'source-pins.json') @(Get-ChildItem $PSScriptRoot -File|Sort-Object Name|ForEach-Object{@{path=$_.FullName;sha256=(Get-FileHash $_.FullName).Hash.ToLowerInvariant()}})
$rows=[Collections.Generic.List[object]]::new();$traces=[Collections.Generic.List[object]]::new()
function Check([bool]$OK,[string]$Case){if(!$OK){throw ('ASSERT_'+$Case)}}
function Scenario([string]$Name,$Options,[string]$Fault,[scriptblock]$Assert){
 $p=$base|ConvertTo-Json -Depth 64|ConvertFrom-Json -AsHashtable -Depth 64;$old=$p.runID;$p.runID=[Guid]::NewGuid().ToString('N');$p.evidenceRoot=Join-Path $root $Name;$p.mode='SYNTHETIC_FAKE_NATIVE_NOT_RUNTIME'
 New-Item -ItemType Directory -Path $p.evidenceRoot|Out-Null
 foreach($r in $p.roles){$n=$r.name;$r.name='wed-source-'+$p.runID+'-offline-'+$r.role;$r.argv=@(foreach($a in $r.argv){if($a -ceq $n){$r.name}elseif($a -ceq ('com.wed-snap.run='+$old)){'com.wed-snap.run='+$p.runID}else{$a}})}
 $fake=New-FakeNative $p $Options;$faultState=@{used=$false}
 $hook={param($name,$op,$diag)
  $target=if($Fault.EndsWith('-start')){'start-app'}else{'create-app'}
  if(!$faultState.used -and $name.StartsWith('diagnostic-') -and $op.operation -ceq $target -and $Fault.StartsWith('cap-')){$faultState.used=$true;return @{diagnostics=@{pad=('x'*17000)}}}
  if(!$faultState.used -and $name.StartsWith('diagnostic-') -and $op.operation -ceq $target -and $Fault.StartsWith('serialize-')){$faultState.used=$true;$deep=@{};$v=$deep;foreach($i in 1..40){$v.next=@{};$v=$v.next};return @{diagnostics=$deep}}
  if(!$faultState.used -and $Fault -ceq 'core-cap-create' -and $name -ceq 'core-app-created-ledger'){$faultState.used=$true;return @{operation=@{pad=('x'*66000)}}}
 }.GetNewClosure()
 $ioState=@{used=$false}
 $io={param($stream,$bytes)
  $ordinal=if($Fault -ceq 'write-start'){6}else{3}
  # First role sequence: images1/collision2/create3/owner4/guard5/start6.
  if(!$ioState.used -and $Fault.StartsWith('write-') -and $stream.Name.Contains('diagnostic-'+$ordinal.ToString('D3')+'.json.')){$ioState.used=$true;$stream.Write($bytes,0,1);throw 'SYNTHETIC_IO_SECRET_NOT_FOR_LOG'}
 }.GetNewClosure()
 $out=Invoke-LoggedAttempt $p $fake.invoke $fake.now {} $hook $io
 & $Assert $out $fake.state $p
 foreach($n in $fake.state.outcomes){Check ($n.result.Status -ceq $n.status -and $n.result.RootExit -eq $n.exit -and $n.result.TerminationRequested -eq $n.forced) 'NATIVE_OBSERVATION_UNCHANGED'}
 foreach($file in Get-ChildItem $p.evidenceRoot -File){$text=[IO.File]::ReadAllText($file.FullName);Check (!$text.Contains('SYNTHETIC_RAW_SECRET') -and !$text.Contains('SYNTHETIC_IO_SECRET')) 'RAW_SECRET_OMITTED';$d=[Text.Json.JsonDocument]::Parse($text);try{$span=$d.RootElement.GetProperty('diagnostics').GetRawText();Check ((Get-Item $file.FullName).Length -le 65536 -and $script:StrictUTF8.GetByteCount($span) -le 16384) 'ACTUAL_PERSISTED_CAP'}finally{$d.Dispose()}}
 Check (@(Get-ChildItem $p.evidenceRoot -Filter '*.stage' -Force).Count -eq 0) 'NO_PARTIAL_STAGES'
 $traces.Add(@{case=$Name;completionPASS=$out.completionPASS;cleanupClosed=$out.cleanupClosed;coreRuntimePASS=$out.core.runtimePASS;evidenceComplete=$out.core.evidenceComplete;loggerFailures=$out.loggerFailures;created=$fake.state.created;removed=$fake.state.removed;calls=@($fake.state.calls|ForEach-Object{@{operation=$_.operation;limit=$_.limit;cap=$_.cap;reference=$(if($_.argv[0] -ceq 'container'){$_.argv[2]}elseif($_.argv[0] -ceq 'rm'){$_.argv[2]}else{$null})}});ledger=$out.core.ledger})
 $rows.Add(@{case=$Name;status='PASS_FAKE_INTEGRATED_NOT_NATIVE'})
}
try{
 Scenario 'all-five-fake' @{} 'none' {param($o,$s,$p) Check ($o.completionPASS -and $o.cleanupClosed -and $s.created.Count -eq 5 -and $s.removed.Count -eq 5) 'ALL_FIVE_SUCCESS'}
 Scenario 'guard-fail-cleanup' @{guardFail=$true} 'none' {param($o,$s,$p) Check (!$o.completionPASS -and $o.cleanupClosed -and $s.created.Count -eq 1 -and $s.removed.Count -eq 1 -and @($s.calls|Where-Object operation -Like 'start-*').Count -eq 0) 'GUARD_FAIL_CLEANUP'}
 foreach($kind in @('foreign','missing')){$opt=@{};$opt[$kind]=$true;Scenario ('owner-'+$kind) $opt 'none' {param($o,$s,$p) Check (!$o.completionPASS -and !$o.cleanupClosed -and $s.created.Count -eq 1 -and $s.removed.Count -eq 0) 'NO_FOREIGN_DELETE'}}
 foreach($fault in @('cap-create','cap-start','serialize-create','serialize-start','write-create','write-start','core-cap-create')){
  Scenario $fault @{} $fault {param($o,$s,$p) Check (!$o.completionPASS -and !$o.core.evidenceComplete -and $o.loggerFailed -and $o.cleanupClosed -and $s.created.Count -eq 1 -and $s.removed.Count -eq 1) 'LOG_FAIL_SAFE_CLEANUP_NO_NEXT_ROLE'}
 }
 Scenario 'force-root-zero' @{forced=$true} 'none' {param($o,$s,$p) Check (!$o.completionPASS -and $o.cleanupClosed -and $s.created.Count -eq 1) 'FORCE_NOT_PASS'}
 Scenario 'created-exit-zero' @{createdZero=$true} 'none' {param($o,$s,$p) Check (!$o.completionPASS -and $o.cleanupClosed -and $s.created.Count -eq 1) 'CREATED_NOT_PASS'}
 Scenario 'work-reserve' @{workExhausted=$true} 'none' {param($o,$s,$p) Check (!$o.completionPASS -and $o.cleanupClosed -and $o.core.elapsedMs -eq 239500 -and @($s.calls|Where-Object operation -Like 'start-*').Count -eq 0) 'ABSOLUTE_WORK_RESERVE'}
 Scenario 'budget-exhausted' @{allExhausted=$true} 'none' {param($o,$s,$p) Check (!$o.completionPASS -and !$o.cleanupClosed -and $s.calls.Count -eq 4 -and $s.removed.Count -eq 0) 'NO_CHILD_AFTER_DEADLINE'}
 Scenario 'absence-not-empty' @{absenceUnknown=$true} 'none' {param($o,$s,$p) Check (!$o.completionPASS -and !$o.cleanupClosed -and $s.created.Count -eq 1) 'ABSENCE_BLOCKS_ADMISSION'}
 $denied=$false;try{& (Join-Path $PSScriptRoot 'run.ps1') -Namespace $PreparedNamespace -PlanSHA ((Get-FileHash ('docs/evidence/ui-source-diagnostic-runtime-20261019/backend/'+$PreparedNamespace+'/plan.json')).Hash.ToLowerInvariant())}catch{$denied=$_.Exception.Message -ceq 'SEPARATE_RUNTIME_TASK_REQUIRED'};Check $denied 'ENTRYPOINT_REJECT_BEFORE_DELEGATE';$rows.Add(@{case='entrypoint-no-task-switch';status='PASS_PURE_GATE'})
 $engine=Load-FinalDiagnostic $base
 Check ($engine.FullName -ceq 'WedJobDiagnostic.Engine' -and $null -ne $engine.GetMethod('Run')) 'CORRECT_DIAGNOSTIC_ENGINE_METADATA';$rows.Add(@{case='final-dll-metadata-only';status='PASS_METADATA_NO_RUN'})
 $after=Verify-Dependencies
 Save-New (Join-Path $root 'transcripts.json') $traces.ToArray()
 Save-New (Join-Path $root 'result.json') @{status='PASS_OFFLINE_WIRING';cases=$rows.ToArray();caseCount=$rows.Count;nativeCalls=0;EngineRunCalls=0;daemonCalls=0;baselinePins=@($after.pins).Count;utc=[DateTimeOffset]::UtcNow.ToString('o')}
 Write-Output ('OFFLINE_WIRING_PASS_'+$rows.Count)
}catch{Save-New (Join-Path $root 'failure.json') @{completed=$rows.Count;code=$(if($_.Exception.Message -match '^ASSERT_[A-Z0-9_-]+$'){$_.Exception.Message}else{'WIRING_TEST_ERROR_NO_MESSAGE'});nativeCalls=0};Save-New (Join-Path $root 'partial-transcripts.json') @{cases=$traces.ToArray()};throw}
