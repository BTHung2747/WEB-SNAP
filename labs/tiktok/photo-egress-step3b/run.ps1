param([ValidateSet('broker','typecheck','worker')][string]$Mode='broker',[ValidateRange(1,20)][int]$Attempt=1)
$ErrorActionPreference='Stop';Set-Location 'D:\WED SNAP'
$ev="docs/evidence/tiktok-photo-egress-step3b-20261015/$Mode-$Attempt";if(Test-Path $ev){throw 'Refuse reuse'};New-Item -ItemType Directory -Path $ev|Out-Null
$run=[Guid]::NewGuid().ToString('N');$ids=@();$nets=@();$proxyID=$null;$phaseSecret=[Convert]::ToHexString([Security.Cryptography.RandomNumberGenerator]::GetBytes(32)).ToLowerInvariant()
$proxyImage='sha256:8bc0a567955111ea3cfbab2dd3b14f40a602f2d10ac987e78eb465f9d48d7f10';$appImage='sha256:d4558b29dd379b16d4906fb9e618dfc4d045e3008a70e031ea3474b7b2218e4e'
function Scrub([string]$s){$s.Replace($phaseSecret,'[control-secret-redacted]')}
function Native([string]$step,[string[]]$argv){$begin=[DateTimeOffset]::UtcNow;$out=& docker @argv 2>&1|Out-String;$exit=$LASTEXITCODE;$record=@{step=$step;arguments=$argv;actualExit=$exit;utcStart=$begin.ToString('o');utcEnd=[DateTimeOffset]::UtcNow.ToString('o');output=$out}|ConvertTo-Json -Depth 10 -Compress;Scrub $record|Add-Content "$ev/native.jsonl";if($exit){throw "Native $step exit$exit"};return $out.Trim()}
$files=@(foreach($root in @('apps/egress','apps/media/src','apps/worker/src','apps/api/src','packages/shared/src','prisma')){Get-ChildItem $root -File -Recurse|Where-Object{$_.FullName -notmatch '[\\/](node_modules|__pycache__)[\\/]'}})+@(Get-Item package.json,package-lock.json,tsconfig.json)
$hashes=@($files|Sort-Object FullName|ForEach-Object{@{path=[IO.Path]::GetRelativePath((Get-Location).Path,$_.FullName).Replace('\','/');sha256=(Get-FileHash $_.FullName).Hash.ToLowerInvariant()}});$hashes|ConvertTo-Json|Set-Content "$ev/expected-source.json"
$tests=@(Get-ChildItem labs/tiktok/photo-egress-step3b -File|ForEach-Object{@{path=$_.Name;sha256=(Get-FileHash $_.FullName).Hash.ToLowerInvariant()}});$tests|ConvertTo-Json|Set-Content "$ev/test-source.json";New-Item -ItemType Directory -Path "$ev/tested-tools"|Out-Null;foreach($r in $tests){Copy-Item "labs/tiktok/photo-egress-step3b/$($r.path)" "$ev/tested-tools/$($r.path)"}
$common=@('--mount',"type=bind,source=$((Resolve-Path labs/tiktok/photo-egress-step3b).Path),target=/fixture,readonly",'--mount',"type=bind,source=$((Resolve-Path $ev).Path),target=/control")
$repoMounts=@(foreach($root in @('apps/egress','apps/worker/src','apps/api/src','packages/shared/src','prisma')){'--mount';"type=bind,source=$((Resolve-Path $root).Path),target=/repo/$root,readonly"})
foreach($file in $files|Where-Object{$_.FullName -match '[\\/]apps[\\/]media[\\/]src[\\/]'}){$relative=[IO.Path]::GetRelativePath((Get-Location).Path,$file.FullName).Replace('\','/');$repoMounts+=@('--mount',"type=bind,source=$($file.FullName),target=/repo/$relative,readonly")}
foreach($root in @('package.json','package-lock.json','tsconfig.json')){$repoMounts+=@('--mount',"type=bind,source=$((Resolve-Path $root).Path),target=/repo/$root,readonly")}
$appMounts=@(foreach($root in @('apps/worker/src','apps/api/src','packages/shared/src','prisma')){'--mount';"type=bind,source=$((Resolve-Path $root).Path),target=/app/$root,readonly"})
foreach($file in $files|Where-Object{$_.FullName -match '[\\/]apps[\\/]media[\\/]src[\\/]'}){$rel=[IO.Path]::GetRelativePath((Get-Location).Path,$file.FullName).Replace('\','/');$appMounts+=@('--mount',"type=bind,source=$($file.FullName),target=/app/$rel,readonly")}
$appMounts+=@('--mount',"type=bind,source=$((Resolve-Path apps/media/src/media_adapter.py).Path),target=/app/infra/media_adapter.py,readonly")
function Create([string]$role,[string]$network,[string]$command){
 $proxy=$role -in @('broker','proxy');$mem=if($proxy){'96m'}else{'512m'};$cpu=if($proxy){'0.25'}else{'0.75'};$user=if($proxy){'65534:65534'}else{'1000:1000'};$image=if($proxy){$proxyImage}else{$appImage};$pids=if($role -eq 'broker'){'64'}elseif($proxy){'96'}else{'160'}
 $extra=if($proxy){@('-e','PYTHONPATH=/repo/apps/egress/src:/repo/apps/egress/vendor:/fixture','-e','EGRESS_STEP3_FIXTURE=1','-e',"TIKTOK_EGRESS_CONTROL_NETWORKS=$controlSubnet")}
 else{@('-e','PYTHONPATH=/fixture:/app/apps/media/src','-e','MEDIA_ROOT=/media','-e','MEDIA_PROXY=http://egress:8888','-e','NODE_OPTIONS=--max-old-space-size=128','-e','DATABASE_URL=postgresql://gate_fixture:lab-public-only-password@postgres:5432/photo_gate_fixture','-e','REDIS_URL=redis://redis:6379/7','-e','TIKTOK_PHOTO_ENABLED=1','-e','TIKTOK_ADAPTER_ENABLED=1','-e','VERIFIED_PLATFORMS=tiktok,youtube','--tmpfs','/media:size=64m,uid=1000,gid=1000,nosuid,noexec','--tmpfs','/app/node_modules/.prisma:size=64m,uid=1000,gid=1000,nosuid,exec')+$appMounts}
 if($role -eq 'proxy'){$extra+=@('--network-alias','egress')}
 Native "create-$role" (@('create','--pull=never','--label',"com.wed-snap.run=$run",'--network',$network,'--ipc','private','--read-only','--user',$user,'--memory',$mem,'--memory-swap',$mem,'--cpus',$cpu,'--pids-limit',$pids,'--cap-drop','ALL','--security-opt','no-new-privileges:true','--tmpfs','/tmp:size=32m,mode=1777,nosuid','-e','PYTHONDONTWRITEBYTECODE=1','-e','TIKTOK_EGRESS_POLICY_ENABLED=1','-e',"TIKTOK_EGRESS_CONTROL_SECRET=$phaseSecret")+$common+$repoMounts+$extra+@($image,'/usr/bin/timeout','--signal=KILL','360s','python3')+@($command -split ' '))
}
try{
 $controlSubnet='127.0.0.0/8'
 if($Mode -eq 'worker'){
  $gen=Create 'generate' 'none' '/fixture/generate.py generate';$ids+=,$gen;Native 'generate' @('start','-a',$gen)|Out-Null;Native 'remove-generator' @('rm',$gen)|Out-Null;$ids=@()
  $net=Native 'network-create' @('network','create','--internal','--label',"com.wed-snap.run=$run",("photo-egress-step3b-$run"));$nets+=,$net
  $n=@((Native 'network-guard' @('network','inspect',$net)|ConvertFrom-Json))[0];if(!$n.Internal){throw 'Internal required'};$controlSubnet=$n.IPAM.Config[0].Subnet
  $pg=Native 'create-db' @('create','--pull=never','--label',"com.wed-snap.run=$run",'--network',$net,'--network-alias','postgres','--read-only','--user','999:999','--memory','128m','--memory-swap','128m','--cpus','0.25','--pids-limit','64','--cap-drop','ALL','--security-opt','no-new-privileges:true','--tmpfs','/var/lib/postgresql/data:size=128m,uid=999,gid=999,nosuid','--tmpfs','/var/run/postgresql:size=8m,uid=999,gid=999,nosuid','--tmpfs','/tmp:size=8m,uid=999,gid=999,nosuid','-e','POSTGRES_DB=photo_gate_fixture','-e','POSTGRES_USER=gate_fixture','-e','POSTGRES_PASSWORD=lab-public-only-password','postgres:16.10-bookworm','postgres','-c','shared_buffers=16MB','-c','max_connections=20');$ids+=,$pg
  $redis=Native 'create-redis' @('create','--pull=never','--label',"com.wed-snap.run=$run",'--network',$net,'--network-alias','redis','--read-only','--user','1000:1000','--memory','64m','--memory-swap','64m','--cpus','0.25','--pids-limit','32','--cap-drop','ALL','--security-opt','no-new-privileges:true','--tmpfs','/data:size=8m,uid=1000,gid=1000,nosuid','redis:7.4.6-bookworm','redis-server','--save','','--appendonly','no','--maxmemory','32mb');$ids+=,$redis
  Native 'start-db' @('start',$pg,$redis)|Out-Null;Native 'db-ready' @('exec',$pg,'bash','-c','for i in {1..40}; do pg_isready -U gate_fixture -d photo_gate_fixture && exit 0; sleep .25; done; exit 1')|Out-Null
  $proxyID=Create 'proxy' $net '/fixture/proxy_service.py';$ids+=,$proxyID;Native 'start-proxy' @('start',$proxyID)|Out-Null
  $end=[DateTimeOffset]::UtcNow.AddSeconds(20);while(!(Test-Path "$ev/ready") -and [DateTimeOffset]::UtcNow -lt $end){Start-Sleep -Milliseconds 100};if(!(Test-Path "$ev/ready")){Native 'proxy-logs' @('logs',$proxyID)|Out-Null;throw 'Proxy not ready'}
  $app=Create 'worker' $net '/fixture/gate.py worker';$ids+=,$app
 }else{$app=Create $Mode 'none' "/fixture/gate.py $Mode";$ids+=,$app}
 foreach($id in $ids){$g=@((Native 'guard' @('inspect',$id)|ConvertFrom-Json))[0];if($g.Config.Labels.'com.wed-snap.run' -cne $run -or !$g.HostConfig.ReadonlyRootfs -or $g.HostConfig.Privileged -or $g.HostConfig.CapAdd -or $g.HostConfig.CapDrop -notcontains 'ALL' -or $g.HostConfig.SecurityOpt -notcontains 'no-new-privileges:true' -or $g.HostConfig.MemorySwap -ne $g.HostConfig.Memory -or @($g.HostConfig.PortBindings.PSObject.Properties).Count){throw 'Guard failed'};Scrub ($g|ConvertTo-Json -Depth 40)|Set-Content "$ev/guard-$id.json"}
 Native 'test' @('start','-a',$app)|Out-Null
 foreach($id in $ids){$s=@((Native 'state' @('inspect',$id)|ConvertFrom-Json))[0];if($s.State.OOMKilled){throw 'OOM'}}
 if($Mode -eq 'worker'){$exit=Native 'proxy-wait' @('wait',$proxyID);Native 'proxy-logs' @('logs',$proxyID)|Out-Null;if($exit -cne '33'){throw 'Expected deliberate final proxy crash33'}}
 foreach($r in $hashes){if((Get-FileHash $r.path).Hash.ToLowerInvariant() -cne $r.sha256){throw 'Source changed'}}
 foreach($r in $tests){if((Get-FileHash "labs/tiktok/photo-egress-step3b/$($r.path)").Hash.ToLowerInvariant() -cne $r.sha256){throw 'Fixture changed'}}
 @{status='PASS_OFFLINE_ONLY';mode=$Mode;actualExit=0;sourceCalls=0;utc=[DateTimeOffset]::UtcNow.ToString('o');vn=[DateTimeOffset]::UtcNow.ToOffset([TimeSpan]::FromHours(7)).ToString('o')}|ConvertTo-Json|Set-Content "$ev/completion.json"
}finally{
 if($proxyID){[IO.File]::WriteAllText((Join-Path (Resolve-Path $ev).Path 'stop'),'stop')}
 foreach($id in $ids){$g=@((Native 'cleanup-owner' @('inspect',$id)|ConvertFrom-Json))[0];if($g.Config.Labels.'com.wed-snap.run' -cne $run){throw 'Owner mismatch'};Native 'remove-own' @('rm','-f',$id)|Out-Null}
 foreach($id in $nets){Native 'remove-network' @('network','rm',$id)|Out-Null}
 $left=Native 'absent' @('ps','-aq','--filter',"label=com.wed-snap.run=$run");if($left){throw 'Owned resources remain'}
 @{containers=$ids;networks=$nets;generatorRemoved=$gen;ownResourcesLeft=0;volumesCreated=0;run=$run}|ConvertTo-Json|Set-Content "$ev/cleanup.json"
}
