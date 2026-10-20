. (Join-Path $PSScriptRoot 'common.ps1')
$script:MountProjection='{"id":{{json .ID}},"mounts":[{{range $i,$m := .Mounts}}{{if $i}},{{end}}{"type":{{json $m.Type}},"source":{{json $m.Source}},"target":{{json $m.Destination}},"rw":{{json $m.RW}}}{{end}}]}'
function Host-Clock { @{unixMs=[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds();qpc=[Diagnostics.Stopwatch]::GetTimestamp();frequency=[Diagnostics.Stopwatch]::Frequency} }
function Check-ReadinessMounts($Plan,$Packet,[string]$CID){
 Keys-Exact $Packet @('id','mounts')
 if($Packet.id -cne $CID -or $Packet.mounts -isnot [array]){throw 'MOUNT_BINDING'}
 $expected=@($Plan.rows)+@{source=(Join-Path (Get-Location).Path 'labs/tiktok/ui-source-live-attempt/clock.cjs');target='/probe/clock.cjs'}
 if($Packet.mounts.Count -ne $expected.Count){throw 'MOUNT_COUNT'}
 $seen=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal);$map=@()
 foreach($m in $Packet.mounts){
  Keys-Exact $m @('type','source','target','rw')
  if($m.type -cne 'bind' -or $m.rw -isnot [bool] -or $m.rw -or $m.source -isnot [string] -or !$m.source.StartsWith('/') -or !$seen.Add([string]$m.target)){throw 'MOUNT_UNPROVEN'}
  $row=@($expected|Where-Object target -CEQ $m.target);if($row.Count -ne 1){throw 'MOUNT_UNPROVEN'}
  $map+=@{windowsSource=$row[0].source;observedEngineSource=$m.source;target=$m.target;cid=$CID;method='EXACT_CREATE_ARGV_INSPECT_TARGET_AND_CONTENT_HASH_NO_PREFIX_INFERENCE'}
 }
 return ,$map
}
function Check-ReadinessPacket($Plan,$Packet){
 Keys-Exact $Packet @('mode','nonce','node','platform','uid','unixMs','monotonicNs','files')
 if($Packet.mode -cne 'READINESS_ONLY_NO_SOURCE_AUTHORITY' -or $Packet.nonce -cne $Plan.runID -or $Packet.node -cne '22.22.3' -or $Packet.platform -cne 'linux' -or $Packet.uid -ne 1000 -or $Packet.monotonicNs -cnotmatch '^[0-9]{10,24}$' -or $Packet.files -isnot [array] -or $Packet.files.Count -ne $Plan.rows.Count){throw 'CLOCK_PACKET_SCOPE'}
 $seen=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
 foreach($f in $Packet.files){Keys-Exact $f @('target','sha256');$r=@($Plan.rows|Where-Object target -CEQ $f.target);if($r.Count -ne 1 -or !$seen.Add([string]$f.target) -or $f.sha256 -cne $r[0].sha256){throw 'LEAF_CONTENT_MISMATCH'}}
}
function Check-ReadinessCleanupMounts($Packet,[string]$CID){
 Keys-Exact $Packet @('id','mounts')
 if($Packet.id -cne $CID -or $Packet.mounts -isnot [array]){throw 'MOUNT_BINDING'}
 foreach($m in $Packet.mounts){
  Keys-Exact $m @('type','source','target','rw')
  # This probe owns no writable bind. Exact layout/content is a runtime guard,
  # not a deletion prerequisite; unknown volumes and writable binds remain held.
  if($m.type -cne 'bind' -or $m.rw -isnot [bool] -or $m.rw){throw 'MOUNT_UNPROVEN'}
 }
}
function Readiness-Limit([long]$Elapsed,[bool]$Cleanup){
 $left=$(if($Cleanup){80000}else{60000})-$Elapsed
 if($left -lt 600){throw 'READINESS_DEADLINE'}
 return [int][Math]::Min(15000,$left)
}
function Readiness-ErrorType($ErrorRecord){
 $type=$ErrorRecord.Exception.GetType().FullName
 $known=@{'System.Management.Automation.CommandNotFoundException'='COMMAND_RESOLUTION';'System.Management.Automation.ParameterBindingException'='PARAMETER_BINDING';'System.Management.Automation.ParameterBindingArgumentTransformationException'='PARAMETER_TRANSFORM';'System.Management.Automation.MethodInvocationException'='METHOD_INVOCATION';'System.Management.Automation.RuntimeException'='RUNTIME_EXCEPTION';'System.NullReferenceException'='NULL_REFERENCE';'System.InvalidOperationException'='INVALID_OPERATION'}
 return $(if($known.ContainsKey($type)){$known[$type]}else{'OTHER_EXCEPTION_NO_MESSAGE'})
}
function Invoke-ReadinessBatch($Plan,[scriptblock]$Native,[scriptblock]$Sink,[scriptblock]$Clock,[scriptblock]$PortCheck){
 # Injection is for pure tests only; this function cannot create a source context.
 $start=& $Clock;$calls=0;$cid=$null;$issued=$false;$clear=$false;$recovered=$false;$closed=$false;$absent=$false;$logOK=$true;$cause=$null;$clockPair=$null;$mapping=@();$nativeRows=[Collections.Generic.List[object]]::new()
 $role=@{name=$Plan.name;image=$Plan.image;user='1000:1000';memoryMiB=512;cpu=0.75;pids=160;tmpfs=@();mounts=@($Plan.rows)+@{target='/probe/clock.cjs'}}
 $identityPlan=@{runID=$Plan.runID;task=$Plan.taskMarker}
 function Put([string]$Name,$Value){try{& $Sink $Name $Value}catch{$script:ReadinessLogError=$true;throw 'READINESS_LOG_INCOMPLETE'}}
 $script:ReadinessLogError=$false
 function Call([string]$Op,[string[]]$Argv,[bool]$Cleanup=$false){
  $limit=Readiness-Limit ((& $Clock)-$start) $Cleanup
  $script:ReadinessCallSequence++
  try{Put ('invoke-intent-'+$script:ReadinessCallSequence.ToString('D3')) @{operation=$Op;limitMs=$limit;cap=65536;cleanup=$Cleanup;argvRecordedInPlan=$true}}catch{if(!$Cleanup){throw}}
  try{$r=& $Native $Op $Argv $limit 65536}catch{
   $row=@{operation=$Op;limitMs=$limit;cap=65536;resultObserved=$false;rootExit=$null;code='NATIVE_WRAPPER_EXCEPTION';exceptionCode=Readiness-ErrorType $_};$nativeRows.Add($row)
   try{Put ('invoke-error-'+$script:ReadinessCallSequence.ToString('D3')) $row}catch{}
   throw 'NATIVE_WRAPPER_EXCEPTION'
  }
  $row=Native-Projection $r $Op;$row.limitMs=$limit;$nativeRows.Add($row)
  # Do not lose a CREATE result if persistence fails. Cleanup receives it first.
  if($Op -ceq 'create' -and $r.RawOut.Trim() -cmatch '^[a-f0-9]{64}$'){$script:ReadinessCID=$r.RawOut.Trim()}
  try{Put ('native-'+$script:ReadinessCallSequence.ToString('D3')) $row}catch{if(!$Cleanup){throw}}
  if(!(Native-Accepted $r)){throw 'NATIVE_FAIL'}
  return $r
 }
 function Owner([string]$Ref,[bool]$Cleanup){$r=Call 'owner' @('container','inspect',$Ref,'--format',$script:Projection.owner) $Cleanup;$g=Read-JSON $r.RawOut;Assert-Identity $identityPlan $role $g $script:ReadinessCID;return $g}
 $script:ReadinessCallSequence=0;$script:ReadinessCID=$null
 try{
  Put 'attempt-once' @{runID=$Plan.runID;sourceGate=$false;workMs=60000;hardMs=80000;grants=0;claims=0}
  & $PortCheck
  $r=Call 'collision' @('ps','--all','--no-trunc','--filter',('name=^/'+$Plan.name+'$'),'--format',$script:Projection.list)
  if(![string]::IsNullOrWhiteSpace($r.RawOut)){throw 'COLLISION_OR_UNKNOWN'};$clear=$true
  Put 'create-intent' @{runID=$Plan.runID;name=$Plan.name;image=$Plan.image;task=$Plan.taskMarker;planSHA=$Plan.planSHA}
  $issued=$true;$r=Call 'create' $Plan.argv
  $cid=$script:ReadinessCID;if(!$cid){throw 'CREATE_RESULT_UNKNOWN'}
  Put 'created' @{cid=$cid;name=$Plan.name;runID=$Plan.runID;image=$Plan.image}
  $null=Owner $cid $false
  $r=Call 'guards' @('container','inspect',$cid,'--format',$script:Projection.guard);$g=Read-JSON $r.RawOut
  # Docker represents no tmpfs as null. Only this readiness role plans none.
  if($null -eq $g.tmpfs){$g.tmpfs=@{}};Assert-Guard $role $g $cid;Put 'guards' $g
  $r=Call 'mounts' @('container','inspect',$cid,'--format',$script:MountProjection);$mapping=Check-ReadinessMounts $Plan (Read-JSON $r.RawOut) $cid
  Put 'observed-mount-map' $mapping
  $before=Host-Clock;$r=Call 'clock-start' @('start','--attach',$cid);$after=Host-Clock
  $packet=Read-JSON $r.RawOut;Check-ReadinessPacket $Plan $packet;$clockPair=Check-ClockPair $before $after $packet
  Put 'clock-content' @{hostBefore=$before;hostAfter=$after;packet=$packet;clockPair=$clockPair;scope='SNAPSHOT_NOT_LIVE_DEADLINE_OR_AUTHORITY'}
  $r=Call 'state' @('container','inspect',$cid,'--format',$script:Projection.state);$s=Read-JSON $r.RawOut;Assert-State $s $cid;Put 'container-state' $s
 }catch{$cause=Live-Code $_}finally{
  $cid=$script:ReadinessCID
  if($issued){
   try{
    if(!$cid){if(!$clear){throw 'OWNERSHIP_UNPROVEN'};$recovered=$true;$owner=Owner $Plan.name $true;$cid=$owner.id;$script:ReadinessCID=$cid}else{$owner=Owner $cid $true}
    if(!$cid){$cid=$owner.id;$script:ReadinessCID=$cid};Assert-Identity $identityPlan $role $owner $cid
    $r=Call 'cleanup-mounts' @('container','inspect',$cid,'--format',$script:MountProjection) $true
    Check-ReadinessCleanupMounts (Read-JSON $r.RawOut) $cid
    $null=Call 'remove' @('rm','--force',$cid) $true
    $r=Call 'cid-absence' @('ps','--all','--no-trunc','--filter',('id='+$cid),'--format',$script:Projection.list) $true
    if(![string]::IsNullOrWhiteSpace($r.RawOut)){throw 'ABSENCE_UNKNOWN'};$closed=$true
   }catch{$closed=$false;if(!$cause){$cause=Live-Code $_}}
  }else{$closed=$true}
  try{
   $r=Call 'name-absence' @('ps','--all','--no-trunc','--filter',('name=^/'+$Plan.name+'$'),'--format',$script:Projection.list) $true
   $n=Call 'label-absence' @('ps','--all','--no-trunc','--filter',('label=com.wed-snap.run='+$Plan.runID),'--filter',('label=com.wed-snap.task='+$Plan.taskMarker),'--format',$script:Projection.list) $true
   $absent=[string]::IsNullOrWhiteSpace($r.RawOut) -and [string]::IsNullOrWhiteSpace($n.RawOut)
  }catch{if(!$cause){$cause=Live-Code $_}}
 }
 $result=@{schema='wed-live-readiness-result-v1';runID=$Plan.runID;readinessPASS=(!$cause -and $closed -and $absent -and !$script:ReadinessLogError);cause=$cause;cleanupClosed=$closed;scopedAbsent=$absent;cid=$cid;createIssued=$issued;recoveryUsed=$recovered;clockPair=$clockPair;mappingCount=$mapping.Count;elapsedMs=(& $Clock)-$start;nativeCalls=$nativeRows.ToArray();logComplete=(!$script:ReadinessLogError);sourceCalls=0;liveGrants=0;sourceClaims=0;utc=[DateTimeOffset]::UtcNow.ToString('o')}
 try{Put 'result' $result}catch{$result.readinessPASS=$false;$result.logComplete=$false}
 return $result
}
function Live-Code($ErrorRecord){
 $safe=@('READINESS_DEADLINE','READINESS_LOG_INCOMPLETE','NATIVE_FAIL','NATIVE_WRAPPER_EXCEPTION','COLLISION_OR_UNKNOWN','CREATE_RESULT_UNKNOWN','OWNERSHIP_UNPROVEN','MOUNT_BINDING','MOUNT_COUNT','MOUNT_UNPROVEN','LEAF_CONTENT_MISMATCH','CLOCK_PACKET_SCOPE','CLOCK_PAIR_UNBOUNDED','CLOCK_PACKET_TYPE','CLOCK_SKEW_NOT_BOUNDED','ABSENCE_UNKNOWN','PORT_UNAVAILABLE','PIN_DRIFT','GUARD_MISMATCH','CONTAINER_STATE_FAIL')
 if($ErrorRecord.Exception.Message -cin $safe){return $ErrorRecord.Exception.Message};return 'READINESS_ERROR_NO_MESSAGE'
}
