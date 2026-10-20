param([ValidateRange(1,20)][int]$Attempt=1)
$ErrorActionPreference='Stop';Set-Location 'D:\WED SNAP'
$ev="docs/evidence/tiktok-photo-egress-step3-20261015/pipeline-$Attempt";if(Test-Path $ev){throw 'Refuse reuse'};New-Item -ItemType Directory -Path $ev|Out-Null
$run=[Guid]::NewGuid().ToString('N');$ids=@();$nets=@()
$proxyImage='sha256:8bc0a567955111ea3cfbab2dd3b14f40a602f2d10ac987e78eb465f9d48d7f10';$mediaImage='sha256:31742091e95df2cc62669a6c6a9e0892dc09a34341eaeefc16959dcd4dfa417e'
function Native([string]$step,[string[]]$argv){$begin=[DateTimeOffset]::UtcNow;$out=& docker @argv 2>&1|Out-String;$exit=$LASTEXITCODE;@{step=$step;arguments=$argv;actualExit=$exit;utcStart=$begin.ToString('o');utcEnd=[DateTimeOffset]::UtcNow.ToString('o');output=$out}|ConvertTo-Json -Depth 10 -Compress|Add-Content "$ev/native.jsonl";if($exit){throw "Native $step exit$exit"};return $out.Trim()}
$source=@(Get-ChildItem apps/egress -Recurse -File|Where-Object{$_.FullName -notmatch '__pycache__'})+@(Get-ChildItem apps/media/src -Recurse -File|Where-Object{$_.FullName -notmatch '[\\/](node_modules|__pycache__)[\\/]'})
$hashes=@($source|Sort-Object FullName|ForEach-Object{@{path=[IO.Path]::GetRelativePath((Get-Location).Path,$_.FullName).Replace('\','/');sha256=(Get-FileHash $_.FullName).Hash.ToLowerInvariant()}});$hashes|ConvertTo-Json|Set-Content "$ev/expected-source.json"
$tools=@(Get-ChildItem labs/tiktok/photo-egress-step3 -File|ForEach-Object{@{path=$_.Name;sha256=(Get-FileHash $_.FullName).Hash.ToLowerInvariant()}})
$tools|ConvertTo-Json|Set-Content "$ev/test-source.json"
New-Item -ItemType Directory -Path "$ev/tested-tools"|Out-Null
foreach($tool in $tools){Copy-Item -LiteralPath "labs/tiktok/photo-egress-step3/$($tool.path)" -Destination "$ev/tested-tools/$($tool.path)"}
$mounts=@('--mount',"type=bind,source=$((Resolve-Path labs/tiktok/photo-egress-step3).Path),target=/fixture,readonly",'--mount',"type=bind,source=$((Resolve-Path $ev).Path),target=/control")
$mediaMounts=@(foreach($file in $source|Where-Object{$_.FullName -match '[\\/]apps[\\/]media[\\/]src[\\/]'}){'--mount';"type=bind,source=$($file.FullName),target=/app/$([IO.Path]::GetRelativePath((Get-Location).Path,$file.FullName).Replace('\','/')),readonly"})+@('--mount',"type=bind,source=$((Resolve-Path apps/media/src/media_adapter.py).Path),target=/app/infra/media_adapter.py,readonly")
function Create([string]$role,[string]$network,[string]$command){
 $proxy=$role -eq 'proxy';$memory=if($proxy){'96m'}else{'512m'};$cpu=if($proxy){'0.25'}else{'0.75'};$user=if($proxy){'65534:65534'}else{'1000:1000'};$image=if($proxy){$proxyImage}else{$mediaImage}
 $extra=if($proxy){@('--network-alias','egress','-e','TIKTOK_EGRESS_POLICY_ENABLED=1','-e','EGRESS_STEP3_FIXTURE=1','-e','PYTHONPATH=/code/src:/code/vendor:/fixture','--mount',"type=bind,source=$((Resolve-Path apps/egress).Path),target=/code,readonly")}
 else{@('-e','MEDIA_ROOT=/media','-e','MEDIA_PROXY=http://egress:8888','-e','NODE_OPTIONS=--max-old-space-size=128','-e','PYTHONPATH=/fixture:/app/apps/media/src','--tmpfs','/media:size=48m,uid=1000,gid=1000,noexec,nosuid')+$mediaMounts}
 Native "create-$role" (@('create','--pull=never','--label',"com.wed-snap.run=$run",'--network',$network,'--ipc','private','--read-only','--user',$user,'--memory',$memory,'--memory-swap',$memory,'--cpus',$cpu,'--pids-limit','96','--cap-drop','ALL','--security-opt','no-new-privileges:true','--tmpfs','/tmp:size=16m,mode=1777,nosuid,noexec','-e','PYTHONDONTWRITEBYTECODE=1')+$mounts+$extra+@($image,'/usr/bin/timeout','--signal=KILL','225s','python3')+@($command -split ' '))
}
try{
 $generate=Create 'generate' 'none' '/fixture/media.py generate';$ids+=,$generate
 Native 'generate' @('start','-a',$generate)|Out-Null
 $prep=@((Native 'generate-owner-state' @('inspect',$generate)|ConvertFrom-Json))[0]
 if($prep.Config.Labels.'com.wed-snap.run' -cne $run -or $prep.State.ExitCode -ne 0 -or $prep.State.OOMKilled){throw 'Generate ownership/state failed'}
 Native 'remove-generate-before-runtime' @('rm',$generate)|Out-Null
 $ids=@($ids|Where-Object{$_ -cne $generate})
 $network=Native 'create-network' @('network','create','--internal','--label',"com.wed-snap.run=$run",("photo-egress-step3-$run"));$nets+=,$network
 $proxy=Create 'proxy' $network '/fixture/proxy_service.py';$ids+=,$proxy
 $media=Create 'media' $network '/fixture/media.py pipeline';$ids+=,$media
 foreach($id in $ids){$g=@((Native 'guard' @('inspect',$id)|ConvertFrom-Json))[0];if($g.Config.Labels.'com.wed-snap.run' -cne $run -or !$g.HostConfig.ReadonlyRootfs -or $g.HostConfig.Privileged -or $g.HostConfig.CapAdd -or $g.HostConfig.CapDrop -notcontains 'ALL' -or $g.HostConfig.SecurityOpt -notcontains 'no-new-privileges:true' -or $g.HostConfig.MemorySwap -ne $g.HostConfig.Memory -or @($g.HostConfig.PortBindings.PSObject.Properties).Count){throw 'Guard failed'};$g|ConvertTo-Json -Depth 40|Set-Content "$ev/guard-$id.json"}
 $n=@((Native 'network-guard' @('network','inspect',$network)|ConvertFrom-Json))[0];if(!$n.Internal){throw 'Network must be internal'}
 Native 'start-proxy' @('start',$proxy)|Out-Null
 $end=[DateTimeOffset]::UtcNow.AddSeconds(25);while(!(Test-Path "$ev/ready") -and [DateTimeOffset]::UtcNow -lt $end){Start-Sleep -Milliseconds 100};if(!(Test-Path "$ev/ready")){Native 'proxy-failure-logs' @('logs',$proxy)|Out-Null;throw 'Proxy readiness failed'}
 Native 'media' @('start','-a',$media)|Out-Null
 $wait=Native 'proxy-wait' @('wait',$proxy);Native 'proxy-logs' @('logs',$proxy)|Out-Null
 foreach($id in @($proxy,$media)){$g=@((Native 'state' @('inspect',$id)|ConvertFrom-Json))[0];if($g.State.ExitCode -ne 0 -or $g.State.OOMKilled){throw 'Actual runtime state failed'}}
 $result=Get-Content "$ev/proxy-result.json" -Raw|ConvertFrom-Json
 if($result.status -cne 'PASS_PROXY_TLS_CLOSURE' -or $result.counts.metadata -ne 4 -or $result.counts.videoMetadata -ne 2 -or $result.counts.JPEG -ne 1 -or @($result.connections|Where-Object{!$_.accepted -or !$_.workerThreadClosed}).Count){throw 'Pipeline receipt/counter guard failed'}
 foreach($r in $hashes){if((Get-FileHash $r.path).Hash.ToLowerInvariant() -cne $r.sha256){throw 'Source drift'}}
 foreach($tool in $tools){if((Get-FileHash "labs/tiktok/photo-egress-step3/$($tool.path)").Hash.ToLowerInvariant() -cne $tool.sha256){throw 'Fixture drift'}}
 @{status='PASS_OFFLINE_ACTUAL_PROXY_TLS_JPEG';sourceCalls=0;actualExits=@(0,0);totalRuntimeBytes=608MB;utc=[DateTimeOffset]::UtcNow.ToString('o');vn=[DateTimeOffset]::UtcNow.ToOffset([TimeSpan]::FromHours(7)).ToString('o')}|ConvertTo-Json|Set-Content "$ev/completion.json"
}finally{
 if($proxy -and (Test-Path $ev)){[IO.File]::WriteAllText((Join-Path (Resolve-Path $ev).Path 'stop'),'stop')}
 foreach($id in $ids){$g=@((Native 'cleanup-owner' @('inspect',$id)|ConvertFrom-Json))[0];if($g.Config.Labels.'com.wed-snap.run' -cne $run){throw 'Owner mismatch'};Native 'remove-own' @('rm','-f',$id)|Out-Null}
 foreach($id in $nets){Native 'remove-network' @('network','rm',$id)|Out-Null}
 $left=Native 'verify-absent' @('ps','-aq','--filter',"label=com.wed-snap.run=$run");if($left){throw 'Own resources remain'}
 @{containers=$ids;generateRemovedBeforeRuntime=$generate;networks=$nets;ownResourcesLeft=0;volumesCreated=0;run=$run}|ConvertTo-Json|Set-Content "$ev/cleanup.json"
}
