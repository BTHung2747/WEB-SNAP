param([Parameter(Mandatory)][ValidatePattern('^[a-z0-9-]{1,40}$')][string]$Namespace,[Parameter(Mandatory)][string]$PreparedNamespace)
. (Join-Path $PSScriptRoot 'core.ps1')
. (Join-Path $PSScriptRoot 'native.ps1')
$root=Join-Path (Get-Location).Path ('docs/evidence/ui-source-runtime-probe-fix-20261019/backend/'+$Namespace)
if(Test-Path $root){throw 'FRESH_TEST_NAMESPACE_REQUIRED'};New-Item -ItemType Directory -Path $root|Out-Null
$before=Get-OldBaseline
$base=Get-Content ('docs/evidence/ui-source-runtime-probe-fix-20261019/backend/'+$PreparedNamespace+'/plan.json') -Raw|ConvertFrom-Json -AsHashtable -Depth 64
Save-New (Join-Path $root 'source-pins.json') @(Get-ChildItem $PSScriptRoot -File|Sort-Object Name|ForEach-Object{@{path=$_.FullName;sha256=(Get-FileHash $_.FullName).Hash.ToLowerInvariant()}})
$rows=[Collections.Generic.List[object]]::new();$transcripts=[Collections.Generic.List[object]]::new()
function Expect([bool]$Value,[string]$Code){if(!$Value){throw ('TEST_ASSERT_'+$Code)}}
function Fake-Native([string]$Out){return [pscustomobject]@{Status='PASS';Created=$true;RootInOwnJob=$true;RootExit=0;TerminationRequested=$false;Timeout=$false;ByteCapExceeded=$false;FinalActive=0;AfterRootRelease=0;PipesEOF=$true;CleanupClosed=$true;LiveHandles=0;LiveBuffers=0;BackgroundReaders=0;ElapsedMs=1;RawOut=$Out;RawErr='';StdoutBytes=[Text.Encoding]::UTF8.GetByteCount($Out);StderrBytes=0}}
function Fixture-Plan {
 $p=$base|ConvertTo-Json -Depth 64|ConvertFrom-Json -AsHashtable -Depth 64
 $old=$p.runID;$p.runID=[Guid]::NewGuid().ToString('N');$p.mode='SYNTHETIC_FAKE_EXECUTOR_NOT_RUNTIME'
 foreach($role in $p.roles){$oldname=$role.name;$role.name='wed-source-'+$p.runID+'-offline-'+$role.role;$role.argv=@(foreach($a in $role.argv){if($a -ceq $oldname){$role.name}elseif($a -ceq ('com.wed-snap.run='+$old)){'com.wed-snap.run='+$p.runID}else{$a}})};return $p
}
function Scenario([string]$Name,$Opt,[scriptblock]$Assert){
 $p=Fixture-Plan
 $S=@{time=0;calls=[Collections.Generic.List[object]]::new();writes=[Collections.Generic.List[string]]::new();ownerCount=@{};created=@{};removed=@{};writeFaultUsed=$false}
 $executor={param($op,$argv,$limit,$cap)
  $S.calls.Add(@{operation=$op;argv=$argv;limit=$limit;cap=$cap;at=$S.time})
  if($op -ceq 'images'){return Fake-Native ((@($p.roles.image|Sort-Object -Unique)|ForEach-Object{@{id=$_;volumes=$null}|ConvertTo-Json -Compress}) -join "`n")}
  if($op -ceq 'collision'){return Fake-Native $(if($Opt.collision){'EXISTING_SYNTHETIC_RESOURCE'}else{''})}
  if($op -cin @('final-names','final-labels')){return Fake-Native $(if($Opt.finalNonempty){'f'*64}else{''})}
  $name=($op -split '-')[-1];$role=$p.roles|Where-Object role -CEQ $name;$idx=[array]::IndexOf(@('app','proxy','postgres','redis','gateway'),$name);$cid=(@('a','b','c','d','e')[$idx])*64
  $r=Fake-Native ''
  if($op.StartsWith('create-')){
   Expect (!$S.created.ContainsKey($name)) 'NO_RECREATE';$S.created[$name]=$cid
   if($Opt.createThrows){throw 'SYNTHETIC_EXECUTOR_THROW'}
   $r=Fake-Native $(if($Opt.createOutputMissing){''}elseif($Opt.createOutputCut){$cid.Substring(0,20)}else{$cid})
  }elseif($op.StartsWith('owner-')){
   $S.ownerCount[$name]=1+$S.ownerCount[$name]
   $g=@{id=$cid;name='/'+$role.name;image=$role.image;run=$p.runID;task=$p.task}
   if($Opt.ownerField){if($Opt.ownerMissing){$g.Remove($Opt.ownerField)}else{$g[$Opt.ownerField]=$(if($Opt.ownerValidForeignCID){'f'*64}else{'FOREIGN_SYNTHETIC'})}}
   if($Opt.ownerExtra){$g.extra='SYNTHETIC'}
   $r=Fake-Native ($g|ConvertTo-Json -Compress)
   if($Opt.ownerMalformed){$r.RawOut='NOT_JSON'}
   if($Opt.ownerDuplicate){$r.RawOut=$r.RawOut.Replace('"id":','"id":"'+('f'*64)+'","id":')}
   if($Opt.ownerMulti){$r.RawOut+=' '+$r.RawOut}
   if($Opt.ownerNative){$r.RootExit=1;$r.Status='FAIL'}
   if($Opt.exhaustWork -and $S.ownerCount[$name] -eq 1){$S.time=239500}
   if($Opt.exhaustAll -and $S.ownerCount[$name] -eq 1){$S.time=300001}
  }elseif($op.StartsWith('guard-')){
   $tmp=@{};foreach($v in $role.tmpfs){$x=$v.Split(':',2);$tmp[$x[0]]=$x[1]}
   $g=@{id=$cid;user=$role.user;rootRO=$true;privileged=$false;capAdd=$null;capDrop=@('ALL');security=@('no-new-privileges:true');memory=[long]$role.memoryMiB*1MB;swap=[long]$role.memoryMiB*1MB;pids=[long]$role.pids;nanoCPU=[long]($role.cpu*1e9);ipc='private';cgroupns='private';network='none';portCount=0;networks=@('none');tmpfs=$tmp;mounts=@($role.mounts|ForEach-Object{@{type='bind';target=$_.target;rw=$false}})}
   if($Opt.guardField){if($Opt.guardMissing){$g.Remove($Opt.guardField)}else{$g[$Opt.guardField]=$Opt.guardValue}}
   if($Opt.guardDuplicateMount){$g.mounts+=,$g.mounts[0]}
   $r=Fake-Native ($g|ConvertTo-Json -Depth 64 -Compress)
   if($Opt.guardMalformed){$r.RawOut='SYNTHETIC_INVALID_JSON'}
   if($Opt.nativePatch){foreach($k in $Opt.nativePatch.Keys){$r.$k=$Opt.nativePatch[$k]}}
  }elseif($op.StartsWith('start-')){
   $pack=@(@{role=$name;kind='kernel';ok=$true},@{role=$name;kind='role';ok=$true});if($name -ceq 'app'){$pack+=@{role=$name;kind='media-import';ok=$true}}
   if($Opt.packetFail){$pack[0].ok=$false};if($Opt.packetString){$pack[0].ok='true'}
   $r=Fake-Native (($pack|ForEach-Object{$_|ConvertTo-Json -Compress}) -join "`n")
   if($Opt.attachPatch){foreach($k in $Opt.attachPatch.Keys){$r.$k=$Opt.attachPatch[$k]}}
  }elseif($op.StartsWith('state-')){
   $g=@{id=$cid;running=$false;status='exited';exit=0;oom=$false;errorPresent=$false}
   if($Opt.statePatch){foreach($k in $Opt.statePatch.Keys){$g[$k]=$Opt.statePatch[$k]}}
   $r=Fake-Native ($g|ConvertTo-Json -Compress)
  }elseif($op.StartsWith('mountTypes-')){
   $g=@{id=$cid;types=@('bind')};if($Opt.volume){$g.types=@('volume')};if($Opt.mountTypesNull){$g.types=$null}
   $r=Fake-Native ($g|ConvertTo-Json -Compress)
  }elseif($op.StartsWith('remove-')){
   Expect ($argv.Count -eq 3 -and $argv[0] -ceq 'rm' -and $argv[1] -ceq '--force' -and $argv[2] -ceq $cid -and $S.created[$name] -ceq $cid) 'EXACT_CREATED_FULL_CID_REMOVE'
   $S.removed[$name]=$true;if($Opt.removeFailure){$r.RootExit=1;$r.Status='FAIL'}
  }elseif($op.StartsWith('absence-')){$r=Fake-Native $(if($Opt.absenceNonempty){$cid}else{''})}
  else{throw 'UNEXPECTED_FAKE_OPERATION'}
  if($op.StartsWith('create-') -and $Opt.createPatch){foreach($k in $Opt.createPatch.Keys){$r.$k=$Opt.createPatch[$k]}}
  return $r
 }.GetNewClosure()
 $sink={param($name,$value)
  $S.writes.Add($name)
  if(!$S.writeFaultUsed -and (($Opt.receiptFailure -and $name -ceq 'native-003') -or ($Opt.ledgerFailure -and $name -ceq 'app-created-ledger'))){$S.writeFaultUsed=$true;throw 'SYNTHETIC_WRITE_FAILURE'}
 }.GetNewClosure()
 $now={$S.time}.GetNewClosure();$check={}
 $outcome=Invoke-ProbeAttempt $p $executor $sink $now $check
 & $Assert $outcome $S $p
 foreach($call in $S.calls){Expect ($call.limit -le $(if($call.operation.StartsWith('start-')){20000}else{15000}) -and $call.limit -ge 600 -and $call.cap -eq 65536) 'NATIVE_CAPS'}
 $transcripts.Add(@{case=$Name;runID=$p.runID;sourceGate=$false;mode='SYNTHETIC_FAKE_EXECUTOR';calls=@($S.calls|ForEach-Object{$sha=[Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes(($_.argv|ConvertTo-Json -Compress)));@{operation=$_.operation;argvSHA=[Convert]::ToHexString($sha).ToLowerInvariant();verb=$_.argv[0];reference=$(if($_.argv[0] -ceq 'container'){$_.argv[2]}elseif($_.argv[0] -ceq 'rm'){$_.argv[2]}elseif($_.argv[0] -ceq 'start'){$_.argv[2]}else{$null});limitMs=$_.limit;cap=$_.cap;atMs=$_.at}});outcome=@{runtimePASS=$outcome.runtimePASS;closed=$outcome.closed;evidenceComplete=$outcome.evidenceComplete;results=$outcome.results;ledger=$outcome.ledger;failure=$outcome.failure};writes=$S.writes.ToArray()})
 $rows.Add(@{case=$Name;status='PASS_FAKE_EXECUTOR_NOT_RUNTIME'})
}
try{
 Assert-ProjectionContracts
 $bad=$script:Projection.Clone();$bad.guard=$bad.guard.Replace('NanoCPUs','NanoCpus');$deny=$false;try{Assert-ProjectionContracts $bad}catch{$deny=$true};Expect $deny 'CASING_REGRESSION';$rows.Add(@{case='typed-casing-static-contract';status='PASS_STATIC_NOT_GO_EXECUTION'})
 Scenario 'all-five-success' @{} {param($r,$s,$p) Expect ($r.runtimePASS -and $r.closed -and $r.results.Count -eq 5 -and $s.created.Count -eq 5 -and $s.removed.Count -eq 5) 'ALL_FIVE'}
 $guardStop={param($r,$s,$p) Expect (!$r.runtimePASS -and $r.closed -and $s.created.Count -eq 1 -and $s.removed.Count -eq 1 -and @($s.calls|Where-Object operation -Like 'start-*').Count -eq 0) 'GUARD_FAIL_OWNER_CLEANUP'}
 Scenario 'guard-inspect-native-fail-owner-cleanup' @{nativePatch=@{RootExit=1;Status='FAIL'}} $guardStop
 Scenario 'guard-malformed-owner-cleanup' @{guardMalformed=$true} $guardStop
 foreach($f in @('pids','networks','mounts','tmpfs')){Scenario ('guard-missing-'+$f) @{guardField=$f;guardMissing=$true} $guardStop}
 Scenario 'guard-null-pids' @{guardField='pids';guardValue=$null} $guardStop
 Scenario 'guard-boolean-string' @{guardField='rootRO';guardValue='true'} $guardStop
 Scenario 'guard-null-capdrop' @{guardField='capDrop';guardValue=$null} $guardStop
 Scenario 'guard-duplicate-mount' @{guardDuplicateMount=$true} $guardStop
 $noDelete={param($r,$s,$p) Expect (!$r.runtimePASS -and !$r.closed -and $s.removed.Count -eq 0 -and $s.created.Count -eq 1 -and @($s.calls|Where-Object operation -Like 'start-*').Count -eq 0) 'NO_FOREIGN_DELETE'}
 foreach($f in @('id','name','image','run','task')){Scenario ('owner-foreign-'+$f) @{ownerField=$f} $noDelete;Scenario ('owner-missing-'+$f) @{ownerField=$f;ownerMissing=$true} $noDelete}
 Scenario 'owner-malformed' @{ownerMalformed=$true} $noDelete
 Scenario 'owner-duplicate-identity' @{ownerDuplicate=$true} $noDelete
 Scenario 'owner-multi-object' @{ownerMulti=$true} $noDelete
 Scenario 'owner-native-failure' @{ownerNative=$true} $noDelete
 Scenario 'owner-valid-foreign-full-cid' @{ownerField='id';ownerValidForeignCID=$true} $noDelete
 Scenario 'owner-extra-field-ambiguous-contract' @{ownerExtra=$true} $noDelete
 foreach($flag in @('createOutputMissing','createOutputCut','createThrows','receiptFailure','ledgerFailure')){
  $opt=@{};$opt[$flag]=$true
  Scenario $flag $opt {param($r,$s,$p) Expect (!$r.runtimePASS -and $r.closed -and $s.created.Count -eq 1 -and $s.removed.Count -eq 1 -and $r.ledger[0].recoveryAttempted -and @($s.calls|Where-Object{$_.operation -ceq 'owner-app' -and $_.argv[2] -ceq $p.roles[0].name}).Count -eq 1 -and @($s.calls|Where-Object operation -Like 'start-*').Count -eq 0) 'ONE_NAME_RECOVERY_NO_RECREATE'}
 }
 Scenario 'create-timeout-missing-output-recovery' @{createOutputMissing=$true;createPatch=@{Timeout=$true;Status='FAIL';RootExit=$null}} {param($r,$s,$p) Expect (!$r.runtimePASS -and $r.closed -and $r.ledger[0].recoveryAttempted -and $s.created.Count -eq 1 -and $s.removed.Count -eq 1) 'TIMEOUT_RECOVERY'}
 Scenario 'lost-create-output-foreign-name-recovery-denied' @{createOutputMissing=$true;ownerField='run'} {param($r,$s,$p) Expect (!$r.runtimePASS -and !$r.closed -and $r.ledger[0].recoveryAttempted -and $s.created.Count -eq 1 -and $s.removed.Count -eq 0 -and @($s.calls|Where-Object operation -EQ 'owner-app').Count -eq 1) 'RECOVERY_NO_FOREIGN_ADOPTION'}
 $runtimeFail={param($r,$s,$p) Expect (!$r.runtimePASS -and $r.closed -and $s.created.Count -eq 1 -and $s.removed.Count -eq 1) 'CONTAINER_NOT_CLIENT_SUCCESS'}
 Scenario 'client-zero-container-nonzero' @{statePatch=@{exit=20}} $runtimeFail
 Scenario 'created-exit0-not-success' @{statePatch=@{status='created'}} $runtimeFail
 Scenario 'container-oom' @{statePatch=@{oom=$true}} $runtimeFail
 Scenario 'container-exit-null' @{statePatch=@{exit=$null}} $runtimeFail
 Scenario 'container-wrong-binding' @{statePatch=@{id='f'*64}} $runtimeFail
 Scenario 'packet-fail' @{packetFail=$true} $runtimeFail
 Scenario 'packet-string-true' @{packetString=$true} $runtimeFail
 foreach($patch in @(@{RootExit=20;Status='FAIL'},@{RootExit=0;TerminationRequested=$true},@{RootExit=$null;Timeout=$true},@{PipesEOF=$false},@{CleanupClosed=$false},@{ByteCapExceeded=$true},@{FinalActive=$null})){
  Scenario ('attach-native-reject-'+$rows.Count) @{attachPatch=$patch} $runtimeFail
 }
 Scenario 'cleanup-absence-nonempty-stops-admission' @{absenceNonempty=$true} {param($r,$s,$p) Expect (!$r.runtimePASS -and !$r.closed -and $s.created.Count -eq 1) 'ABSENCE_NOT_NATIVE_ZERO'}
 Scenario 'cleanup-remove-fails-stops-admission' @{removeFailure=$true} {param($r,$s,$p) Expect (!$r.runtimePASS -and !$r.closed -and $s.created.Count -eq 1) 'REMOVE_FAIL'}
 Scenario 'cleanup-volume-unproven' @{volume=$true} {param($r,$s,$p) Expect (!$r.runtimePASS -and !$r.closed -and $s.removed.Count -eq 0) 'NO_VOLUME_DELETE'}
 Scenario 'cleanup-mount-types-null' @{mountTypesNull=$true} {param($r,$s,$p) Expect (!$r.runtimePASS -and !$r.closed -and $s.removed.Count -eq 0) 'NO_UNKNOWN_MOUNT_DELETE'}
 Scenario 'work-exhausted-cleanup-reserve-not-reset' @{exhaustWork=$true} {param($r,$s,$p) Expect (!$r.runtimePASS -and $r.closed -and $r.elapsedMs -eq 239500 -and @($s.calls|Where-Object operation -EQ 'start-app').Count -eq 0) 'RESERVE_ONLY'}
 Scenario 'all-budget-exhausted-no-extra-child' @{exhaustAll=$true} {param($r,$s,$p) Expect (!$r.runtimePASS -and !$r.closed -and $s.removed.Count -eq 0 -and $s.calls.Count -eq 4) 'ABSOLUTE_DEADLINE'}
 Scenario 'preflight-collision-no-adoption' @{collision=$true} {param($r,$s,$p) Expect (!$r.runtimePASS -and $s.created.Count -eq 0 -and $s.removed.Count -eq 0) 'COLLISION'}
 Scenario 'final-absence-native0-nonempty' @{finalNonempty=$true} {param($r,$s,$p) Expect (!$r.runtimePASS -and !$r.closed -and $r.results.Count -eq 5) 'FINAL_ABSENCE'}
 $parseErrors=@();foreach($file in Get-ChildItem $PSScriptRoot -Filter '*.ps1'){$tokens=$null;$e=$null;$null=[Management.Automation.Language.Parser]::ParseFile($file.FullName,[ref]$tokens,[ref]$e);$parseErrors+=@($e)};Expect ($parseErrors.Count -eq 0) 'PS_PARSE';$rows.Add(@{case='successor-ps-parse';status='PASS_PARSE'})
 $after=Get-OldBaseline
 Save-New (Join-Path $root 'result.json') @{status='PASS_OFFLINE_ONLY';cases=$rows.ToArray();caseCount=$rows.Count;daemonCalls=0;resources=0;GoTemplateExecution='NOT_RUN_NO_GO_TOOLCHAIN';baselineSources=$after.oldSources;baselineArtifacts=$after.oldArtifacts;utc=[DateTimeOffset]::UtcNow.ToString('o')}
 Save-New (Join-Path $root 'transcripts.json') $transcripts.ToArray()
 Write-Output ('PASS_OFFLINE_ONLY_'+$rows.Count)
}catch{
 Save-New (Join-Path $root 'failure.json') @{status='OFFLINE_TEST_FAIL';completed=$rows.Count;code=$(if($_.Exception.Message -match '^TEST_ASSERT_[A-Z0-9_]+$'){$_.Exception.Message}else{'TEST_ERROR_NO_MESSAGE'});utc=[DateTimeOffset]::UtcNow.ToString('o')}
 Save-New (Join-Path $root 'partial-transcripts.json') $transcripts.ToArray();throw
}
