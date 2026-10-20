param([switch]$ExecuteSource,[switch]$DryRun)
if(!$ExecuteSource -and !$DryRun){Write-Output 'SOURCE_DISABLED sourceGrantNew=false sourceRequestsNew=0';exit 78}
$ErrorActionPreference='Stop';Set-Location 'D:\WED SNAP'
$lab='labs/tiktok/photo-source-fixed'
$pins=@(Get-Content "$lab/source-pins.json" -Raw|ConvertFrom-Json)
$dependencies=@(Get-Content "$lab/tool-dependencies.json" -Raw|ConvertFrom-Json)
if($pins.Count -ne 128 -or $dependencies.Count -ne 36){throw 'PIN_COVERAGE'}
foreach($pin in @($pins+$dependencies)){if((Get-FileHash -LiteralPath $pin.path).Hash.ToLowerInvariant() -cne $pin.sha256){throw 'PIN_MISMATCH'}}
. "$lab/mounts.ps1"
if($DryRun){
 @{status='DRY_RUN_ONLY';sourceGrantNew=$false;sourceExecutionStarted=$false;sourceRequestsNew=0;executionSwitchPresent=[bool]$ExecuteSource;resourcesCreated=0;sourcePins=$pins.Count;frozenToolPins=$dependencies.Count;proxyMounts=@(ProxyMounts);appCommonMounts=@(AppCommonMounts);proxyCommand=@(ProxyCommand);appCommand=@('-I','/lab/source_entry.py');target='https://www.tiktok.com/@adne_la.veil/photo/7678209751167110421';selectedIndex=2;sourceGETBudget='2+2+conditional1';topology=@{app='internal-only';PGRedis='internal-only';proxy='internal+dedicated-egress-only-after-new-source-task';controlCIDR='exactinternal local-and-peer';publicPorts=0};runtimeMiB=800;futureRuntime='docs/evidence/tiktok-photo-source-fixed-runtime-20261015/source-once';testCodeMountedOnSource=$false}|ConvertTo-Json -Depth 6
 exit 0
}
$ev='docs/evidence/tiktok-photo-source-fixed-runtime-20261015/source-once';if(Test-Path $ev){throw 'Refuse reuse'};New-Item -ItemType Directory -Path $ev|Out-Null
$run=[Guid]::NewGuid().ToString('N');$ids=@();$nets=@();$proxyID=$null;$phaseSecret=[Convert]::ToHexString([Security.Cryptography.RandomNumberGenerator]::GetBytes(32)).ToLowerInvariant()
$adminSecret=[Convert]::ToHexString([Security.Cryptography.RandomNumberGenerator]::GetBytes(32)).ToLowerInvariant()
$proxyImage='sha256:8bc0a567955111ea3cfbab2dd3b14f40a602f2d10ac987e78eb465f9d48d7f10';$appImage='sha256:d4558b29dd379b16d4906fb9e618dfc4d045e3008a70e031ea3474b7b2218e4e'
function Scrub([string]$s){$s.Replace($adminSecret,'[admin-secret-redacted]').Replace($phaseSecret,'[control-secret-redacted]')}
$runDeadline=[DateTimeOffset]::UtcNow.AddSeconds(360);$startupDeadline=[DateTimeOffset]::UtcNow.AddSeconds(60);$cleanupDeadline=$null;$executionStarted=$false
function Native([string]$step,[string[]]$argv){
 $begin=[DateTimeOffset]::UtcNow
 $end=if($cleanupDeadline){$cleanupDeadline}elseif(!$executionStarted){$startupDeadline}else{$runDeadline.AddSeconds(-20)}
 $cap=if($step -eq 'test'){320000}else{30000};$wait=[int][Math]::Floor([Math]::Min($cap,($end-$begin).TotalMilliseconds))
 if($wait -le 0){throw 'ORCHESTRATOR_ABSOLUTE_DEADLINE'}
 $info=[Diagnostics.ProcessStartInfo]::new('docker');$info.UseShellExecute=$false;$info.CreateNoWindow=$true;$info.RedirectStandardOutput=$true;$info.RedirectStandardError=$true
 foreach($a in $argv){$info.ArgumentList.Add($a)}
 $proc=[Diagnostics.Process]::new();$proc.StartInfo=$info
 try{
  if(!$proc.Start()){throw 'DOCKER_CLI_START'}
  $stdout=$proc.StandardOutput.ReadToEndAsync();$stderr=$proc.StandardError.ReadToEndAsync();$timedOut=!$proc.WaitForExit($wait)
  if($timedOut){$proc.Kill($true);$proc.WaitForExit(1000)|Out-Null}
  $out=$stdout.GetAwaiter().GetResult()+$stderr.GetAwaiter().GetResult();$exit=if($proc.HasExited){$proc.ExitCode}else{$null}
  if($out.Length -gt 1048576){throw 'NATIVE_OUTPUT_CAP'}
  $record=@{step=$step;arguments=$argv;actualExit=$exit;timedOut=$timedOut;nativeWaitLimitMs=$wait;utcStart=$begin.ToString('o');utcEnd=[DateTimeOffset]::UtcNow.ToString('o');output=$out}|ConvertTo-Json -Depth 10 -Compress
  Scrub $record|Add-Content "$ev/native.jsonl"
  if($timedOut -or $exit -ne 0){throw "Native $step did not complete successfully"};return $out.Trim()
 }finally{$proc.Dispose()}
}
$files=@($pins|ForEach-Object{Get-Item -LiteralPath $_.path})
$hashes=@($files|Sort-Object FullName -Unique|ForEach-Object{@{path=[IO.Path]::GetRelativePath((Get-Location).Path,$_.FullName).Replace('\','/');sha256=(Get-FileHash $_.FullName).Hash.ToLowerInvariant()}});$hashes|ConvertTo-Json|Set-Content "$ev/expected-source.json"
$tests=@($dependencies)+@(Get-ChildItem $lab -File|ForEach-Object{@{path=[IO.Path]::GetRelativePath((Get-Location).Path,$_.FullName).Replace('\','/');sha256=(Get-FileHash $_.FullName).Hash.ToLowerInvariant()}});$tests|ConvertTo-Json|Set-Content "$ev/test-source.json";New-Item -ItemType Directory "$ev/tested-tools"|Out-Null;foreach($r in $tests){$d="$ev/tested-tools/$($r.path)";New-Item -ItemType Directory -Force (Split-Path $d)|Out-Null;Copy-Item -LiteralPath $r.path -Destination $d}
$common=@('--mount',"type=bind,source=$((Resolve-Path $ev).Path),target=/control")
$repoMounts=@(foreach($root in @('apps/egress','apps/web','apps/worker/src','apps/api/src','packages/shared/src','prisma')){'--mount';"type=bind,source=$((Resolve-Path $root).Path),target=/repo/$root,readonly"})
foreach($file in $files|Where-Object{$_.FullName -match '[\\/]apps[\\/]media[\\/]src[\\/]'}){$relative=[IO.Path]::GetRelativePath((Get-Location).Path,$file.FullName).Replace('\','/');$repoMounts+=@('--mount',"type=bind,source=$($file.FullName),target=/repo/$relative,readonly")}
foreach($root in @('package.json','package-lock.json','tsconfig.json')){$repoMounts+=@('--mount',"type=bind,source=$((Resolve-Path $root).Path),target=/repo/$root,readonly")}
$appMounts=@(foreach($root in @('apps/web','apps/worker/src','apps/api/src','packages/shared/src','prisma')){'--mount';"type=bind,source=$((Resolve-Path $root).Path),target=/app/$root,readonly"})
foreach($file in $files|Where-Object{$_.FullName -match '[\\/]apps[\\/]media[\\/]src[\\/]'}){$rel=[IO.Path]::GetRelativePath((Get-Location).Path,$file.FullName).Replace('\','/');$appMounts+=@('--mount',"type=bind,source=$($file.FullName),target=/app/$rel,readonly")}
$appMounts+=@(FrozenMount 'labs/tiktok/photo-app-source-executor/common/media_entry.py' '/app/infra/media_adapter.py')
function Create([string]$role,[string]$network,[string]$command){
 $proxy=$role -in @('broker','proxy');$mem=if($proxy){'96m'}else{'512m'};$cpu=if($proxy){'0.25'}else{'0.75'};$user=if($proxy){'65534:65534'}else{'1000:1000'};$image=if($proxy){$proxyImage}else{$appImage};$pids=if($role -eq 'broker'){'64'}elseif($proxy){'96'}else{'160'}
 $extra=if($proxy){@('-e',"TIKTOK_EGRESS_CONTROL_NETWORKS=$controlSubnet")}
 else{@('-e','PYTHONPATH=/app/apps/media/src','-e','MEDIA_ROOT=/media','-e','MEDIA_PROXY=http://egress:8888','-e','NODE_OPTIONS=--max-old-space-size=128','-e','DATABASE_URL=postgresql://gate_fixture:lab-public-only-password@postgres:5432/step5_executor','-e','REDIS_URL=redis://redis:6379/7','-e','APP_ORIGIN=http://step5-executor.invalid','-e',"ADMIN_SESSION_SECRET=$adminSecret",'-e','TIKTOK_PHOTO_ENABLED=1','-e','TIKTOK_ADAPTER_ENABLED=1','-e','VERIFIED_PLATFORMS=tiktok,youtube','--tmpfs','/media:size=64m,uid=1000,gid=1000,nosuid,noexec','--tmpfs','/app/node_modules/.prisma:size=64m,uid=1000,gid=1000,nosuid,exec')+$appMounts}
 $extra+=@('-e','STEP5_EXECUTE_SOURCE=1') # Only reachable by the explicit switch in a separately assigned source task.
 $roleMounts=if($proxy){@(ProxyMounts)}else{@(AppCommonMounts)}
 $roleRepoMounts=if($proxy){@()}else{$repoMounts} # ProxyMounts already owns /repo/apps/egress; never duplicate a destination.
 if($role -eq 'proxy'){$extra+=@('--network-alias','egress')}
 Native "create-$role" (@('create','--pull=never','--label',"com.wed-snap.run=$run",'--network',$network,'--ipc','private','--read-only','--user',$user,'--memory',$mem,'--memory-swap',$mem,'--cpus',$cpu,'--pids-limit',$pids,'--cap-drop','ALL','--security-opt','no-new-privileges:true','--tmpfs','/tmp:size=32m,mode=1777,nosuid','-e','PYTHONDONTWRITEBYTECODE=1','-e','TIKTOK_EGRESS_POLICY_ENABLED=1','-e',"TIKTOK_EGRESS_CONTROL_SECRET=$phaseSecret")+$common+$roleRepoMounts+$roleMounts+$extra+@($image,'/usr/bin/timeout','--signal=KILL','360s','python3')+@($command -split ' '))
}
try{
 foreach($pin in @($appImage,$proxyImage,'sha256:38471f330eb885e04de130b768d6db4e10469e2311879c7e5c699f6d2d8a1c74','sha256:a9cc41d6d01da2aa26c219e4f99ecbeead955a7b656c1c499cce8922311b2514')){Native 'cache-inspect' @('image','inspect',$pin,'--format','{{.Id}}')|Out-Null}
 $controlSubnet='127.0.0.0/8'
  $net=Native 'network-create' @('network','create','--internal','--label',"com.wed-snap.run=$run",("photo-app-source-executor-$run"));$nets+=,$net
  $n=@((Native 'network-guard' @('network','inspect',$net)|ConvertFrom-Json))[0];if(!$n.Internal){throw 'Internal required'};$controlSubnet=$n.IPAM.Config[0].Subnet
  $pg=Native 'create-db' @('create','--pull=never','--label',"com.wed-snap.run=$run",'--network',$net,'--network-alias','postgres','--read-only','--user','999:999','--memory','128m','--memory-swap','128m','--cpus','0.25','--pids-limit','64','--cap-drop','ALL','--security-opt','no-new-privileges:true','--tmpfs','/var/lib/postgresql/data:size=128m,uid=999,gid=999,nosuid','--tmpfs','/var/run/postgresql:size=8m,uid=999,gid=999,nosuid','--tmpfs','/tmp:size=8m,uid=999,gid=999,nosuid','-e','POSTGRES_DB=step5_executor','-e','POSTGRES_USER=gate_fixture','-e','POSTGRES_PASSWORD=lab-public-only-password','sha256:38471f330eb885e04de130b768d6db4e10469e2311879c7e5c699f6d2d8a1c74','postgres','-c','shared_buffers=16MB','-c','max_connections=20');$ids+=,$pg
  $redis=Native 'create-redis' @('create','--pull=never','--label',"com.wed-snap.run=$run",'--network',$net,'--network-alias','redis','--read-only','--user','1000:1000','--memory','64m','--memory-swap','64m','--cpus','0.25','--pids-limit','32','--cap-drop','ALL','--security-opt','no-new-privileges:true','--tmpfs','/data:size=8m,uid=1000,gid=1000,nosuid','sha256:a9cc41d6d01da2aa26c219e4f99ecbeead955a7b656c1c499cce8922311b2514','redis-server','--save','','--appendonly','no','--maxmemory','32mb');$ids+=,$redis
  Native 'start-db' @('start',$pg,$redis)|Out-Null;Native 'db-ready' @('exec',$pg,'bash','-c','for i in {1..40}; do pg_isready -U gate_fixture -d step5_executor && exit 0; sleep .25; done; exit 1')|Out-Null
  $proxyCommand=(ProxyCommand) -join ' '
  $proxyID=Create 'proxy' $net $proxyCommand;$ids+=,$proxyID
  Native 'start-proxy' @('start',$proxyID)|Out-Null
  # This branch is prepared for a separately authorized source task. Never entered by offline/import/dry-run.
   $external=Native 'source-egress-create' @('network','create','--driver','bridge','--label',"com.wed-snap.run=$run",("photo-executor-egress-$run"));$nets+=,$external
   Native 'source-egress-connect-proxy-only' @('network','connect',$external,$proxyID)|Out-Null
   $x=@((Native 'source-egress-inspect' @('network','inspect',$external)|ConvertFrom-Json))[0]
   if($x.Internal -or $x.Driver -cne 'bridge' -or @($x.Containers.PSObject.Properties).Count -ne 1 -or @($x.Containers.PSObject.Properties.Name)[0] -cne $proxyID){throw 'SOURCE_TOPOLOGY_NOT_ISOLATED'}
  $end=[DateTimeOffset]::UtcNow.AddSeconds(20);while(!(Test-Path "$ev/ready") -and [DateTimeOffset]::UtcNow -lt $end){Start-Sleep -Milliseconds 100};if(!(Test-Path "$ev/ready")){Native 'proxy-logs' @('logs',$proxyID)|Out-Null;throw 'Proxy not ready'}
  $app=Create 'source' $net '-I /lab/source_entry.py';$ids+=,$app
 foreach($id in $ids){$g=@((Native 'guard' @('inspect',$id)|ConvertFrom-Json))[0];if($g.Config.Labels.'com.wed-snap.run' -cne $run -or !$g.HostConfig.ReadonlyRootfs -or $g.HostConfig.Privileged -or $g.HostConfig.CapAdd -or $g.HostConfig.CapDrop -notcontains 'ALL' -or $g.HostConfig.SecurityOpt -notcontains 'no-new-privileges:true' -or $g.HostConfig.MemorySwap -ne $g.HostConfig.Memory -or @($g.HostConfig.PortBindings.PSObject.Properties).Count){throw 'Guard failed'}
   $want=if($id -ceq $proxyID){2}else{1};if(@($g.NetworkSettings.Networks.PSObject.Properties).Count -ne $want){throw 'SOURCE_NETWORK_MEMBERSHIP'}
   if($id -cne $proxyID -and $g.HostConfig.NetworkMode -cne $net){throw 'NON_PROXY_EXTERNAL_NETWORK'}
   if(@($g.Mounts|Where-Object{$_.Destination -ceq '/offline'}).Count -or ($g.Config.Env -match '^STEP5_OFFLINE')){throw 'FIXTURE_IN_SOURCE'}
  Scrub ($g|ConvertTo-Json -Depth 40)|Set-Content "$ev/guard-$id.json"
 }
 $executionStarted=$true;Native 'test' @('start','-a',$app)|Out-Null
 [IO.File]::WriteAllText((Join-Path (Resolve-Path $ev).Path 'stop'),'stop')
 foreach($id in $ids){$s=@((Native 'state' @('inspect',$id)|ConvertFrom-Json))[0];if($s.State.OOMKilled){throw 'OOM'}}
 $exit=Native 'proxy-wait' @('wait',$proxyID);Native 'proxy-logs' @('logs',$proxyID)|Out-Null;if($exit -cne '0'){throw 'Expected proxy closure0'}
 foreach($r in $hashes){if((Get-FileHash $r.path).Hash.ToLowerInvariant() -cne $r.sha256){throw 'Source changed'}}
 foreach($r in $tests){if((Get-FileHash -LiteralPath $r.path).Hash.ToLowerInvariant() -cne $r.sha256){throw 'Runtime dependency changed'}}
 @{status='TECHNICAL_SOURCE_RESULT_SEE_FILE_AND_REVIEW';actualExit=0;sourceExecutionStarted=$true;sourceCalls='SEE_PHASE_ATTEMPTS_AND_RESPONSES_WIRE_UNKNOWN';utc=[DateTimeOffset]::UtcNow.ToString('o');vn=[DateTimeOffset]::UtcNow.ToOffset([TimeSpan]::FromHours(7)).ToString('o')}|ConvertTo-Json|Set-Content "$ev/completion.json"
}finally{
 $cleanupStart=[DateTimeOffset]::UtcNow;$cleanupDeadline=$cleanupStart.AddSeconds(20)
 if($proxyID){[IO.File]::WriteAllText((Join-Path (Resolve-Path $ev).Path 'stop'),'stop')}
 foreach($id in $ids){$g=@((Native 'cleanup-owner' @('inspect',$id)|ConvertFrom-Json))[0];if($g.Config.Labels.'com.wed-snap.run' -cne $run){throw 'Owner mismatch'};Native 'remove-own' @('rm','-f',$id)|Out-Null}
 foreach($id in $nets){Native 'remove-network' @('network','rm',$id)|Out-Null}
 $left=Native 'absent' @('ps','-aq','--filter',"label=com.wed-snap.run=$run");if($left){throw 'Owned resources remain'}
 @{containers=$ids;networks=$nets;generatorRemoved=$gen;ownResourcesLeft=0;volumesCreated=0;run=$run;cleanupLimitSeconds=20;cleanupElapsedSeconds=([DateTimeOffset]::UtcNow-$cleanupStart).TotalSeconds;timeoutMeansClosureUnknown=$true}|ConvertTo-Json|Set-Content "$ev/cleanup.json"
}
