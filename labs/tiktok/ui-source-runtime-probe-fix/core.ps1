$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'projections.ps1')
function Save-New([string]$Path,$Value){
 $f=[IO.FileStream]::new($Path,[IO.FileMode]::CreateNew)
 try{$b=[Text.Encoding]::UTF8.GetBytes(($Value|ConvertTo-Json -Depth 64));$f.Write($b,0,$b.Length);$f.Flush($true)}finally{$f.Dispose()}
}
function Native-Accepted($R){
 $R.Status -ceq 'PASS' -and $R.Created -eq $true -and $R.RootInOwnJob -eq $true -and $null -ne $R.RootExit -and $R.RootExit -eq 0 -and !$R.TerminationRequested -and !$R.Timeout -and !$R.ByteCapExceeded -and $null -ne $R.FinalActive -and $R.FinalActive -eq 0 -and $R.PipesEOF -eq $true -and $R.CleanupClosed -eq $true
}
function Check-JSONKeys($Element){
 if($Element.ValueKind -eq [Text.Json.JsonValueKind]::Object){
  $keys=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
  foreach($prop in $Element.EnumerateObject()){if(!$keys.Add($prop.Name)){throw 'AMBIGUOUS_JSON'};Check-JSONKeys $prop.Value}
 }elseif($Element.ValueKind -eq [Text.Json.JsonValueKind]::Array){foreach($v in $Element.EnumerateArray()){Check-JSONKeys $v}}
}
function Read-JSON([string]$Text){
 try{$doc=[Text.Json.JsonDocument]::Parse($Text);try{Check-JSONKeys $doc.RootElement}finally{$doc.Dispose()};$g=ConvertFrom-Json -InputObject $Text -AsHashtable -Depth 64 -ErrorAction Stop;if($g -isnot [Collections.IDictionary]){throw 'OBJECT_REQUIRED'};return $g}catch{throw 'PROJECTION_JSON_INVALID'}
}
function Keys-Exact($G,[string[]]$Keys){
 if($G -isnot [Collections.IDictionary] -or $G.Count -ne $Keys.Count){throw 'PROJECTION_SHAPE'}
 foreach($key in $Keys){if(!$G.Contains($key)){throw 'PROJECTION_SHAPE'}}
}
function Is-Integer($V){$V -is [long] -or $V -is [int]}
function Assert-Identity($Plan,$Role,$G,[string]$CID=''){
 Keys-Exact $G @('id','name','image','run','task')
 foreach($k in @('id','name','image','run','task')){if($G[$k] -isnot [string]){throw 'OWNERSHIP_UNPROVEN'}}
 if($G.id -cnotmatch '^[a-f0-9]{64}$' -or ($CID -and $G.id -cne $CID) -or $G.name -cne ('/'+$Role.name) -or $G.image -cne $Role.image -or $G.run -cne $Plan.runID -or $G.task -cne $Plan.task){throw 'OWNERSHIP_UNPROVEN'}
}
function Assert-State($G,[string]$CID){
 Keys-Exact $G @('id','running','status','exit','oom','errorPresent')
 if($G.id -cne $CID -or $G.running -isnot [bool] -or $G.oom -isnot [bool] -or $G.errorPresent -isnot [bool] -or !(Is-Integer $G.exit) -or $G.status -isnot [string]){throw 'STATE_SHAPE'}
 if($G.running -or $G.status -cne 'exited' -or $G.exit -ne 0 -or $G.oom -or $G.errorPresent){throw 'CONTAINER_STATE_FAIL'}
}
function Assert-Guard($Role,$G,[string]$CID){
 Keys-Exact $G @('id','user','rootRO','privileged','capAdd','capDrop','security','memory','swap','pids','nanoCPU','ipc','cgroupns','network','portCount','networks','tmpfs','mounts')
 if($G.id -cne $CID){throw 'GUARD_BINDING'}
 foreach($k in @('rootRO','privileged')){if($G[$k] -isnot [bool]){throw 'GUARD_SHAPE'}}
 foreach($k in @('memory','swap','pids','nanoCPU','portCount')){if(!(Is-Integer $G[$k])){throw 'GUARD_SHAPE'}}
 foreach($k in @('user','ipc','cgroupns','network')){if($G[$k] -isnot [string]){throw 'GUARD_SHAPE'}}
 foreach($k in @('capDrop','security','networks','mounts')){if($null -eq $G[$k] -or $G[$k] -isnot [array]){throw 'GUARD_SHAPE'}}
 if($null -ne $G.capAdd -and $G.capAdd -isnot [array]){throw 'GUARD_SHAPE'}
 foreach($k in @('capAdd','capDrop','security','networks')){foreach($v in $G[$k]){if($v -isnot [string]){throw 'GUARD_SHAPE'}}}
 if($G.user -cne $Role.user -or !$G.rootRO -or $G.privileged -or ($null -ne $G.capAdd -and $G.capAdd.Count -gt 0) -or $G.capDrop -cnotcontains 'ALL' -or $G.security -cnotcontains 'no-new-privileges:true' -or $G.memory -ne $Role.memoryMiB*1MB -or $G.swap -ne $G.memory -or $G.pids -ne $Role.pids -or $G.nanoCPU -ne [long]($Role.cpu*1e9) -or $G.ipc -cne 'private' -or $G.cgroupns -cne 'private' -or $G.network -cne 'none' -or $G.portCount -ne 0 -or $G.networks.Count -ne 1 -or $G.networks[0] -cne 'none'){throw 'GUARD_MISMATCH'}
 if($G.tmpfs -isnot [Collections.IDictionary] -or $G.tmpfs.Count -ne @($Role.tmpfs).Count){throw 'TMPFS_MISMATCH'}
 foreach($t in $Role.tmpfs){$a=$t.Split(':',2);if(!$G.tmpfs.Contains($a[0]) -or $G.tmpfs[$a[0]] -cne $a[1]){throw 'TMPFS_MISMATCH'}}
 $targets=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
 foreach($m in $G.mounts){Keys-Exact $m @('type','target','rw');if($m.type -isnot [string] -or $m.target -isnot [string] -or $m.rw -isnot [bool] -or !$targets.Add($m.target)){throw 'MOUNT_SHAPE'};if($m.type -cne 'bind' -or $m.rw -or $m.target -cnotin @($Role.mounts.target)){throw 'MOUNT_GUARD'}}
 if($targets.Count -ne @($Role.mounts).Count){throw 'MOUNT_GUARD'}
}
function Assert-Packets([string]$Text,[string]$Role){
 $packets=@();foreach($line in ($Text -split '\r?\n'|Where-Object{$_})){if($line.Length -gt 32768){throw 'PACKET_CAP'};$g=Read-JSON $line;if($g.role -cne $Role -or $g.kind -cnotin @('kernel','role','media-import','failure') -or $g.ok -isnot [bool] -or !$g.ok){throw 'PACKET_FAIL'};$packets+=,$g}
 $expected=@('kernel','role');if($Role -ceq 'app'){$expected+='media-import'}
 if($packets.Count -ne $expected.Count){throw 'PACKET_FAIL'};foreach($k in $expected){if(@($packets|Where-Object kind -CEQ $k).Count -ne 1){throw 'PACKET_FAIL'}};return ,$packets
}
function Safe-Code($Err){
 $safe=@('PROJECTION_JSON_INVALID','PROJECTION_SHAPE','OWNERSHIP_UNPROVEN','STATE_SHAPE','CONTAINER_STATE_FAIL','GUARD_BINDING','GUARD_SHAPE','GUARD_MISMATCH','TMPFS_MISMATCH','MOUNT_SHAPE','MOUNT_GUARD','PACKET_CAP','PACKET_FAIL','NATIVE_FAIL','BUDGET_EXHAUSTED','EVIDENCE_WRITE_FAILED','CREATE_RESULT_UNKNOWN','IMAGE_VOLUMES_FAIL','COLLISION_OR_UNKNOWN','ADMISSION_STOP','UNEXPECTED_VOLUME','ABSENCE_UNKNOWN','RECOVERY_ALREADY_USED','PIN_DRIFT')
 if($Err.Exception.Message -cin $safe){return $Err.Exception.Message};return 'INTEGRATION_ERROR_NO_MESSAGE'
}
function Write-Probe($C,[string]$Name,$Value){
 try{& $C.sink $Name $Value}catch{$C.evidenceComplete=$false;$C.writeFailures.Add($Name);return $false};return $true
}
function Call-Probe($C,[string]$Op,[string[]]$Argv,[bool]$Cleanup=$false,[bool]$Attach=$false){
 $deadline=if($Cleanup){300000}else{240000};$left=$deadline-([long](& $C.now)-$C.start)
 $limit=[int][Math]::Min($(if($Attach){20000}else{15000}),$left);if($limit -lt 600){throw 'BUDGET_EXHAUSTED'}
 $r=& $C.executor $Op $Argv $limit 65536
 $receipt=@{operation=$Op;argv=$Argv;limitMs=$limit;cap=65536;cleanup=$Cleanup;actualExit=$r.RootExit;nativeStatus=$r.Status;accepted=(Native-Accepted $r);forced=$r.TerminationRequested;timeout=$r.Timeout;capExceeded=$r.ByteCapExceeded;EOF=$r.PipesEOF;jobFinal=$r.FinalActive;jobAfterRoot=$r.AfterRootRelease;cleanupClosed=$r.CleanupClosed;liveHandles=$r.LiveHandles;liveBuffers=$r.LiveBuffers;readers=$r.BackgroundReaders;elapsedMs=$r.ElapsedMs;stdoutBytes=$r.StdoutBytes;stderrBytes=$r.StderrBytes;stderrCode=$(if($r.StderrBytes){'STDERR_PRESENT_NO_MESSAGE'}else{$null});utc=[DateTimeOffset]::UtcNow.ToString('o')}
 $C.calls.Add($receipt);$written=Write-Probe $C ('native-'+$C.calls.Count.ToString('D3')) $receipt
 return @{raw=$r;ok=(Native-Accepted $r);written=$written}
}
function Require-Call($R){if(!$R.ok){throw 'NATIVE_FAIL'};if(!$R.written){throw 'EVIDENCE_WRITE_FAILED'}}
function Inspect-Probe($C,$Role,[string]$Ref,[string]$Kind,[bool]$Cleanup=$false){
 $r=Call-Probe $C ($Kind+'-'+$Role.role) @('container','inspect',$Ref,'--format',$script:Projection[$Kind]) $Cleanup
 # Cleanup can still close the resource if evidence sink fails; completion FAIL.
 if(!$r.ok){throw 'NATIVE_FAIL'};if(!$Cleanup -and !$r.written){throw 'EVIDENCE_WRITE_FAILED'}
 $g=Read-JSON $r.raw.RawOut
 if($Kind -ceq 'owner'){Assert-Identity $C.plan $Role $g $(if($Ref -cmatch '^[a-f0-9]{64}$'){$Ref}else{''})}
 $null=Write-Probe $C ($Role.role+'-'+$Kind+'-'+$C.calls.Count) $g
 return $g
}
function Close-ProbeRole($C,$Role,$Record){
 try{
  if(!$Record.createIssued){$Record.closed=$true;return}
  if(!$Record.cid -or $Record.needsRecovery){
   if($Record.recoveryAttempted){throw 'RECOVERY_ALREADY_USED'};$Record.recoveryAttempted=$true
   if(!$Record.preflightClear){throw 'OWNERSHIP_UNPROVEN'}
   $owner=Inspect-Probe $C $Role $Role.name owner $true
   if($Record.candidateCID -and $owner.id -cne $Record.candidateCID){throw 'OWNERSHIP_UNPROVEN'}
   $Record.cid=$owner.id;$Record.needsRecovery=$false
  }else{$owner=Inspect-Probe $C $Role $Record.cid owner $true}
  Assert-Identity $C.plan $Role $owner $Record.cid;$Record.ownerVerified=$true
  # Volume safety is separate from identity and unrelated to runtime guard fields.
  $m=Inspect-Probe $C $Role $Record.cid mountTypes $true;Keys-Exact $m @('id','types')
  if($m.id -cne $Record.cid -or $null -eq $m.types -or $m.types -isnot [array]){throw 'PROJECTION_SHAPE'}
  foreach($t in $m.types){if($t -isnot [string] -or $t -cnotin @('bind','tmpfs')){throw 'UNEXPECTED_VOLUME'}}
  $r=Call-Probe $C ('remove-'+$Role.role) @('rm','--force',$Record.cid) $true;if(!$r.ok){throw 'NATIVE_FAIL'}
  $r=Call-Probe $C ('absence-'+$Role.role) @('ps','--all','--no-trunc','--filter',('id='+$Record.cid),'--format',$script:Projection.list) $true
  if(!$r.ok -or ![string]::IsNullOrWhiteSpace($r.raw.RawOut)){throw 'ABSENCE_UNKNOWN'}
  $Record.closed=$true
 }catch{$Record.cleanupCause=Safe-Code $_}
 $null=Write-Probe $C ($Role.role+'-cleanup') $Record
}
function Invoke-ProbeAttempt($Plan,[scriptblock]$Executor,[scriptblock]$Sink,[scriptblock]$Now,[scriptblock]$CheckPins){
 Assert-ProjectionContracts
 if($Plan.sourceGate -ne $false -or $Plan.workSeconds -ne 240 -or $Plan.cleanupReserveSeconds -ne 60 -or $Plan.runID -cnotmatch '^[a-f0-9]{32}$' -or $Plan.task -cne 'runtime-probe-fix-20261019' -or @($Plan.roles).Count -ne 5 -or @($Plan.roles.role|Sort-Object -Unique).Count -ne 5){throw 'PLAN_SCOPE'}
 foreach($role in $Plan.roles){if($role.name -cne ('wed-source-'+$Plan.runID+'-offline-'+$role.role) -or $role.image -cnotmatch '^sha256:[a-f0-9]{64}$'){throw 'PLAN_SCOPE'}}
 $C=@{plan=$Plan;executor=$Executor;sink=$Sink;now=$Now;start=[long](& $Now);evidenceComplete=$true;writeFailures=[Collections.Generic.List[string]]::new();calls=[Collections.Generic.List[object]]::new();ledger=[Collections.Generic.List[object]]::new();results=[Collections.Generic.List[object]]::new()}
 $failure=$null;$finalAbsent=$false
 try{
  if(!(Write-Probe $C 'attempt-once' @{runID=$Plan.runID;sourceGate=$false;mode='OFFLINE_ONLY_NOT_AUTHORITY'})){throw 'EVIDENCE_WRITE_FAILED'}
  & $CheckPins
  $ids=@($Plan.roles.image|Sort-Object -Unique)
  $r=Call-Probe $C 'images' (@('image','inspect')+$ids+@('--format',$script:Projection.image));Require-Call $r
  $seen=@{};foreach($line in ($r.raw.RawOut -split '\r?\n'|Where-Object{$_})){$m=Read-JSON $line;Keys-Exact $m @('id','volumes');if($m.id -cnotin $ids -or $seen.ContainsKey($m.id)){throw 'IMAGE_VOLUMES_FAIL'};$seen[$m.id]=$true;if($null -ne $m.volumes -and $m.volumes -isnot [Collections.IDictionary]){throw 'IMAGE_VOLUMES_FAIL'};foreach($path in $m.volumes.Keys){foreach($role in $Plan.roles|Where-Object image -CEQ $m.id){if($path -cnotin @($role.tmpfs|ForEach-Object{($_ -split ':',2)[0]})){throw 'IMAGE_VOLUMES_FAIL'}}}}
  if($seen.Count -ne $ids.Count){throw 'IMAGE_VOLUMES_FAIL'}
  $r=Call-Probe $C 'collision' @('ps','--all','--no-trunc','--filter',('name=^/wed-source-'+$Plan.runID+'-offline-'),'--format',$script:Projection.list);Require-Call $r
  if(![string]::IsNullOrWhiteSpace($r.raw.RawOut)){throw 'COLLISION_OR_UNKNOWN'}
  foreach($role in $Plan.roles){
   if(([long](& $Now)-$C.start) -gt 210000 -or @($C.ledger|Where-Object{!$_.closed}).Count){throw 'ADMISSION_STOP'}
   & $CheckPins
   $rec=@{role=$role.role;name=$role.name;image=$role.image;cid=$null;candidateCID=$null;createIssued=$false;preflightClear=$true;recoveryAttempted=$false;needsRecovery=$false;ownerVerified=$false;closed=$false;cleanupCause=$null};$C.ledger.Add($rec)
   $pass=$false;$cause=$null;$state=$null;$attach=$null
   try{
    if(!(Write-Probe $C ($role.role+'-intent') @{name=$role.name;image=$role.image;runID=$Plan.runID;task=$Plan.task;argv=$role.argv})){throw 'EVIDENCE_WRITE_FAILED'}
    $rec.createIssued=$true
    $r=Call-Probe $C ('create-'+$role.role) $role.argv
    if($r.raw.RawOut.Trim() -cmatch '^[a-f0-9]{64}$'){$rec.cid=$r.raw.RawOut.Trim();$rec.candidateCID=$rec.cid}
    if(!$r.written){$rec.needsRecovery=$true;throw 'EVIDENCE_WRITE_FAILED'}
    if(!(Write-Probe $C ($role.role+'-created-ledger') $rec)){$rec.needsRecovery=$true;throw 'EVIDENCE_WRITE_FAILED'}
    Require-Call $r;if(!$rec.cid){throw 'CREATE_RESULT_UNKNOWN'}
    $null=Inspect-Probe $C $role $rec.cid owner
    $guard=Inspect-Probe $C $role $rec.cid guard;Assert-Guard $role $guard $rec.cid
    $attach=Call-Probe $C ('start-'+$role.role) @('start','--attach',$rec.cid) $false $true
    $state=Inspect-Probe $C $role $rec.cid state;Assert-State $state $rec.cid
    $guard=Inspect-Probe $C $role $rec.cid guard;Assert-Guard $role $guard $rec.cid
    Require-Call $attach;$packets=Assert-Packets $attach.raw.RawOut $role.role
    if(!(Write-Probe $C ($role.role+'-packets') $packets)){throw 'EVIDENCE_WRITE_FAILED'};$pass=$true
   }catch{$cause=Safe-Code $_}finally{Close-ProbeRole $C $role $rec}
   $row=@{role=$role.role;runtimePASS=$pass;cause=$cause;closed=$rec.closed;cleanupCause=$rec.cleanupCause;containerExit=$(if($null -ne $state){$state.exit}else{$null});attachExit=$(if($null -ne $attach){$attach.raw.RootExit}else{$null});attachAccepted=$(if($null -ne $attach){$attach.ok}else{$false})};$C.results.Add($row);$null=Write-Probe $C ($role.role+'-result') $row
   if(!$pass -or !$rec.closed -or !$C.evidenceComplete){throw 'ADMISSION_STOP'}
  }
 }catch{$failure=Safe-Code $_}finally{
  # At most the same absolute 300s, never reset after a failure.
  try{
   $n=Call-Probe $C 'final-names' @('ps','--all','--no-trunc','--filter',('name=^/wed-source-'+$Plan.runID+'-offline-'),'--format',$script:Projection.list) $true
   $l=Call-Probe $C 'final-labels' @('ps','--all','--no-trunc','--filter',('label=com.wed-snap.run='+$Plan.runID),'--filter',('label=com.wed-snap.task='+$Plan.task),'--format',$script:Projection.list) $true
   $finalAbsent=$n.ok -and $l.ok -and [string]::IsNullOrWhiteSpace($n.raw.RawOut+$l.raw.RawOut)
  }catch{$finalAbsent=$false}
 }
 $closed=$finalAbsent -and @($C.ledger|Where-Object{!$_.closed}).Count -eq 0
 $summary=@{mode=$Plan.mode;runID=$Plan.runID;sourceGate=$false;failure=$failure;runtimePASS=($C.results.Count -eq 5 -and @($C.results|Where-Object{!$_.runtimePASS}).Count -eq 0 -and $closed -and $C.evidenceComplete);closed=$closed;evidenceComplete=$C.evidenceComplete;writeFailures=$C.writeFailures.ToArray();results=$C.results.ToArray();ledger=$C.ledger.ToArray();calls=$C.calls.ToArray();elapsedMs=([long](& $Now)-$C.start);finalAbsent=$finalAbsent}
 if(!(Write-Probe $C 'summary' $summary)){$summary.runtimePASS=$false;$summary.evidenceComplete=$false};return $summary
}
