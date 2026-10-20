function Bridge-DockerArgs($Context,[string[]]$Argv){
 $s=Get-NativeContext $Context;if(!$s.PSObject.Properties['Bridge']){return ,$Argv}
 foreach($k in @('DOCKER_HOST','DOCKER_CONTEXT','DOCKER_CONFIG','DOCKER_TLS_VERIFY','DOCKER_CERT_PATH','DOCKER_CUSTOM_HEADERS','DOCKER_API_VERSION','DOCKER_DEFAULT_PLATFORM')){if([Environment]::GetEnvironmentVariable($k)){throw 'OVERRIDE_PRESENT'}}
 if(!$Argv.Count -or $Argv[0] -cnotin @('image','network','inspect','ps','start','wait','rm','create')){throw 'BRIDGE_ENDPOINT_OVERRIDE'}
 $dockerPart=@($Argv)
 if($Argv[0] -ceq 'create'){
  # Only the create flags used by the frozen lab recipe, with their official
  # v29.8.1 arity. This is not a general Docker CLI parser. Never inspect the
  # container command after the immutable image (postgres -c is payload).
  $valueFlags=@('--pull','--label','--name','--network','--network-alias','--ipc','--cgroupns','--user','--memory','--memory-swap','--cpus','--pids-limit','--cap-drop','--security-opt','--restart','--mount','--tmpfs','--entrypoint','--platform','-e','--env','-p','--publish')
  $images=@('sha256:d4558b29dd379b16d4906fb9e618dfc4d045e3008a70e031ea3474b7b2218e4e','sha256:8bc0a567955111ea3cfbab2dd3b14f40a602f2d10ac987e78eb465f9d48d7f10','sha256:38471f330eb885e04de130b768d6db4e10469e2311879c7e5c699f6d2d8a1c74','sha256:a9cc41d6d01da2aa26c219e4f99ecbeead955a7b656c1c499cce8922311b2514')
  $i=1
  while($i -lt $Argv.Count -and $Argv[$i] -cnotin $images){
   $flag=$Argv[$i].Split('=',2)[0]
   if($flag -ceq '--read-only'){$i++;continue}
   if($flag -cnotin $valueFlags){throw 'BRIDGE_ENDPOINT_OVERRIDE'}
   if($Argv[$i].Contains('=')){$i++}else{if($i+1 -ge $Argv.Count){throw 'BRIDGE_CREATE_ARGUMENT_SHAPE'};$i+=2}
  }
  if($i -ge $Argv.Count){throw 'BRIDGE_CREATE_IMAGE_NOT_PINNED'}
  $dockerPart=@($Argv[0..($i-1)])
 }
 if(@($dockerPart|Where-Object{$_ -cmatch '^--(?:host|context|config|tls(?:verify|cacert|cert|key)?)(?:=|$)|^-(?:H|c)(?:=|[^-]|$)'}).Count){throw 'BRIDGE_ENDPOINT_OVERRIDE'}
 $out=@($Argv)
 if($Argv[0] -ceq 'create'){$out=@('create','--label',('com.wed-snap.task='+$script:BridgeTaskMarker))+$Argv[1..($Argv.Count-1)]}
 if($Argv.Count -gt 1 -and $Argv[0] -ceq 'network' -and $Argv[1] -ceq 'create'){$out=@('network','create','--label',('com.wed-snap.task='+$script:BridgeTaskMarker))+$Argv[2..($Argv.Count-1)]}
 return ,(@('--host','npipe:////./pipe/dockerDesktopLinuxEngine')+$out)
}
function Assert-BridgeCleanupMounts($Context,$Info){
 if(!$Info.PSObject.Properties['Mounts'] -or $Info.Mounts -isnot [array]){throw 'BRIDGE_UNKNOWN_VOLUME'}
 foreach($m in $Info.Mounts){
  if($m.Type -ceq 'tmpfs'){continue}
  if($m.Type -cne 'bind' -or $m.RW -isnot [bool]){throw 'BRIDGE_UNKNOWN_VOLUME'}
  if(!$m.RW){continue} # Removing a container does not delete readonly bind data.
  if(!$Context.Control){throw 'BRIDGE_WRITABLE_BIND_UNPROVEN'}
  $expected=Get-CanonicalMountHost $Context.Control
  Assert-NoPrivateMountSource $Context $expected
  Assert-ObservedMountSource $Context $expected ([string]$m.Source)
 }
}
function Assert-BridgeResource($Context,$Record,$Info){
 if($Info.Id -cnotmatch '^[a-f0-9]{64}$' -or ($Record.ID -and $Info.Id -cne $Record.ID)){throw 'BRIDGE_OWNER_MISMATCH'}
 $labels=if($Record.Kind -ceq 'container'){$Info.Config.Labels}else{$Info.Labels}
 $name=if($Record.Kind -ceq 'container'){'/'+$Record.Name}else{$Record.Name}
 if($Info.Name -cne $name -or $labels.'com.wed-snap.run' -cne $Context.Payload.runID -or $labels.'com.wed-snap.task' -cne $script:BridgeTaskMarker){throw 'BRIDGE_OWNER_MISMATCH'}
 if($Record.Kind -ceq 'container'){
  if($Info.Image -cne $Record.Image){throw 'BRIDGE_OWNER_MISMATCH'}
  Assert-BridgeCleanupMounts $Context $Info
 }elseif($Info.Driver -cne 'bridge' -or $Info.Internal -ne ($Record.Role -ceq 'internal')){throw 'BRIDGE_NETWORK_PROVENANCE'}
}
function Window-Keys($Object,[string[]]$Keys){
 if($null -eq $Object -or (@($Object.PSObject.Properties.Name|Sort-Object) -join '|') -cne (@($Keys|Sort-Object) -join '|')){throw 'BRIDGE_WINDOW_SCHEMA'}
}
function Window-Long($Value){
 $n=[long]0
 if($Value -isnot [string] -or $Value -cnotmatch '^[0-9]{1,19}$' -or ![long]::TryParse($Value,[Globalization.NumberStyles]::None,[Globalization.CultureInfo]::InvariantCulture,[ref]$n)){throw 'BRIDGE_WINDOW_NUMERIC'}
 return $n
}
function Window-Ns([long]$Ticks,[long]$Frequency){[string][decimal]::Floor([decimal]$Ticks*1000000000/$Frequency)}
function Window-Paths([string]$Control,[string]$Mode,[string]$Run){
 if($Run -cnotmatch '^[a-f0-9]{32}$'){throw 'BRIDGE_WINDOW_ROOT'}
 $root=Resolve-WorkspaceFile ([IO.Path]::GetRelativePath((Get-Location).Path,[IO.Path]::GetFullPath($Control)))
 $prefixes=if($Mode -ceq 'UI_SINGLE_PHOTO_SOURCE'){@('docs/evidence/ui-source-live-attempt-20261019/backend/source-')}elseif($Mode -ceq 'MANAGED_ADAPTER_TEST'){@('docs/evidence/ui-source-live-adapter-fix-20261019/backend/unit/runtime-','docs/evidence/ui-source-adapter-final-gaps-20261020/backend/unit/runtime-')}else{throw 'BRIDGE_WINDOW_ROOT'}
 $expected=@($prefixes|ForEach-Object{[IO.Path]::GetFullPath((Join-Path (Get-Location).Path ($_+$Run+'/control')))}|Where-Object{$_ -ceq $root})
 if($expected.Count -ne 1){throw 'BRIDGE_WINDOW_ROOT'}
 $runRoot=[IO.Path]::GetDirectoryName($root)
 $proof=Resolve-WorkspaceFile ([IO.Path]::GetRelativePath((Get-Location).Path,(Join-Path $runRoot 'owner-private/window-response-proof.json')))
 return @{root=$root;runRoot=$runRoot;proof=$proof;response=(Join-Path $root 'window-response.json');contract=(Join-Path $root 'browser-contract.json');observation=(Join-Path $root 'browser-observation.json');abort=(Join-Path $root 'browser-abort')}
}
function Window-Contract($C){
 Window-Keys $C @('schema','mode','runID','origin','path','approvedURL','expectedPostID','selectedIndex','decisionSHA256','budgetSHA256','startMonoNs','observationDeadlineMonoNs','cleanupDeadlineMonoNs','runDeadlineMonoNs')
 foreach($key in @('schema','mode','runID','origin','path','approvedURL','expectedPostID','decisionSHA256','budgetSHA256','startMonoNs','observationDeadlineMonoNs','cleanupDeadlineMonoNs','runDeadlineMonoNs')){if($C.$key -isnot [string]){throw 'BRIDGE_WINDOW_CONTRACT'}}
 if($C.schema -cne 'wed-ui-photo-source-contract-v1' -or $C.origin -cne 'http://127.0.0.1:5206' -or $C.path -cne '/' -or $C.approvedURL -cne 'https://www.tiktok.com/@adne_la.veil/photo/7678209751167110421' -or $C.expectedPostID -cne '7678209751167110421' -or ($C.selectedIndex -isnot [int] -and $C.selectedIndex -isnot [long]) -or $C.selectedIndex -ne 2 -or $C.decisionSHA256 -cnotmatch '^[a-f0-9]{64}$' -or $C.budgetSHA256 -cnotmatch '^[a-f0-9]{64}$'){throw 'BRIDGE_WINDOW_CONTRACT'}
 foreach($key in @('startMonoNs','observationDeadlineMonoNs','cleanupDeadlineMonoNs','runDeadlineMonoNs')){$null=Window-Long $C.$key}
}
function Window-Binding($Binding,$C){
 $keys=@('mode','runID','origin','path','expectedPostID','selectedIndex','decisionSHA256','budgetSHA256','observationDeadlineMonoNs');Window-Keys $Binding $keys
 foreach($key in $keys){if($key -ceq 'selectedIndex'){if(($Binding.$key -isnot [int] -and $Binding.$key -isnot [long]) -or $Binding.$key -ne $C.$key){throw 'BRIDGE_WINDOW_BINDING'}}elseif($Binding.$key -isnot [string] -or $Binding.$key -cne $C.$key){throw 'BRIDGE_WINDOW_BINDING'}}
}
function Window-Write([string]$Path,$Value){
 # Existing JSON conversion and exact-byte atomic nooverwrite writer. Hash the
 # owned bytes, never a reread of a container-writable public response.
 $bytes=[Text.Encoding]::UTF8.GetBytes(($Value|ConvertTo-Json -Depth 24 -Compress))
 Write-ExactBytes $Path $bytes
 return [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()
}
function New-OwnerWindowSample($Context){
 Assert-ExecutionContext $Context -Docker;$s=Get-NativeContext $Context
 if(!$Context.Contract -or !$s.PSObject.Properties['Bridge']){throw 'BRIDGE_WINDOW_CONTEXT'}
 if(!$s.Bridge.ContainsKey('contractJSON') -or ($Context.Contract|ConvertTo-Json -Compress) -cne $s.Bridge.contractJSON){throw 'BRIDGE_WINDOW_BINDING'}
 $now=[Diagnostics.Stopwatch]::GetTimestamp();$f=[Diagnostics.Stopwatch]::Frequency
 $work=[long][Math]::Floor(($Context.WorkDeadline-$now)*1000.0/$f)
 $cutoff=[Math]::Min($Context.WorkDeadline-[long](10*$f),[long]([decimal]$Context.Contract.observationDeadlineMonoNs*$f/1000000000))
 $binding=@{};foreach($k in @('mode','runID','origin','path','expectedPostID','selectedIndex','decisionSHA256','budgetSHA256','observationDeadlineMonoNs')){$binding[$k]=$Context.Contract[$k]}
 $paths=Window-Paths $Context.Control $Context.Mode $Context.Payload.runID;$doc=Read-LimitedJSON $paths.contract 8192;Window-Contract $doc.Value
 foreach($key in $Context.Contract.Keys){if($doc.Value.$key -cne $Context.Contract[$key]){throw 'BRIDGE_WINDOW_CONTRACT'}}
 return @{schema='wed-owner-window-sample-v2';binding=$binding;clockDomain='WINDOWS_QPC';sampleQPC=[string]$now;frequency=[string]$f;utc=[DateTimeOffset]::UtcNow.ToString('o');remainingWorkMs=$work;effectiveObservationCutoffQPC=[string]$cutoff;cleanupDeadlineQPC=[string]$Context.CleanupDeadline;hardDeadlineQPC=[string]$Context.HardDeadline;preOpenMinimumMs=260000;canOpen=($work -ge 260000);sampleIsNotReservation=$true;maxRelayAgeMs=1000;root=$paths.root;observationPath=$paths.observation;abortPath=$paths.abort;sourceAuthority='OWNER_REGISTERED_CONTEXT_ONLY';contractSHA256=$doc.SHA}
}
function Service-OwnerWindowRequest($Context,[scriptblock]$ManagedAfterPublic=$null){
 $s=Get-NativeContext $Context;$b=$s.Bridge;$file=Join-Path $Context.Control 'window-request.json'
 if($ManagedAfterPublic -and (!$b.managed -or $Context.Mode -cne 'MANAGED_ADAPTER_TEST')){throw 'BRIDGE_MANAGED_DISPATCH_ONLY'}
 if(!(Test-Path $file)){return}
 if($b.ContainsKey('windowServed')){return};$b.windowServed=$true
 $request=(Read-LimitedJSON $file 8192).Value
 if($request.schema -cne 'wed-owner-window-request-v2' -or $request.nonce -cnotmatch '^[a-f0-9]{32}$' -or @($request.PSObject.Properties).Count -ne 3){throw 'BRIDGE_WINDOW_REQUEST'}
 $sample=New-OwnerWindowSample $Context
 Window-Binding $request.binding $Context.Contract
 $response=@{schema='wed-owner-window-response-v2';nonce=$request.nonce;sample=$sample}
 $paths=Window-Paths $Context.Control $Context.Mode $Context.Payload.runID
 $sha=Window-Write $paths.response $response
 # Managed-only observation point for the two-phase publication test. The live
 # service has no callback; the original owned-byte hash still seals the response.
 if($ManagedAfterPublic){& $ManagedAfterPublic $paths.root $request.nonce $sample.contractSHA256|Out-Null}
 $proof=@{schema='wed-owner-window-proof-v3';ref=$paths.response;sha256=$sha;mode=$Context.Mode;runID=$Context.Payload.runID;nonce=$request.nonce;binding=$sample.binding;contractSHA256=$sample.contractSHA256;clockDomain='WINDOWS_QPC';frequency=$sample.frequency;sampleQPC=$sample.sampleQPC;ownerStartQPC=[string]$Context.StartTicks;workDeadlineQPC=[string]$Context.WorkDeadline;cleanupDeadlineQPC=[string]$Context.CleanupDeadline;hardDeadlineQPC=[string]$Context.HardDeadline;effectiveObservationCutoffQPC=$sample.effectiveObservationCutoffQPC;remainingWorkMs=$sample.remainingWorkMs;root=$paths.root;observationPath=$paths.observation;abortPath=$paths.abort}
 $null=Window-Write $paths.proof $proof
 Write-BridgeTrace $Context 'WINDOW_SAMPLE' 'OWNER_WINDOW_RESPONSE' @{remainingMs=$sample.remainingWorkMs;preOpenMinimumMs=260000;maxRelayAgeMs=1000}
}
function Test-ManagedWindow($Context){
 $s=Get-NativeContext $Context;if(!$s.Bridge.managed){throw 'BRIDGE_MANAGED_DISPATCH_ONLY'}
 $f=[Diagnostics.Stopwatch]::Frequency;$ns=[string][decimal]::Floor([decimal]$Context.WorkDeadline*1000000000/$f)
 $c=[ordered]@{schema='wed-ui-photo-source-contract-v1';mode='MANAGED_ADAPTER_TEST';runID=$Context.Payload.runID;origin='http://127.0.0.1:5206';path='/';approvedURL='https://www.tiktok.com/@adne_la.veil/photo/7678209751167110421';expectedPostID='7678209751167110421';selectedIndex=2;decisionSHA256=('a'*64);budgetSHA256=('b'*64);observationDeadlineMonoNs=$ns;startMonoNs=(Window-Ns $Context.StartTicks $f);cleanupDeadlineMonoNs=(Window-Ns $Context.CleanupDeadline $f);runDeadlineMonoNs=(Window-Ns $Context.HardDeadline $f)}
 $Context|Add-Member NoteProperty Contract $c;$s.Bridge.contractJSON=($c|ConvertTo-Json -Compress)
 $null=Window-Write (Join-Path $Context.Control 'browser-contract.json') $c
 New-OwnerWindowSample $Context
}
function Initialize-ManagedAdapterHarness($Context){
 $s=Get-NativeContext $Context
 if(!$s.PSObject.Properties['Bridge'] -or !$s.Bridge.managed -or $Context.Mode -cne 'MANAGED_ADAPTER_TEST'){throw 'BRIDGE_MANAGED_DISPATCH_ONLY'}
 if(Test-Path $s.Bridge.root){throw 'BRIDGE_RUNTIME_NAMESPACE_REUSE'}
 New-Item -ItemType Directory (Join-Path $s.Bridge.root 'owner-private') -ErrorAction Stop|Out-Null
 New-Item -ItemType Directory (Join-Path $s.Bridge.root 'control') -ErrorAction Stop|Out-Null
 $Context.Root=$s.Bridge.root;$Context|Add-Member NoteProperty Control (Join-Path $Context.Root 'control')
 return @{mode='MANAGED_HARNESS_NO_NATIVE';root=$Context.Root}
}
function Test-ManagedWindowService($Context,[string]$Nonce,[scriptblock]$AfterPublic=$null){
 $s=Get-NativeContext $Context;if(!$s.Bridge.managed -or $Context.Mode -cne 'MANAGED_ADAPTER_TEST'){throw 'BRIDGE_MANAGED_DISPATCH_ONLY'}
 if($Nonce -cnotmatch '^[a-f0-9]{32}$'){throw 'BRIDGE_WINDOW_REQUEST'}
 $sample=Test-ManagedWindow $Context
 Write-ExclusiveJSON (Join-Path $Context.Control 'window-request.json') @{schema='wed-owner-window-request-v2';nonce=$Nonce;binding=$sample.binding}
 Service-OwnerWindowRequest $Context $AfterPublic
 Read-OwnerWindowResponse $Context.Control $Nonce $sample.contractSHA256
}
function Read-OwnerWindowResponse([string]$Control,[string]$Nonce,[string]$ContractSHA){
 try{Read-OwnerWindowCore $Control $Nonce $ContractSHA}catch{if($_.Exception.Message -cmatch '^BRIDGE_WINDOW_[A-Z_]+$'){throw $_.Exception.Message};throw 'BRIDGE_WINDOW_INVALID'}
}
function Read-OwnerWindowCore([string]$Control,[string]$Nonce,[string]$ContractSHA){
 $root=Resolve-WorkspaceFile ([IO.Path]::GetRelativePath((Get-Location).Path,[IO.Path]::GetFullPath($Control)))
 $doc=Read-LimitedJSON (Join-Path $root 'browser-contract.json') 8192;$c=$doc.Value;Window-Contract $c
 if($doc.SHA -cne $ContractSHA -or $Nonce -cnotmatch '^[a-f0-9]{32}$'){throw 'BRIDGE_WINDOW_CONTRACT'}
 $paths=Window-Paths $root $c.mode $c.runID
 if(!(Test-Path $paths.proof) -or !(Test-Path $paths.response)){throw 'BRIDGE_WINDOW_PENDING_SEAL'}
 $private=Read-LimitedJSON $paths.proof 16384;$p=$private.Value
 $public=Read-LimitedJSON $paths.response 16384;$r=$public.Value;$s=$r.sample
 Window-Keys $r @('schema','nonce','sample')
 foreach($key in @('schema','ref','sha256','mode','runID','nonce','contractSHA256','clockDomain','frequency','sampleQPC','ownerStartQPC','workDeadlineQPC','cleanupDeadlineQPC','hardDeadlineQPC','effectiveObservationCutoffQPC','root','observationPath','abortPath')){if($p.$key -isnot [string]){throw 'BRIDGE_WINDOW_NUMERIC'}}
 foreach($key in @('schema','clockDomain','frequency','sampleQPC','effectiveObservationCutoffQPC','cleanupDeadlineQPC','hardDeadlineQPC','root','observationPath','abortPath','contractSHA256')){if($s.$key -isnot [string]){throw 'BRIDGE_WINDOW_NUMERIC'}}
 if($p.schema -cne 'wed-owner-window-proof-v3' -or $p.ref -cne $paths.response -or $p.sha256 -cne $public.SHA -or $p.contractSHA256 -cne $doc.SHA -or $p.mode -cne $c.mode -or $p.runID -cne $c.runID -or $p.nonce -cne $Nonce -or $r.nonce -cne $Nonce -or $r.schema -cne 'wed-owner-window-response-v2' -or $s.schema -cne 'wed-owner-window-sample-v2' -or $s.contractSHA256 -cne $doc.SHA){throw 'BRIDGE_WINDOW_PRIVATE_PROOF'}
 Window-Binding $p.binding $c;Window-Binding $s.binding $c
 foreach($row in @($s,$p)){if($row.root -cne $paths.root -or $row.observationPath -cne $paths.observation -or $row.abortPath -cne $paths.abort -or $row.clockDomain -cne 'WINDOWS_QPC'){throw 'BRIDGE_WINDOW_PATH_OR_CLOCK'}}
 $freq=Window-Long $p.frequency
 if($freq -ne [Diagnostics.Stopwatch]::Frequency -or $s.frequency -cne $p.frequency){throw 'BRIDGE_WINDOW_NUMERIC'}
 $start=Window-Long $p.ownerStartQPC;$tick=Window-Long $p.sampleQPC;$work=Window-Long $p.workDeadlineQPC;$cleanup=Window-Long $p.cleanupDeadlineQPC;$hard=Window-Long $p.hardDeadlineQPC;$cutoff=Window-Long $p.effectiveObservationCutoffQPC
 if($s.sampleQPC -cne $p.sampleQPC -or $s.cleanupDeadlineQPC -cne $p.cleanupDeadlineQPC -or $s.hardDeadlineQPC -cne $p.hardDeadlineQPC -or $s.effectiveObservationCutoffQPC -cne $p.effectiveObservationCutoffQPC){throw 'BRIDGE_WINDOW_BUDGET'}
 if((Window-Ns $start $freq) -cne $c.startMonoNs -or (Window-Ns $work $freq) -cne $c.observationDeadlineMonoNs -or (Window-Ns $cleanup $freq) -cne $c.cleanupDeadlineMonoNs -or (Window-Ns $hard $freq) -cne $c.runDeadlineMonoNs -or $work-$start -gt 320*$freq -or $cleanup-$work -ne 20*$freq -or $hard-$cleanup -ne $freq -or $hard-$start -gt 341*$freq -or $tick -lt $start -or $tick -ge $work -or $cutoff -ne $work-10*$freq){throw 'BRIDGE_WINDOW_BUDGET'}
 $remaining=[long][Math]::Floor(($work-$tick)*1000.0/$freq)
 foreach($row in @($p,$s)){if(($row.remainingWorkMs -isnot [int] -and $row.remainingWorkMs -isnot [long]) -or $row.remainingWorkMs -ne $remaining){throw 'BRIDGE_WINDOW_NUMERIC'}}
 if(($s.maxRelayAgeMs -isnot [int] -and $s.maxRelayAgeMs -isnot [long]) -or ($s.preOpenMinimumMs -isnot [int] -and $s.preOpenMinimumMs -isnot [long]) -or $s.maxRelayAgeMs -ne 1000 -or $s.preOpenMinimumMs -ne 260000){throw 'BRIDGE_WINDOW_BUDGET'}
 $now=[Diagnostics.Stopwatch]::GetTimestamp();$age=($now-$tick)*1000.0/$freq;$left=[long][Math]::Floor(($work-$now)*1000.0/$freq)
 if($age -lt 0 -or $age -gt 1000 -or $left -lt 260000 -or $now -ge $cutoff){throw 'BRIDGE_WINDOW_STALE_OR_TOO_SMALL'}
 return @{schema='wed-owner-window-client-v2';binding=$s.binding;sample=$s;ageAtReadMs=$age;remainingAtReadMs=$left;privateProofSHA256=$private.SHA;proofMeaning='OWNER_PRIVATE_SEAL_AND_CONTRACT_BOUNDED_AT_READ_NOT_FUTURE_RESERVATION'}
}
function Request-OwnerWindowSample([string]$Control,[string]$ContractSHA){
 $timer=[Diagnostics.Stopwatch]::StartNew()
 $root=Resolve-WorkspaceFile ([IO.Path]::GetRelativePath((Get-Location).Path,[IO.Path]::GetFullPath($Control)))
 $file=Join-Path $root 'browser-contract.json';$doc=Read-LimitedJSON $file 8192;$c=$doc.Value
 if($doc.SHA -cne $ContractSHA -or $c.mode -cne 'UI_SINGLE_PHOTO_SOURCE' -or $c.runID -cnotmatch '^[a-f0-9]{32}$' -or $c.expectedPostID -cne '7678209751167110421' -or $c.selectedIndex -ne 2){throw 'BRIDGE_WINDOW_CONTRACT'}
 $expected=Resolve-WorkspaceFile ('docs/evidence/ui-source-live-attempt-20261019/backend/source-'+$c.runID+'/control')
 if($root -cne $expected){throw 'BRIDGE_WINDOW_ROOT'}
 $binding=@{};foreach($key in @('mode','runID','origin','path','expectedPostID','selectedIndex','decisionSHA256','budgetSHA256','observationDeadlineMonoNs')){$binding[$key]=$c.$key}
 $nonce=[Guid]::NewGuid().ToString('N')
 Write-ExclusiveJSON (Join-Path $root 'window-request.json') @{schema='wed-owner-window-request-v2';nonce=$nonce;binding=$binding}
 $paths=Window-Paths $root $c.mode $c.runID
 while(!(Test-Path $paths.response) -or !(Test-Path $paths.proof)){if($timer.ElapsedMilliseconds -ge 1000){throw 'BRIDGE_WINDOW_NO_RESPONSE'};Start-Sleep -Milliseconds 20}
 $result=Read-OwnerWindowResponse $root $nonce $ContractSHA
 if($timer.ElapsedMilliseconds -gt 1000){throw 'BRIDGE_WINDOW_NO_RESPONSE'};return $result
}
function Invoke-ManagedOwnerCoordinator($Context){
 $state=Get-NativeContext $Context
 if(!$state.Bridge.managed -or $Context.Mode -cne 'MANAGED_ADAPTER_TEST'){throw 'BRIDGE_MANAGED_COORDINATOR_ONLY'}
 $Context.Root=$state.Bridge.root;New-Item -ItemType Directory (Join-Path $Context.Root 'owner-private') -ErrorAction Stop|Out-Null
 Write-ExclusiveJSON (Join-Path $Context.Root 'owner-private/authority-public.json') $state.Bridge.publicIdentity
 $Context|Add-Member NoteProperty Control (Join-Path $Context.Root 'control');New-Item -ItemType Directory $Context.Control|Out-Null
 $Context|Add-Member NoteProperty Plan @{resources=@{roles=@(@{role='app';image='sha256:d4558b29dd379b16d4906fb9e618dfc4d045e3008a70e031ea3474b7b2218e4e'})}}
 $execution=$false;$cause=$null;$closure=$null
 try{
  $entry=Register-Planned $Context 'container' ('wed-source-'+$Context.Payload.runID+'-app') 'app'
  $r=Invoke-DockerNative $Context 'MANAGED_CREATE' @('create','--name',$entry.Name,'--label',('com.wed-snap.run='+$Context.Payload.runID),$entry.Image) 'startup'
  # Content/layout acceptance is intentionally separate from cleanup safety.
  $inspection=Get-DockerOne (Invoke-DockerNative $Context 'MANAGED_LAYOUT' @('inspect',$entry.ID) 'startup')
  Assert-BridgeResource $Context $entry $inspection
  if(@($inspection.Mounts).Count -ne 2 -or @($inspection.Mounts|Where-Object{$_.Type -cne 'bind' -or $_.RW -or $_.Destination -cnotin @('/unit/one','/unit/two')}).Count){throw 'BRIDGE_RUNTIME_LAYOUT_FAIL'}
  $execution=$true
 }catch{$cause=(Bridge-Exception $_).errorID;if($cause -ceq 'UNCLASSIFIED_NO_MESSAGE'){$cause='MANAGED_OPERATION_FAILED'}}finally{$closure=Close-SourceRegistry $Context;Save-NativeReceipts $Context}
 return @{mode='MANAGED_ADAPTER_TEST_NO_NATIVE_OR_SOURCE';executionPASS=$execution;cause=$cause;cleanup=$closure;trace=Get-SourceAdapterTrace $Context;registry=$Context.Registry.ToArray()}
}
function Test-ManagedSourceDispatch($Context,[string[]]$Argv,[string]$Operation='MANAGED_ARGUMENT_PROBE'){
 $s=Get-NativeContext $Context;if(!$s.PSObject.Properties['Bridge'] -or !$s.Bridge.managed -or $Context.Mode -cne 'MANAGED_ADAPTER_TEST'){throw 'BRIDGE_MANAGED_DISPATCH_ONLY'}
 Invoke-DockerNative $Context $Operation $Argv 'startup' 1500
}
