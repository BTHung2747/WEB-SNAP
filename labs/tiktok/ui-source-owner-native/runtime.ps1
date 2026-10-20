function Get-RemainingNativeMs($Context,[string]$Stage='work'){
 $deadline=switch($Stage){startup{$Context.StartupDeadline}cleanup{$Context.CleanupDeadline}seal{$Context.HardDeadline}default{$Context.WorkDeadline}}
 [int][Math]::Floor(($deadline-[Diagnostics.Stopwatch]::GetTimestamp())*1000.0/[Diagnostics.Stopwatch]::Frequency)
}
function Write-ExclusiveJSON([string]$Path,$Value){
 $bytes=[Text.Encoding]::UTF8.GetBytes(($Value|ConvertTo-Json -Depth 25 -Compress));$f=[IO.FileStream]::new($Path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
 try{$f.Write($bytes,0,$bytes.Length);$f.Flush($true)}finally{$f.Dispose()}
}
function Save-NativeReceipts($Context){
 $state=Get-NativeContext $Context
 if($state.PSObject.Properties['Bridge']){
  if(!$state.Bridge.ContainsKey('savedReceipts')){$state.Bridge.savedReceipts=0}
  while($state.Bridge.savedReceipts -lt $Context.NativeReceipts.Count){$i=$state.Bridge.savedReceipts;$state.Bridge.savedReceipts++;try{$null=Write-CappedReceipt (Join-Path $Context.Root ('owner-private/native-'+($i+1).ToString('D4')+'.json')) $Context.NativeReceipts[$i] $null}catch{$state.Bridge.traceFailed=$true}}
  return
 }
 if($Context.Root){$lines=@($Context.NativeReceipts|ForEach-Object{$_|ConvertTo-Json -Depth 6 -Compress});[IO.File]::WriteAllLines((Join-Path $Context.Root 'owner-private/native-receipts.jsonl'),$lines,[Text.UTF8Encoding]::new($false))}
}
function Invoke-DockerNative($Context,[string]$Operation,[string[]]$Argv,[string]$Stage='work',[int]$MaxMs=30000){
 try{Invoke-DockerNativeCore $Context $Operation $Argv $Stage $MaxMs}catch{$original=$_;try{$s=Get-NativeContext $Context;if($s.PSObject.Properties['Bridge']){Write-BridgeTrace $Context 'WRAPPER_ERROR' $Operation (Bridge-Exception $original)}}catch{};throw $original}
}
function Invoke-DockerNativeCore($Context,[string]$Operation,[string[]]$Argv,[string]$Stage='work',[int]$MaxMs=30000){
 Assert-ExecutionContext $Context -Docker
 $state=Get-NativeContext $Context;$bridge=[bool]$state.PSObject.Properties['Bridge']
 if($bridge){$state.Bridge.methodStage=$Stage}
 if($bridge){Write-BridgeTrace $Context 'WRAPPER_ENTER' $Operation @{argumentCount=$Argv.Count;stage=$Stage}}
 if($bridge){$Argv=Bridge-DockerArgs $Context $Argv}
 Assert-NativeTreeCapability $Context
 $left=Get-RemainingNativeMs $Context $Stage;$limit=[Math]::Min($MaxMs,$left)
 if($Stage -ceq 'cleanup'){$limit=[Math]::Min($limit,[int][Math]::Floor($left/[Math]::Max(1,$Context.CleanupCallsLeft)));$Context.CleanupCallsLeft=[Math]::Max(1,$Context.CleanupCallsLeft-1)}
 if($limit -lt 600){throw 'OWNER_NATIVE_DEADLINE'}
 if((Get-FileHash -LiteralPath $Context.Tools.docker.path).Hash.ToLowerInvariant() -cne $Context.Tools.docker.sha256){throw 'DOCKER_EXECUTABLE_CHANGED'}
 try{$r=Invoke-NativeBoundary $Context $Operation $Context.Tools.docker.path $Argv $limit}catch{if($bridge){Write-BridgeTrace $Context 'ERROR' $Operation (Bridge-Exception $_)};throw}
 if($bridge){Write-BridgeTrace $Context 'BEFORE_SINK' $Operation}
 Save-NativeReceipts $Context;if($bridge){Write-BridgeTrace $Context 'SINK_COMPLETE' $Operation}
 Assert-NativeSuccess $r
 if($bridge -and $state.Bridge.traceFailed -and $Stage -cne 'cleanup'){throw 'BRIDGE_TRACE_INCOMPLETE'}
 return $r
}
function Invoke-OwnerProgram($Context,[string]$Operation,[string]$Executable,[string[]]$Argv,[string]$Stage='work',[int]$MaxMs=5000){
 Assert-ExecutionContext $Context -Docker
 $state=Get-NativeContext $Context;if($state.PSObject.Properties['Bridge']){$state.Bridge.methodStage=$Stage}
 Assert-NativeTreeCapability $Context
 $tool=@($Context.Tools.Values|Where-Object path -CEQ $Executable);if($tool.Count -ne 1 -or (Get-FileHash -LiteralPath $Executable).Hash.ToLowerInvariant() -cne $tool[0].sha256){throw 'OWNER_EXECUTABLE_PIN'}
 $limit=[Math]::Min($MaxMs,(Get-RemainingNativeMs $Context $Stage));if($limit -lt 600){throw 'OWNER_PROGRAM_DEADLINE'}
 $r=Invoke-NativeBoundary $Context $Operation $Executable $Argv $limit;Save-NativeReceipts $Context;Assert-NativeSuccess $r
 if($state.PSObject.Properties['Bridge'] -and $state.Bridge.traceFailed -and $Stage -cne 'cleanup'){throw 'BRIDGE_TRACE_INCOMPLETE'}
 return $r
}
function Register-Planned($Context,[string]$Kind,[string]$Name,[string]$Role){
 if($Context.Registry.Count -ge 16 -or $Name -cnotmatch '^wed-source-[a-f0-9]{32}-[a-z-]+$' -or @($Context.Registry|Where-Object Name -CEQ $Name).Count){throw 'RESOURCE_REGISTRY'}
 $state=Get-NativeContext $Context
 $entry=[pscustomobject]@{Kind=$Kind;Name=$Name;Role=$Role;ID=$null;Owner=$Context.Payload.runID};$Context.Registry.Add($entry)
 if($state.PSObject.Properties['Bridge']){
  if($Kind -cnotin @('container','network')){throw 'BRIDGE_RESOURCE_KIND'}
  $image=if($Kind -ceq 'container'){@($Context.Plan.resources.roles|Where-Object role -CEQ $Role)[0].image}else{$null}
  $entry|Add-Member NoteProperty Image $image;$entry|Add-Member NoteProperty PreflightClear $false;$entry|Add-Member NoteProperty RecoveryUsed $false;$entry|Add-Member NoteProperty CreatePending $false
  $state.Bridge.records.Add(@{entry=$entry;identity=($entry.Name+'|'+$entry.Kind+'|'+$entry.Role+'|'+$entry.Owner+'|'+$entry.Image);id=$null})
  $probeArgv=if($Kind -ceq 'container'){@('ps','-aq','--no-trunc','--filter',('name=^/'+$Name+'$'))}else{@('network','ls','-q','--no-trunc','--filter',('name=^'+$Name+'$'))}
  $absence=Invoke-DockerNative $Context 'PLANNED_NAME_ABSENT' $probeArgv 'startup'
  if(![string]::IsNullOrWhiteSpace($absence.RawOut)){throw 'BRIDGE_NAME_COLLISION'}
  $entry.PreflightClear=$true
  Write-ExclusiveJSON (Join-Path $Context.Root ('owner-private/intent-'+$Context.Registry.IndexOf($entry)+'.json')) @{kind=$Kind;name=$Name;role=$Role;image=$image;run=$Context.Payload.runID;task=$script:BridgeTaskMarker}
  $entry.CreatePending=$true;Write-BridgeTrace $Context 'REGISTER_INTENT' 'PLANNED_RESOURCE' @{name=$Name;kind=$Kind}
 }
 return $entry
}
function Get-DockerOne($Result){$rows=@(Read-NativeJSON $Result);if($rows.Count -ne 1){throw 'SINGLE_NATIVE_OBJECT_REQUIRED'};return $rows[0]}
function Assert-ContainerGuard($Context,$Role,$Info,[int]$Networks){
 $h=$Info.HostConfig
 if((Get-NativeContext $Context).PSObject.Properties['Bridge'] -and $h.CgroupnsMode -cne 'private'){throw 'CONTAINER_GUARD'}
 if($Info.Image -cne $Role.image -or $Info.Name -cne ('/wed-source-'+$Context.Payload.runID+'-'+$Role.role)){throw 'CONTAINER_IDENTITY'}
 if($Info.Config.Labels.'com.wed-snap.run' -cne $Context.Payload.runID -or $Info.Config.User -cne $Role.user -or $h.ReadonlyRootfs -ne $true -or $h.Privileged -ne $false -or @($h.CapAdd).Where({$_}).Count -or $h.CapDrop -cnotcontains 'ALL' -or $h.SecurityOpt -cnotcontains 'no-new-privileges:true' -or $h.IpcMode -cne 'private' -or $h.Memory -ne $Role.memoryMiB*1MB -or $h.MemorySwap -ne $h.Memory -or $h.PidsLimit -ne $Role.pids -or $h.NanoCpus -ne [long]($Role.cpu*1e9) -or @($Info.NetworkSettings.Networks.PSObject.Properties).Count -ne $Networks){throw 'CONTAINER_GUARD'}
 $ports=@($h.PortBindings.PSObject.Properties)
 if($Role.role -ceq 'gateway'){if($ports.Count -ne 1 -or $ports[0].Value[0].HostIp -cne '127.0.0.1' -or $ports[0].Value[0].HostPort -cne '5206'){throw 'GATEWAY_PORT'}}elseif($ports.Count){throw 'PRIVATE_PORT'}
 $expected=@($Context.Plan.mounts)+@($Context.Plan.supervisorMirrors)+@($Context.Plan.controlMounts)
 foreach($m in $expected|Where-Object{$_.roles -contains $Role.role}){$found=@($Info.Mounts|Where-Object Destination -CEQ $m.target);if($found.Count -ne 1){throw 'MOUNT_GUARD'};Assert-PlannedMount $Context $m $found[0]}
 $allowed=@($expected|Where-Object{$_.roles -contains $Role.role}|ForEach-Object target)
 foreach($m in $Info.Mounts){if($m.Type -ceq 'bind' -and $m.Destination -cnotin $allowed){throw 'UNPLANNED_BIND_MOUNT'}}
 if(@($Info.Config.Env|Where-Object{$_ -clike 'STEP5_OFFLINE*' -or $_ -clike 'NODE_TLS_REJECT_UNAUTHORIZED=*' -or $_ -clike 'REQUESTS_CA_BUNDLE=*'}).Count){throw 'FIXTURE_ENV_FORBIDDEN'}
 $names=@($Info.NetworkSettings.Networks.PSObject.Properties.Name|Sort-Object)
 $expectedNames=@($(if($Networks -eq 1){'internal'}else{$Role.networks})|ForEach-Object{'wed-source-'+$Context.Payload.runID+'-'+$_}|Sort-Object)
 if(($names -join '|') -cne ($expectedNames -join '|')){throw 'OWN_NETWORK_MEMBERSHIP'}
}
function Get-ContainerOutcome($Info){
 if($null -eq $Info.State.ExitCode -or $Info.State.ExitCode -isnot [int] -and $Info.State.ExitCode -isnot [long] -or $Info.State.OOMKilled -isnot [bool] -or $Info.State.Running -isnot [bool]){throw 'MISSING_CONTAINER_NATIVE_STATE'}
 @{actualExit=[int]$Info.State.ExitCode;actualSignal=$(if(!$Info.State.Running -and $Info.State.ExitCode -eq 0){$null}else{'UNKNOWN'});signalEvidence='DOCKER_STATE_HAS_NO_SEPARATE_SIGNAL_FIELD';oomKilled=$Info.State.OOMKilled;running=$Info.State.Running;observed=$true}
}
function Assert-OwnerPrivateProof($Context,[string]$Path,[string]$SHA){
 $expected=[IO.Path]::GetFullPath((Join-Path $Context.Root 'owner-private/native-exits.json'))
 $actual=[IO.Path]::GetFullPath($Path)
 if($actual -cne $expected -or $actual.StartsWith([IO.Path]::GetFullPath($Context.Control)+[IO.Path]::DirectorySeparatorChar)){throw 'OWNER_PROOF_LOCATION'}
 $ref=[IO.Path]::GetRelativePath((Get-Location).Path,$actual)
 if((Resolve-WorkspaceFile $ref) -cne $actual -or (Read-LimitedJSON $actual 16384).SHA -cne $SHA){throw 'OWNER_PROOF_CHANGED'}
}
function Close-RegistryCore($Context,$Inspect,$Remove,$Absent){
 $ok=$true;$rows=[Collections.Generic.List[object]]::new()
 foreach($kind in @('container','network')){
  $entries=@($Context.Registry|Where-Object Kind -CEQ $kind);[array]::Reverse($entries)
  foreach($r in $entries){
   try{$seen=&$Inspect $r;if($seen.Owner -cne $r.Owner -or !$seen.ID -or ($r.ID -and $seen.ID -cne $r.ID)){throw 'OWNER_MISMATCH'};&$Remove $r $seen;$rows.Add(@{name=$r.Name;kind=$kind;id=$seen.ID;closed=$true})}
   catch{$ok=$false;$rows.Add(@{name=$r.Name;kind=$kind;closed='UNKNOWN'})}
  }
 }
 try{$left=&$Absent;if($left.Containers -ne '' -or $left.Networks -ne ''){$ok=$false}}catch{$ok=$false;$left=@{Containers='UNKNOWN';Networks='UNKNOWN'}}
 $nativeClosed=Test-NativeContextClosed $Context;if(!$nativeClosed){$ok=$false}
 [pscustomobject]@{closed=$ok;resources=$rows.ToArray();absence=$left;nativeTrees=$(if($nativeClosed){'CLOSED_ALL_REGISTERED'}else{'UNKNOWN'})}
}
function Test-OwnedRegistryCleanup($Context,$Inspect,$Remove,$Absent){
 if($Context.Mode -cne 'OFFLINE_TEST_ONLY' -or ![object]::ReferenceEquals($Context.Seal,$script:OfflineSeal)){throw 'OFFLINE_ONLY'}
 Close-RegistryCore $Context $Inspect $Remove $Absent
}
function Close-SourceRegistry($Context){
 $Context.CleanupCallsLeft=3*$Context.Registry.Count+2
 $state=Get-NativeContext $Context;$bridge=[bool]$state.PSObject.Properties['Bridge']
 $inspect={param($r)
  if($bridge -and !$r.ID){if(!$r.PreflightClear -or $r.RecoveryUsed){throw 'BRIDGE_RECOVERY_UNPROVEN'};$r.RecoveryUsed=$true}
  $ref=if($bridge -and $r.ID){$r.ID}else{$r.Name}
  $dockerArgs=if($r.Kind -ceq 'container'){@('inspect',$ref)}else{@('network','inspect',$ref)}
  $g=Get-DockerOne (Invoke-DockerNative $Context 'CLEANUP_INSPECT' $dockerArgs 'cleanup' 2000)
  if($bridge){Assert-BridgeResource $Context $r $g;if(!$r.ID){$r.ID=$g.Id;Set-BridgeRegistryID $Context $r}}
  $owner=if($r.Kind -ceq 'container'){$g.Config.Labels.'com.wed-snap.run'}else{$g.Labels.'com.wed-snap.run'};[pscustomobject]@{Owner=$owner;ID=$g.Id}
 }
 $remove={param($r,$g)
  $dockerArgs=if($r.Kind -ceq 'container'){@('rm','-f',$g.ID)}else{@('network','rm',$g.ID)};Invoke-DockerNative $Context 'REMOVE_OWN_RESOURCE' $dockerArgs 'cleanup' 2000|Out-Null
  if($bridge){$probe=if($r.Kind -ceq 'container'){@('ps','-aq','--no-trunc','--filter',('id='+$g.ID))}else{@('network','ls','-q','--no-trunc','--filter',('id='+$g.ID))};$out=Invoke-DockerNative $Context 'REMOVED_ID_ABSENT' $probe 'cleanup' 2000;if(![string]::IsNullOrWhiteSpace($out.RawOut)){throw 'BRIDGE_REMOVED_ID_STILL_PRESENT'}}
 }
 $absent={@{Containers=(Invoke-DockerNative $Context 'OWN_CONTAINERS_ABSENT' @('ps','-aq','--filter',"label=com.wed-snap.run=$($Context.Payload.runID)") 'cleanup' 2000).RawOut.Trim();Networks=(Invoke-DockerNative $Context 'OWN_NETWORKS_ABSENT' @('network','ls','-q','--filter',"label=com.wed-snap.run=$($Context.Payload.runID)") 'cleanup' 2000).RawOut.Trim()}}
 $receipt=Close-RegistryCore $Context $inspect $remove $absent
 # Synchronous adapter already terminated by OWN job and released its handles.
 # Unknown/disposed records remain private proof failures; never kill a PID or
 # promote closure merely because the job handle was closed.
 if(!(Test-NativeContextClosed $Context)){$receipt.closed=$false;$receipt.nativeTrees='UNKNOWN'}
 return $receipt
}
function Expand-OwnerArg([string]$Value,$Tokens){
 foreach($key in $Tokens.Keys){$Value=$Value.Replace('<'+$key+'>',[string]$Tokens[$key])}
 if($Value -cmatch '<[A-Z_a-z]'){throw 'UNBOUND_NATIVE_TOKEN'};return $Value
}
function Write-SourceRuntimeContract($Context,[string]$Python){
 $freq=[Diagnostics.Stopwatch]::Frequency;$now=[Diagnostics.Stopwatch]::GetTimestamp()
 $Context.WorkDeadline=[Math]::Min($Context.WorkDeadline,$now+[long](280*$freq));if($Context.ProxyStarted){$Context.WorkDeadline=[Math]::Min($Context.WorkDeadline,$Context.ProxyStarted+[long](320*$freq))}
 $Context.CleanupDeadline=$Context.WorkDeadline+[long](20*$freq);$Context.HardDeadline=$Context.CleanupDeadline+[long]$freq
 if((Get-RemainingNativeMs $Context 'work') -lt 279000){throw 'INSUFFICIENT_APP_BOOTSTRAP_AND_WORKFLOW'}
 $probe=Read-NativeJSON (Invoke-OwnerProgram $Context 'HOST_CLOCK_PROBE' $Python @('-I','-B',(Join-Path $PSScriptRoot 'protocol.py'),'clock') 'startup')
 $nsNow=[decimal][Diagnostics.Stopwatch]::GetTimestamp()*1000000000/[decimal]$freq
 if([decimal]$probe.monotonicNS -gt $nsNow+10000000 -or $nsNow-[decimal]$probe.monotonicNS -gt 5000000000){throw 'HOST_MONOTONIC_DOMAIN_UNKNOWN'}
 $ns={param($t)[string][decimal]::Floor([decimal]$t*1000000000/[decimal]$freq)}
 $utcEnd=$Context.UtcStart.AddSeconds(($Context.HardDeadline-$Context.StartTicks)/[double]$freq)
 $b=(Read-LimitedJSON (Join-Path $PSScriptRoot '../ui-source-glue/budget-policy.json')).Value;$target=$Context.Payload.target
 $decision=[ordered]@{schema='wed-ui-photo-source-decision-v1';mode='UI_SINGLE_PHOTO_SOURCE';state='APPROVED_NEW';runID=$Context.Payload.runID;approvedURL=$target.canonicalURL;expectedPostID=$target.expectedPostID;selectedIndex=[int]$target.selectedIndex;budgetSHA256='';expiresAt=$utcEnd.ToString('o')}
 $budgetRaw=$b|ConvertTo-Json -Depth 10 -Compress;$decision.budgetSHA256=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($budgetRaw))).ToLowerInvariant()
 $decisionRaw=$decision|ConvertTo-Json -Depth 10 -Compress
 $c=[ordered]@{schema='wed-ui-photo-source-contract-v1';mode='UI_SINGLE_PHOTO_SOURCE';runID=$Context.Payload.runID;origin='http://127.0.0.1:5206';path='/';approvedURL=$target.canonicalURL;expectedPostID=$target.expectedPostID;selectedIndex=[int]$target.selectedIndex;decisionSHA256=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($decisionRaw))).ToLowerInvariant();budgetSHA256=$decision.budgetSHA256;startMonoNs=(&$ns $Context.StartTicks);observationDeadlineMonoNs=(&$ns $Context.WorkDeadline);cleanupDeadlineMonoNs=(&$ns $Context.CleanupDeadline);runDeadlineMonoNs=(&$ns $Context.HardDeadline)}
 $bundle=Join-Path $Context.Root 'owner-private/runtime-bundle.json';Write-ExclusiveJSON $bundle @{contract=$c;decision=$decision;budget=$b}
 Invoke-OwnerProgram $Context 'INSTALL_RUNTIME_CONFIG' $Python @('-I','-B',(Join-Path $PSScriptRoot 'protocol.py'),'install','--root',$Context.Control,'--bundle',$bundle) 'startup'|Out-Null
 $Context|Add-Member NoteProperty Contract $c
 $state=Get-NativeContext $Context;if($state.PSObject.Properties['Bridge']){$state.Bridge.contractJSON=($c|ConvertTo-Json -Compress)}
}
function Wait-OwnerFile($Context,[string]$Name,[string]$Stage='work',[int]$ReserveMs=0){
 $path=Join-Path $Context.Control $Name
 while(!(Test-Path -LiteralPath $path)){if((Get-RemainingNativeMs $Context $Stage) -lt 600+$ReserveMs){throw 'OWNER_FILE_DEADLINE'};$s=Get-NativeContext $Context;if($s.PSObject.Properties['Bridge'] -and $Context.PSObject.Properties['Contract']){Service-OwnerWindowRequest $Context};Start-Sleep -Milliseconds 100}
 if($ReserveMs -and (Get-RemainingNativeMs $Context $Stage) -lt $ReserveMs){throw 'OWNER_FILE_DEADLINE'}
 return $path
}
function Invoke-SourceOwner([string]$ApprovalPath,$Context=$null){
 $ctx=if($null -ne $Context){Assert-ExecutionContext $Context -Docker;$state=Get-NativeContext $Context;if(!$state.PSObject.Properties['Bridge']){throw 'BRIDGE_REGISTERED_CONTEXT_REQUIRED'};$Context}else{Read-SourceApproval $ApprovalPath}
 Assert-ExecutionContext $ctx -Docker
 if($ctx.Mode -ceq 'MANAGED_ADAPTER_TEST'){return Invoke-ManagedOwnerCoordinator $ctx}
 # Approval/context remain mandatory; helper is prepared below in owned root.
 . (Join-Path $PSScriptRoot '../ui-source-prelaunch/wiring.ps1');$plan=Get-PrelaunchPlan
 foreach($pin in $plan.pins){$match=@($ctx.Pins|Where-Object path -CEQ $pin.path);if($match.Count -ne 1 -or $match[0].sha256 -cne $pin.sha256){throw 'APPROVED_PLAN_PIN_COVERAGE'}}
 $ctx|Add-Member NoteProperty Plan $plan
 $root=Resolve-WorkspaceFile $ctx.Payload.evidenceRef
 if(!$root.StartsWith([IO.Path]::GetFullPath((Join-Path (Get-Location).Path 'docs/evidence'))+[IO.Path]::DirectorySeparatorChar) -or (Test-Path -LiteralPath $root)){throw 'OWN_EVIDENCE_REUSE'}
 New-Item -ItemType Directory -Path (Join-Path $root 'owner-private') -ErrorAction Stop|Out-Null;New-Item -ItemType Directory -Path (Join-Path $root 'control')|Out-Null
 $ctx.Root=$root;$ctx|Add-Member NoteProperty Control (Join-Path $root 'control')
 $bridgeState=Get-NativeContext $ctx;if($bridgeState.PSObject.Properties['Bridge']){Write-ExclusiveJSON (Join-Path $root 'owner-private/authority-public.json') $bridgeState.Bridge.publicIdentity}
 $success=$false;$cleanup=$null;$python=$ctx.Tools.python.path;$run=$ctx.Payload.runID;$tokens=@{OWN_RUN=$run;OWN_CONTROL=$ctx.Control}
 try{
  foreach($image in @($plan.resources.roles.image|Sort-Object -Unique)){$r=Invoke-DockerNative $ctx 'CACHE_IMAGE_ID' @('image','inspect',$image,'--format','{{.Id}}') 'startup';if($r.RawOut.Trim() -cne $image){throw 'CACHE_ID_MISMATCH'}}
  foreach($kind in @('internal','ingress','source-egress')){
   $name="wed-source-$run-$kind";$entry=Register-Planned $ctx 'network' $name $kind
   $dockerArgs=@('network','create','--label',"com.wed-snap.run=$run");if($kind -ceq 'internal'){$dockerArgs+=@('--internal')}else{$dockerArgs+=@('--driver','bridge')};$dockerArgs+=,$name
   $r=Invoke-DockerNative $ctx 'CREATE_OWN_NETWORK' $dockerArgs 'startup';$entry.ID=$r.RawOut.Trim();$tokens['OWN_'+$kind.ToUpperInvariant().Replace('-','_')]=$name
  }
  $internal=Get-DockerOne (Invoke-DockerNative $ctx 'INSPECT_INTERNAL_NETWORK' @('network','inspect',$tokens.OWN_INTERNAL) 'startup');if($internal.Internal -ne $true -or $internal.Labels.'com.wed-snap.run' -cne $run){throw 'INTERNAL_NETWORK'}
  $secret=[Convert]::ToHexString([Security.Cryptography.RandomNumberGenerator]::GetBytes(32)).ToLowerInvariant();$admin=[Convert]::ToHexString([Security.Cryptography.RandomNumberGenerator]::GetBytes(32)).ToLowerInvariant();$dbpw=[Convert]::ToHexString([Security.Cryptography.RandomNumberGenerator]::GetBytes(16)).ToLowerInvariant()
  $tokens.EXACT_INTERNAL_CIDR=$internal.IPAM.Config[0].Subnet;$tokens.RAM_SECRET=$admin;$tokens.PARENT_PROXY_ONLY_SECRET=$secret;$tokens.OWN_LAB_PASSWORD=$dbpw;$tokens.OWN_LAB_DATABASE="postgresql://gate_fixture:$dbpw@postgres:5432/step5_executor";$tokens.OWN_LAB_REDIS='redis://redis:6379/7'
  foreach($role in @('postgres','redis','proxy')){
   $spec=@($plan.resources.roles|Where-Object role -CEQ $role)[0];$name="wed-source-$run-$role";$tokens['OWN_'+$role]=$name;$entry=Register-Planned $ctx 'container' $name $role
   $dockerArgs=@($plan.createArgvTemplates.$role|ForEach-Object{Expand-OwnerArg $_ $tokens});$entry.ID=(Invoke-DockerNative $ctx 'CREATE_PRIVATE_SERVICE' $dockerArgs 'startup').RawOut.Trim()
   $g=Get-DockerOne (Invoke-DockerNative $ctx 'GUARD_PRIVATE_SERVICE' @('inspect',$name) 'startup');Assert-ContainerGuard $ctx $spec $g 1
   Invoke-DockerNative $ctx 'START_PRIVATE_SERVICE' @('start',$name) 'startup'|Out-Null
   if($role -ceq 'proxy'){$ctx.ProxyStarted=[Diagnostics.Stopwatch]::GetTimestamp()}
  }
  Wait-OwnerFile $ctx 'ready' 'startup'|Out-Null
  Write-SourceRuntimeContract $ctx $python
  Write-ExclusiveJSON (Join-Path $ctx.Control 'expected-source.json') $plan.expectedSourceProjection
  $role='app';$tokens.OWN_app="wed-source-$run-app";$entry=Register-Planned $ctx 'container' $tokens.OWN_app $role
  $entry.ID=(Invoke-DockerNative $ctx 'CREATE_SOURCE_APP' @($plan.createArgvTemplates.app|ForEach-Object{Expand-OwnerArg $_ $tokens}) 'startup').RawOut.Trim()
  $g=Get-DockerOne (Invoke-DockerNative $ctx 'GUARD_SOURCE_APP' @('inspect',$tokens.OWN_app) 'startup');Assert-ContainerGuard $ctx (@($plan.resources.roles|Where-Object role -CEQ 'app')[0]) $g 1
  Invoke-DockerNative $ctx 'START_SOURCE_APP' @('start',$tokens.OWN_app) 'startup'|Out-Null
  Wait-OwnerFile $ctx 'backend.ready' 'work' 260000|Out-Null
  if((Get-RemainingNativeMs $ctx 'work') -lt 260000){throw 'INSUFFICIENT_BROWSER_SOURCE_FINAL_BUDGET'}
  $g=Get-DockerOne (Invoke-DockerNative $ctx 'FIXED_API_ADDRESS' @('inspect',$tokens.OWN_app) 'work');$route=@($g.NetworkSettings.Networks.PSObject.Properties|Where-Object Name -CEQ $tokens.OWN_INTERNAL)
  $parsedAddress=[Net.IPAddress]::None
  if($route.Count -ne 1 -or ![Net.IPAddress]::TryParse([string]$route[0].Value.IPAddress,[ref]$parsedAddress) -or $parsedAddress.AddressFamily -ne [Net.Sockets.AddressFamily]::InterNetwork){throw 'NUMERIC_API_IP'};$tokens.INSPECTED_NUMERIC_INTERNAL_IP=$route[0].Value.IPAddress
  Assert-CurrentPins $ctx.Pins
  Invoke-DockerNative $ctx 'OPEN_APPROVED_OWN_EGRESS' @('network','connect',$tokens.OWN_SOURCE_EGRESS,$tokens.OWN_proxy) 'work'|Out-Null
  $proxy=Get-DockerOne (Invoke-DockerNative $ctx 'GUARD_EGRESS_PROXY' @('inspect',$tokens.OWN_proxy) 'work');Assert-ContainerGuard $ctx (@($plan.resources.roles|Where-Object role -CEQ 'proxy')[0]) $proxy 2
  $tokens.OWN_gateway="wed-source-$run-gateway";$entry=Register-Planned $ctx 'container' $tokens.OWN_gateway 'gateway'
  $entry.ID=(Invoke-DockerNative $ctx 'CREATE_SOURCE_GATEWAY' @($plan.createArgvTemplates.gateway|ForEach-Object{Expand-OwnerArg $_ $tokens}) 'work').RawOut.Trim()
  Invoke-DockerNative $ctx 'CONNECT_GATEWAY_INTERNAL' @('network','connect',$tokens.OWN_INTERNAL,$tokens.OWN_gateway) 'work'|Out-Null
  $g=Get-DockerOne (Invoke-DockerNative $ctx 'GUARD_SOURCE_GATEWAY' @('inspect',$tokens.OWN_gateway) 'work');Assert-ContainerGuard $ctx (@($plan.resources.roles|Where-Object role -CEQ 'gateway')[0]) $g 2
  Invoke-DockerNative $ctx 'START_SOURCE_GATEWAY' @('start',$tokens.OWN_gateway) 'work'|Out-Null;Wait-OwnerFile $ctx 'browser.ready'|Out-Null
  $handler=[Net.Http.HttpClientHandler]::new();$handler.UseProxy=$false;$client=[Net.Http.HttpClient]::new($handler);$client.Timeout=[TimeSpan]::FromMilliseconds([Math]::Min(5000,(Get-RemainingNativeMs $ctx)))
  try{$r=$client.GetAsync('http://127.0.0.1:5206/api/v1/health').GetAwaiter().GetResult();if([int]$r.StatusCode -ne 200){throw 'HOST_HEALTH'};$r.Dispose()}finally{$client.Dispose()}
  $binding=[ordered]@{};foreach($k in @('mode','runID','origin','path','expectedPostID','selectedIndex','decisionSHA256','budgetSHA256','observationDeadlineMonoNs')){$binding[$k]=$ctx.Contract[$k]}
  Write-ExclusiveJSON (Join-Path $ctx.Control 'host-ready.json') $binding
  $sidecar=if((Get-NativeContext $ctx).PSObject.Properties['Bridge']){New-OwnerWindowSample $ctx}else{$null}
  Write-ExclusiveJSON (Join-Path $ctx.Root 'owner-private/browser-handoff.json') @{binding=$binding;root=$ctx.Control;publisher=@($python,'-I','-B',(Resolve-Path 'labs/tiktok/ui-source-prelaunch/publisher.py').Path,'--root',$ctx.Control,'--input','<OWNER_OBSERVATION_INPUT>');workflowOwner='FRONTEND_BROWSER_ONLY';remainingMs=(Get-RemainingNativeMs $ctx);window=$sidecar}
  Write-Output 'SOURCE_BROWSER_READY_OWNER_CONTROLLED_HANDOFF'
  Wait-OwnerFile $ctx 'browser-observation.json' 'work' 10000|Out-Null
  $decision=Read-NativeJSON (Invoke-OwnerProgram $ctx 'OWNER_OBSERVATION_DECISION' $python @('-I','-B',(Join-Path $PSScriptRoot 'protocol.py'),'wait','--root',$ctx.Control));if($decision.status -cne 'ACCEPTED'){throw 'BROWSER_NOT_ACCEPTED'}
  [IO.File]::WriteAllText((Join-Path $ctx.Control 'browser-accepted'),'accepted')
  Wait-OwnerFile $ctx 'result.json'|Out-Null
  $nativeProof=[ordered]@{mode='OWNER_NATIVE_PROOF';binding=$binding}
  foreach($role in @('gateway','app','proxy')){
   if($role -ceq 'proxy'){[IO.File]::WriteAllText((Join-Path $ctx.Control 'stop'),'stop')}
   $name=$tokens['OWN_'+$role];$wait=$null;$outcome=@{actualExit=$null;actualSignal='UNKNOWN';oomKilled='UNKNOWN';running='UNKNOWN';observed=$false}
   try{$wait=Invoke-DockerNative $ctx 'WAIT_NATIVE_CONTAINER' @('wait',$name)}catch{}
   try{$g=Get-DockerOne (Invoke-DockerNative $ctx 'OBSERVE_NATIVE_CONTAINER_EXIT' @('inspect',$name));$outcome=Get-ContainerOutcome $g}catch{}
   Write-ExclusiveJSON (Join-Path $ctx.Root ('owner-private/container-'+$role+'.json')) $outcome
   if(!$wait -or $wait.RawOut.Trim() -cne '0' -or !$outcome.observed -or $outcome.running -ne $false -or $outcome.actualExit -ne 0 -or $outcome.oomKilled -ne $false){throw 'CONTAINER_EXIT_OR_OOM_OR_UNKNOWN'}
   $nativeProof[$role]=$outcome
  }
  $proofPath=Join-Path $ctx.Root 'owner-private/native-exits.json';Write-ExclusiveJSON $proofPath $nativeProof
  $proofSHA=(Get-FileHash -LiteralPath $proofPath).Hash.ToLowerInvariant();Assert-OwnerPrivateProof $ctx $proofPath $proofSHA
  Invoke-OwnerProgram $ctx 'SOURCE_FINAL_NATIVE_GATE' $ctx.Tools.node.path @('--max-old-space-size=64',(Resolve-Path 'labs/tiktok/ui-source-prelaunch/final-gate.cjs').Path,$ctx.Control,$proofPath) 'work' 10000|Out-Null
  Assert-OwnerPrivateProof $ctx $proofPath $proofSHA;Assert-CurrentPins $ctx.Pins;$success=$true
 }catch{Write-ExclusiveJSON (Join-Path $ctx.Root 'owner-private/failure.json') @{status='FAIL_STOPPED';code='NATIVE_OWNER_STAGE_FAILED';sourceStageStatus='NOT_ACCEPTED'}}
 finally{
  if(!$success){foreach($name in @('browser-abort','stop')){$p=Join-Path $ctx.Control $name;if(!(Test-Path -LiteralPath $p)){[IO.File]::WriteAllText($p,'OWNER_STOP')}}}
  $ctx.CleanupDeadline=[Math]::Min($ctx.CleanupDeadline,[Diagnostics.Stopwatch]::GetTimestamp()+[long](20*[Diagnostics.Stopwatch]::Frequency))
  $cleanup=Close-SourceRegistry $ctx;Write-ExclusiveJSON (Join-Path $ctx.Root 'owner-private/cleanup.json') $cleanup
  try{Invoke-OwnerProgram $ctx 'OWNER_FINAL_COMPLETION' $python @('-I','-B',(Join-Path $PSScriptRoot 'protocol.py'),'complete','--root',$ctx.Control,'--cleanup',$(if($cleanup.closed){'CLOSED'}else{'UNKNOWN'}),'--execution',$(if($success){'PASS'}else{'FAIL'})) 'seal' 1000|Out-Null}catch{$success=$false}
  Save-NativeReceipts $ctx
 }
 if(!$success -or !$cleanup.closed){throw 'OWNER_FAILED_OR_CLEANUP_UNKNOWN'}
 return [pscustomobject]@{status='PASS_OWNER_NATIVE_SOURCE';root=$ctx.Root;completion='SOURCE_HANDSHAKE_NATIVE_ZERO_AND_CLEANUP_CLOSED'}
}
