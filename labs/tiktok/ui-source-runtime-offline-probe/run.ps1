param([Parameter(Mandatory)][ValidatePattern('^[a-f0-9]{64}$')][string]$PlanSHA)
. (Join-Path $PSScriptRoot 'common.ps1')
$planPath=Join-Path $script:Root 'plan.json'
if((Get-FileHash $planPath).Hash.ToLowerInvariant() -cne $PlanSHA){throw 'APPROVED_PLAN_HASH_REQUIRED'}
$script:Plan=Get-Content $planPath -Raw|ConvertFrom-Json
if($script:Plan.sourceGate -ne $false -or $script:Plan.endpoint -cne $script:Endpoint -or $script:Plan.task -cne $script:TaskMarker -or $script:Plan.workSeconds -ne 240 -or $script:Plan.cleanupReserveSeconds -ne 60 -or $script:Plan.maxRunning -ne 1){throw 'PROBE_SCOPE_MISMATCH'}
foreach($pin in @($script:Plan.sourcePins)+@($script:Plan.baselinePins)+@(@{path=$script:Docker;sha256=$script:DockerSHA},@{path=$script:Plan.helperSource;sha256=$script:HelperSHA},@{path=$script:Plan.binary;sha256=$script:Plan.binarySHA})){if((Get-FileHash $pin.path).Hash.ToLowerInvariant() -cne $pin.sha256){throw 'EXECUTION_PIN_DRIFT'}}
No-Overrides
Save (Join-Path $script:Root 'attempt-once.json') @{runID=$script:Plan.runID;planSHA=$PlanSHA;mode='OFFLINE_LIFECYCLE_ONLY_NOT_SOURCE_AUTHORITY';utc=[DateTimeOffset]::UtcNow.ToString('o')}
if('WedOwnerWin32.Engine' -as [type]){throw 'UNOWNED_PRELOADED_TYPE'}
Add-Type -Path $script:Plan.binary;$script:Engine='WedOwnerWin32.Engine' -as [type]
if($script:Engine.Assembly.Location -cne $script:Plan.binary -or $script:Engine.Module.ModuleVersionId.ToString() -cne $script:Plan.MVID){throw 'ASSEMBLY_PROVENANCE'}
$null=$script:Engine::Layout();$script:clock=[Diagnostics.Stopwatch]::StartNew();$script:counter=0;$script:natives=[Collections.Generic.List[object]]::new();$results=[Collections.Generic.List[object]]::new();$ledger=[Collections.Generic.List[object]]::new()
$ownershipTemplate='{"id":{{json .ID}},"name":{{json .Name}},"image":{{json .Image}},"user":{{json .Config.User}},"run":{{json (index .Config.Labels "com.wed-snap.run")}},"task":{{json (index .Config.Labels "com.wed-snap.task")}},"running":{{json .State.Running}},"status":{{json .State.Status}},"exit":{{json .State.ExitCode}},"oom":{{json .State.OOMKilled}},"errorPresent":{{if .State.Error}}true{{else}}false{{end}},"rootRO":{{json .HostConfig.ReadonlyRootfs}},"privileged":{{json .HostConfig.Privileged}},"capAdd":{{json .HostConfig.CapAdd}},"capDrop":{{json .HostConfig.CapDrop}},"security":{{json .HostConfig.SecurityOpt}},"memory":{{json .HostConfig.Memory}},"swap":{{json .HostConfig.MemorySwap}},"pids":{{json .HostConfig.PidsLimit}},"nanoCPU":{{json .HostConfig.NanoCpus}},"ipc":{{json .HostConfig.IpcMode}},"cgroupns":{{json .HostConfig.CgroupnsMode}},"network":{{json .HostConfig.NetworkMode}},"portCount":{{len .HostConfig.PortBindings}},"networks":{{json .NetworkSettings.Networks}},"tmpfs":{{json .HostConfig.Tmpfs}},"mounts":[{{range $i,$m:=.Mounts}}{{if $i}},{{end}}{"type":{{json $m.Type}},"name":{{json $m.Name}},"source":{{json $m.Source}},"target":{{json $m.Destination}},"rw":{{json $m.RW}}}{{end}}]}'
$listTemplate='{"id":{{json .ID}},"name":{{json .Names}},"run":{{json (.Label "com.wed-snap.run")}},"task":{{json (.Label "com.wed-snap.task")}}}'
function Native([string]$Name,[string[]]$Argv,[switch]$Attach,[switch]$Cleanup){
 No-Overrides
 foreach($pair in @(@($script:Docker,$script:DockerSHA),@($script:Plan.helperSource,$script:HelperSHA),@($script:Plan.binary,$script:Plan.binarySHA))){if((Get-FileHash $pair[0]).Hash.ToLowerInvariant() -cne $pair[1]){throw 'NATIVE_PIN_DRIFT'}}
 $until=if($Cleanup){300000}else{240000};$left=$until-$script:clock.ElapsedMilliseconds;$limit=[int][Math]::Min($(if($Attach){20000}else{15000}),$left)
 if($limit -lt 600){throw 'NATIVE_BUDGET_EXHAUSTED'}
 if($Argv[0] -cnotin @('image','ps','create','container','start','rm')){throw 'NATIVE_VERB_NOT_IN_PLAN'}
 $script:counter++;$utc=[DateTimeOffset]::UtcNow;$actualArgv=@('--host',$script:Endpoint)+$Argv
 $r=$script:Engine::Run($script:Docker,[string[]]$actualArgv,(Get-Location).Path,$limit,65536,'None',$null)
 $ok=Native-OK $r
 $err=if($r.RawErr -match '(?i)access is denied|permission denied'){'ACCESS_DENIED'}elseif($r.RawErr -match '(?i)no such|not found'){'NOT_FOUND'}elseif($r.StderrBytes){'STDERR_PRESENT_NO_MESSAGE'}else{$null}
 $receipt=@{operation=$Name;argv=@($script:Docker)+$actualArgv;actualExit=$r.RootExit;nativeStatus=$r.Status;nativeAccepted=$ok;forcedTermination=$r.TerminationRequested;timedOut=$r.Timeout;byteCapExceeded=$r.ByteCapExceeded;limitMs=$limit;byteCap=65536;elapsedMs=$r.ElapsedMs;stdoutBytes=$r.StdoutBytes;stderrBytes=$r.StderrBytes;retainedBytes=$r.RetainedBytes;jobAfterRootRelease=$r.AfterRootRelease;jobFinalActive=$r.FinalActive;treeClosed=$r.TreeClosed;pipesEOF=$r.PipesEOF;cleanupClosed=$r.CleanupClosed;liveHandles=$r.LiveHandles;liveBuffers=$r.LiveBuffers;backgroundReaders=$r.BackgroundReaders;phase=$r.Phase;win32Error=$r.Win32Error;stderrCode=$err;rawOutput='BOUNDED_RAM_ONLY';cleanupStage=[bool]$Cleanup;utc=$utc.ToString('o');vn=[TimeZoneInfo]::ConvertTimeBySystemTimeZoneId($utc,'SE Asia Standard Time').ToString('o')}
 Save (Join-Path $script:Root ('native-'+$script:counter.ToString('D3')+'-'+$Name+'.json')) $receipt;$script:natives.Add($receipt)
 [pscustomobject]@{OK=$ok;Out=$r.RawOut;Err=$r.RawErr;Receipt=$receipt}
}
function Read-Owner($Role,[string]$Ref,[string]$Phase,[switch]$Cleanup){
 $r=Native ($Phase+'-'+$Role.role) @('container','inspect',$Ref,'--format',$ownershipTemplate) -Cleanup:$Cleanup
 if(!$r.OK){throw 'OWNER_INSPECT_NATIVE_FAILED'}
 $g=$r.Out|ConvertFrom-Json -DateKind String
 $g.networks=@($g.networks.PSObject.Properties|Where-Object MemberType -EQ NoteProperty|ForEach-Object Name)
 Assert-Owner $Role $g $(if($Ref -cmatch '^[a-f0-9]{64}$'){$Ref}else{''})
 Save (Join-Path $script:Root ($Role.role+'/'+$Phase+'.json')) $g;return $g
}
function Recover($Role,$Record){
 if(!$Record.createIssued -or $Record.recoveryAttempted){return};$Record.recoveryAttempted=$true
 # Recovery is one read by exact intended name, never another create or adopt.
 $g=Read-Owner $Role $Role.name 'recover-created-name' -Cleanup
 $Record.cid=$g.id;$Record.ownerVerified=$true
 Save (Join-Path $script:Root ($Role.role+'/recovered-cid.json')) @{cid=$g.id;name=$g.name;run=$g.run;task=$g.task;image=$g.image;createRetried=$false}
}
function Cleanup-Role($Role,$Record){
 $closed=$false;$errorCode=$null
 try{
  if(!$Record.cid){Recover $Role $Record}
  if(!$Record.cid){if(!$Record.createIssued){return @{closed=$true;created=$false}};throw 'CREATE_RESULT_UNKNOWN_NO_CID'}
  $g=Read-Owner $Role $Record.cid 'before-cleanup' -Cleanup
  $Record.ownerVerified=$true
  $volumeCount=@($g.mounts|Where-Object type -CEQ volume).Count
  # All declared VOLUMEs were covered by tmpfs and no volume source/volume-from
  # was passed. Unexpected volume provenance stays UNKNOWN; never delete it.
  $rm=Native ('remove-own-'+$Role.role) @('rm','--force',$Record.cid) -Cleanup
  if(!$rm.OK){throw 'OWN_CID_REMOVE_FAILED'}
  $absence=Native ('cid-absence-'+$Role.role) @('ps','--all','--no-trunc','--filter',('id='+$Record.cid),'--format','{{.ID}}') -Cleanup
  if(!$absence.OK -or ![string]::IsNullOrWhiteSpace($absence.Out)){throw 'OWN_CID_ABSENCE_UNKNOWN'}
  $closed=$volumeCount -eq 0
  if(!$closed){$errorCode='UNEXPECTED_VOLUME_NOT_REMOVED_NO_PROVENANCE'}
 }catch{
  $codes=@('CREATE_RESULT_UNKNOWN_NO_CID','OWNER_INSPECT_NATIVE_FAILED','OWNERSHIP_UNPROVEN_NO_DESTRUCTIVE_ACTION','OWN_CID_REMOVE_FAILED','OWN_CID_ABSENCE_UNKNOWN','NATIVE_BUDGET_EXHAUSTED','NATIVE_PIN_DRIFT')
  $errorCode=if($_.Exception.Message -cin $codes){$_.Exception.Message}else{'CLEANUP_UNKNOWN_NO_MESSAGE'}
 }
 $doc=@{closed=$closed;cid=$Record.cid;ownerVerified=$Record.ownerVerified;errorCode=$errorCode;noGlobalRemoval=$true;utc=[DateTimeOffset]::UtcNow.ToString('o')}
 Save (Join-Path $script:Root ($Role.role+'/cleanup.json')) $doc;return $doc
}
$overall=$false;$cleanupOK=$true;$failure=$null;$volumes=@{}
try{
 Save (Join-Path $script:Root 'runtime-clock.json') @{workSeconds=240;cleanupReserveSeconds=60;startUTC=[DateTimeOffset]::UtcNow.ToString('o');approvalAndPreparationExcluded=$true}
 $ids=@($script:Plan.roles.image|Sort-Object -Unique)
 $m=Native 'declared-image-volumes' (@('image','inspect')+$ids+@('--format','{"id":{{json .ID}},"volumes":{{json .Config.Volumes}}}'))
 if(!$m.OK){throw 'IMAGE_VOLUME_METADATA_FAILED'}
 $meta=@($m.Out -split '\r?\n'|Where-Object{$_}|ForEach-Object{$_|ConvertFrom-Json})
 if($meta.Count -ne 4){throw 'IMAGE_VOLUME_METADATA_COUNT'}
 foreach($v in $meta){if($v.id -cnotin $ids -or $volumes.ContainsKey($v.id)){throw 'IMAGE_VOLUME_METADATA_ID'};$volumes[$v.id]=@($v.volumes.PSObject.Properties|Where-Object MemberType -EQ NoteProperty|ForEach-Object Name)}
 foreach($role in $script:Plan.roles){foreach($path in $volumes[$role.image]){if($path -cnotin @($role.tmpfs|ForEach-Object{($_ -split ':',2)[0]})){throw 'IMAGE_VOLUME_NOT_COVERED_BY_PLANNED_TMPFS'}}}
 Save (Join-Path $script:Root 'image-volume-projection.json') $meta
 $pre=Native 'prospective-name-collision' @('ps','--all','--no-trunc','--filter',('name=^/wed-source-'+$script:Plan.runID+'-offline-'),'--format',$listTemplate)
 if(!$pre.OK -or ![string]::IsNullOrWhiteSpace($pre.Out)){throw 'PROSPECTIVE_NAME_COLLISION_OR_UNKNOWN'}
 Save (Join-Path $script:Root 'preflight.json') @{prospectiveNameRows=0;runID=$script:Plan.runID;noOldResourcesAdopted=$true;imageVolumesCovered=$true}
 foreach($role in $script:Plan.roles){
  if($script:clock.ElapsedMilliseconds -gt 210000){throw 'NEW_ROLE_ADMISSION_BUDGET'}
  if(@($ledger|Where-Object{$_.createIssued -and !$_.closed}).Count){throw 'PRIOR_RESOURCE_NOT_CLOSED'}
  foreach($pin in $role.mounts){if((Get-FileHash $pin.source).Hash.ToLowerInvariant() -cne $pin.sha256){throw 'MOUNT_SOURCE_CHANGED'}}
  $record=[pscustomobject]@{role=$role.role;name=$role.name;image=$role.image;cid=$null;createIssued=$false;recoveryAttempted=$false;ownerVerified=$false;closed=$false};$ledger.Add($record)
  Save (Join-Path $script:Root ($role.role+'/intent.json')) @{role=$role.role;name=$role.name;image=$role.image;runID=$script:Plan.runID;task=$script:TaskMarker;argv=$role.argv;freshAttemptOnly=$true;utc=[DateTimeOffset]::UtcNow.ToString('o')}
  $roleOK=$false;$roleCause=$null;$state=$null;$packets=@();$attach=$null
  try{
   $record.createIssued=$true;$create=Native ('create-'+$role.role) $role.argv
   if($create.Out.Trim() -cmatch '^[a-f0-9]{64}$'){$record.cid=$create.Out.Trim();Save (Join-Path $script:Root ($role.role+'/created-cid.json')) @{cid=$record.cid;nativeAccepted=$create.OK;name=$role.name;image=$role.image}}
   if(!$create.OK -or !$record.cid){throw 'CREATE_NATIVE_OR_OUTPUT_FAILED'}
   $g=Read-Owner $role $record.cid 'before-start';$record.ownerVerified=$true;Assert-Guards $role $g
   $attach=Native ('start-attach-'+$role.role) @('start','--attach',$record.cid) -Attach
   $state=Read-Owner $role $record.cid 'after-exit';Assert-Guards $role $state
   foreach($line in @($attach.Out -split '\r?\n'|Where-Object{$_})){
    if($line.Length -gt 32768 -or !$line.StartsWith('{')){throw 'UNEXPECTED_PROBE_OUTPUT'}
    $packet=$line|ConvertFrom-Json -DateKind String
    if($packet.role -cne $role.role -or $packet.kind -cnotin @('kernel','role','media-import','failure')){throw 'PROBE_PACKET_BINDING'}
    $packets+=,$packet
   }
   Save (Join-Path $script:Root ($role.role+'/packets.json')) $packets
   if(!$attach.OK){throw 'ATTACH_NATIVE_FAILED'}
   if($state.running -or $state.status -cne 'exited' -or $state.exit -ne 0 -or $state.oom -or $state.errorPresent){throw 'CONTAINER_NATIVE_STATE_FAILED'}
   if(@($packets|Where-Object{$_.kind -ceq 'kernel' -and $_.ok -eq $true}).Count -ne 1 -or @($packets|Where-Object{$_.kind -ceq 'role' -and $_.ok -eq $true}).Count -ne 1 -or @($packets|Where-Object kind -CEQ failure).Count){throw 'RUNTIME_ASSERTIONS_FAILED'}
   if($role.role -ceq 'app' -and @($packets|Where-Object{$_.kind -ceq 'media-import' -and $_.ok -eq $true}).Count -ne 1){throw 'MEDIA_IMPORT_ASSERTION_FAILED'}
   $roleOK=$true
  }catch{
   $known=@('CREATE_NATIVE_OR_OUTPUT_FAILED','OWNER_INSPECT_NATIVE_FAILED','OWNERSHIP_UNPROVEN_NO_DESTRUCTIVE_ACTION','HOSTCONFIG_GUARD_MISMATCH','READONLY_BIND_GUARD','UNEXPECTED_PERSISTENT_VOLUME','ATTACH_NATIVE_FAILED','CONTAINER_NATIVE_STATE_FAILED','RUNTIME_ASSERTIONS_FAILED','MEDIA_IMPORT_ASSERTION_FAILED','UNEXPECTED_PROBE_OUTPUT','PROBE_PACKET_BINDING','NATIVE_BUDGET_EXHAUSTED')
   $roleCause=if($_.Exception.Message -cin $known){$_.Exception.Message}else{'ROLE_ERROR_NO_MESSAGE'}
  }finally{
   $cleanup=Cleanup-Role $role $record;$record.closed=$cleanup.closed;if(!$cleanup.closed){$cleanupOK=$false}
  }
  $row=@{role=$role.role;runtimePASS=$roleOK;cause=$roleCause;cid=$record.cid;containerExit=$(if($state){$state.exit}else{$null});containerOOM=$(if($state){$state.oom}else{$null});attachNativeExit=$(if($attach){$attach.Receipt.actualExit}else{$null});attachNativeStatus=$(if($attach){$attach.Receipt.nativeStatus}else{'NOT_RUN'});cleanupClosed=$record.closed;sourceGate=$false}
  Save (Join-Path $script:Root ($role.role+'/result.json')) $row;$results.Add($row);Save (Join-Path $script:Root ('ledger-after-'+$role.role+'.json')) $ledger.ToArray()
  Write-Output ('ROLE_'+$role.role+'_RUNTIME_'+$roleOK+'_CLEANUP_'+$record.closed)
  if(!$roleOK -or !$record.closed){throw 'ROLE_FAILED_STOP_DEPENDENCIES'}
 }
 $overall=$results.Count -eq 5
}catch{
 $known=@('IMAGE_VOLUME_METADATA_FAILED','IMAGE_VOLUME_METADATA_COUNT','IMAGE_VOLUME_METADATA_ID','IMAGE_VOLUME_NOT_COVERED_BY_PLANNED_TMPFS','PROSPECTIVE_NAME_COLLISION_OR_UNKNOWN','NEW_ROLE_ADMISSION_BUDGET','PRIOR_RESOURCE_NOT_CLOSED','MOUNT_SOURCE_CHANGED','ROLE_FAILED_STOP_DEPENDENCIES','NATIVE_BUDGET_EXHAUSTED')
 $failure=if($_.Exception.Message -cin $known){$_.Exception.Message}else{'RUNTIME_ATTEMPT_ERROR_NO_MESSAGE'}
}finally{
 # Per-role finally runs for every create attempt; outer catch also handles
 # failure before any admission. No resource may be adopted by global sweep.
 try{
  $names=Native 'final-own-name-absence' @('ps','--all','--no-trunc','--filter',('name=^/wed-source-'+$script:Plan.runID+'-offline-'),'--format',$listTemplate) -Cleanup
  $labels=Native 'final-own-label-absence' @('ps','--all','--no-trunc','--filter',('label=com.wed-snap.run='+$script:Plan.runID),'--filter',('label=com.wed-snap.task='+$script:TaskMarker),'--format','{{.ID}}') -Cleanup
  $absenceOK=$names.OK -and $labels.OK -and [string]::IsNullOrWhiteSpace($names.Out) -and [string]::IsNullOrWhiteSpace($labels.Out)
  if(!$absenceOK){$cleanupOK=$false}
  Save (Join-Path $script:Root 'final-absence.json') @{closed=$absenceOK;scope='EXACT_PROSPECTIVE_NAMES_AND_RUN_TASK_LABELS';globalAbsence='NOT_CLAIMED';CIDs=@($ledger|ForEach-Object cid);perCIDClosed=@($ledger|Where-Object{!$_.closed}).Count -eq 0}
 }catch{$cleanupOK=$false;Save (Join-Path $script:Root 'final-absence.json') @{closed=$false;scope='UNKNOWN_NATIVE_OR_BUDGET';CIDs=@($ledger|ForEach-Object cid)}}
 Save (Join-Path $script:Root 'ledger-final.json') $ledger.ToArray()
 Save (Join-Path $script:Root 'native-index.json') $script:natives.ToArray()
 Save (Join-Path $script:Root 'frozen-after.json') (Frozen)
 foreach($pin in @($script:Plan.sourcePins)+@($script:Plan.baselinePins)){if((Get-FileHash $pin.path).Hash.ToLowerInvariant() -cne $pin.sha256){$overall=$false;$failure='FINAL_SOURCE_DRIFT'}}
 Save (Join-Path $script:Root 'source-pins-after.json') (Pins)
 Save (Join-Path $script:Root 'summary.json') @{status=$(if($overall -and $cleanupOK){'OFFLINE_RUNTIME_PASS_PENDING_REVIEW_SOURCE_HOLD'}else{'OFFLINE_RUNTIME_FAIL_OR_UNKNOWN_SOURCE_HOLD'});allFiveRolesRuntimePASS=$overall;cleanupClosed=$cleanupOK;failure=$failure;roles=$results.ToArray();notRunRoles=@($script:Plan.roles.role|Where-Object{$_ -cnotin @($results|ForEach-Object role)});nativeCalls=$script:counter;runtimeElapsedMs=$script:clock.ElapsedMilliseconds;workLimitSeconds=240;hardWithCleanupSeconds=300;maxRunningPlanned=1;customNetworksCreated=0;sourceCalls=0;sourceGate=$false;liveKeys=0;liveApproval=0;liveClaim=0;mainChanges=0;clockSkew='UNKNOWN_NOT_RUN';portCheck='UNKNOWN_NOT_RUN';egressPhaseTLS='NOT_RUN';browserE2E='NOT_RUN';OSHardKillDaemonCleanup='NOT_PROVEN';utc=[DateTimeOffset]::UtcNow.ToString('o')}
}
if(!$overall -or !$cleanupOK){Write-Output 'OFFLINE_RUNTIME_FAIL_OR_UNKNOWN_SOURCE_HOLD';exit 20}
Write-Output 'OFFLINE_RUNTIME_PASS_SOURCE_HOLD';exit 0
