param([string]$PythonPath='C:/Users/LENOVO/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe')
. (Join-Path $PSScriptRoot 'integration.ps1')
$ErrorActionPreference='Stop'
Set-Location 'D:\WED SNAP'
$ev='docs/evidence/ui-combined-offline-20261016/runtime'
if(Test-Path -LiteralPath $ev){throw 'REFUSE_REUSE'}
if(Get-NetTCPConnection -State Listen -LocalPort 5206 -ErrorAction SilentlyContinue){throw 'GATEWAY_PORT_BUSY'}
New-Item -ItemType Directory -Path $ev|Out-Null
$run=[Guid]::NewGuid().ToString('N');$ids=@();$nets=@();$proxyID=$null;$gen=$null;$cleanupDeadline=$null
$phaseSecret=[Convert]::ToHexString([Security.Cryptography.RandomNumberGenerator]::GetBytes(32)).ToLowerInvariant()
$adminSecret=[Convert]::ToHexString([Security.Cryptography.RandomNumberGenerator]::GetBytes(32)).ToLowerInvariant()
$proxyImage='sha256:8bc0a567955111ea3cfbab2dd3b14f40a602f2d10ac987e78eb465f9d48d7f10';$appImage='sha256:d4558b29dd379b16d4906fb9e618dfc4d045e3008a70e031ea3474b7b2218e4e'
$pgImage='sha256:38471f330eb885e04de130b768d6db4e10469e2311879c7e5c699f6d2d8a1c74';$redisImage='sha256:a9cc41d6d01da2aa26c219e4f99ecbeead955a7b656c1c499cce8922311b2514'
$deadline=[DateTimeOffset]::UtcNow.AddSeconds(480)
function Scrub([string]$value){$value.Replace($adminSecret,'[admin-secret-redacted]').Replace($phaseSecret,'[control-secret-redacted]')}
function Native([string]$step,[string[]]$argv){
 $at=[DateTimeOffset]::UtcNow;$until=if($cleanupDeadline){$cleanupDeadline}else{$deadline.AddSeconds(-21)};$wait=[int][Math]::Floor([Math]::Min(30000,($until-$at).TotalMilliseconds));if($wait -le 0){throw 'NATIVE_DEADLINE'}
 $info=[Diagnostics.ProcessStartInfo]::new('docker');$info.UseShellExecute=$false;$info.CreateNoWindow=$true;$info.RedirectStandardOutput=$true;$info.RedirectStandardError=$true;foreach($a in $argv){$info.ArgumentList.Add($a)}
 $p=[Diagnostics.Process]::new();$p.StartInfo=$info
 try{if(!$p.Start()){throw 'NATIVE_START'};$o=$p.StandardOutput.ReadToEndAsync();$e=$p.StandardError.ReadToEndAsync();$timeout=!$p.WaitForExit($wait);if($timeout){$p.Kill($true);$p.WaitForExit(1000)|Out-Null};$text=$o.GetAwaiter().GetResult()+$e.GetAwaiter().GetResult();$code=if($p.HasExited){$p.ExitCode}else{$null}
  if($text.Length -gt 1048576){$text='OUTPUT_CAP';$timeout=$true}
  Scrub (@{step=$step;arguments=$argv;actualExit=$code;timedOut=$timeout;waitMs=$wait;utcStart=$at.ToString('o');utcEnd=[DateTimeOffset]::UtcNow.ToString('o');output=$text}|ConvertTo-Json -Depth 8 -Compress)|Add-Content -LiteralPath "$ev/native.jsonl"
  if($timeout -or $code -ne 0){throw 'NATIVE_FAILED'};return $text.Trim()
 }finally{$p.Dispose()}
}
$success=$false;$cleanupOK=$true
try{
 $offline=Get-Content docs/evidence/ui-combined-offline-20261016/preflight.json -Raw|ConvertFrom-Json
 if($offline.filesystemActualExit -ne 0 -or $offline.filesystemCases -ne 8 -or $offline.historicalPinCount -ne 164 -or @($offline.historicalMismatch).Count){throw 'OFFLINE_GATE'}
 foreach($pin in $offline.implementation){if((Get-FileHash -LiteralPath $pin.path).Hash.ToLowerInvariant() -cne $pin.sha256){throw 'OFFLINE_HASH_GATE'}}
 $handshakeRoot=(Resolve-Path $ev).Path
 $init=Invoke-BrowserHandshake 'init' $handshakeRoot @('--run-id',$run,'--deadline-utc',$deadline.ToString('o'));if($init.actualExit -ne 0){throw 'HANDSHAKE_INIT'}
 foreach($image in @($appImage,$proxyImage,$pgImage,$redisImage)){$seen=Native 'cache-inspect' @('image','inspect',$image,'--format','{{.Id}}');if($seen -cne $image){throw 'IMAGE_ID'}}
 $manifest=Get-Content docs/evidence/ui-a-app-integration-20261016/manifest.json -Raw|ConvertFrom-Json
 $build=@(foreach($name in @('index.html','assets/index-UOIc8eun.js','assets/index-DCfw3VbE.css')){$path='docs/evidence/ui-a-app-integration-20261016/build/web/'+$name;$pin=@($manifest.artifacts|Where-Object path -CEQ $path);if($pin.Count -ne 1 -or (Get-FileHash -LiteralPath $path).Hash.ToLowerInvariant() -cne $pin[0].sha256){throw 'BUILD_HASH'};Get-Item -LiteralPath $path})
 $index=[IO.File]::ReadAllText($build[0].FullName);if(!$index.Contains('/assets/index-UOIc8eun.js') -or !$index.Contains('/assets/index-DCfw3VbE.css') -or $index -match '(?i)(src|href)=["''](?:https?:|//)'){throw 'BUILD_ORIGIN'}
 $files=@(foreach($root in @('apps/web','apps/egress','apps/media/src','apps/worker/src','apps/api/src','packages/shared/src','prisma','labs/tiktok/photo-app-source-executor','labs/tiktok/ui-backend-offline','labs/tiktok/ui-combined-offline')){Get-ChildItem -LiteralPath $root -File -Recurse|Where-Object{$_.FullName -notmatch '[\\/](node_modules|__pycache__|dist)[\\/]'}})+@(Get-Item package.json,package-lock.json,tsconfig.json,labs/tiktok/photo-dns-diagnostics-fix/proxy_collect.py)+$build
 $pins=@($files|Sort-Object FullName -Unique|ForEach-Object{@{path=[IO.Path]::GetRelativePath((Get-Location).Path,$_.FullName).Replace('\','/');sha256=(Get-FileHash -LiteralPath $_.FullName).Hash.ToLowerInvariant()}})
 $pins|ConvertTo-Json|Set-Content -LiteralPath "$ev/expected-source.json"
 foreach($pin in $pins|Where-Object path -Like 'apps/web/*'){$rel=$pin.path.Substring(9);$old='docs/evidence/ui-a-app-integration-20261016/source-final/web/'+$rel;if(!(Test-Path -LiteralPath $old) -or (Get-FileHash -LiteralPath $old).Hash.ToLowerInvariant() -cne $pin.sha256){throw 'CURRENT_UI_HASH'}}
 $common=@('--mount',"type=bind,source=$((Resolve-Path labs/tiktok/photo-app-source-executor/common).Path),target=/lab,readonly",'--mount',"type=bind,source=$((Resolve-Path labs/tiktok/photo-app-source-executor/offline).Path),target=/offline,readonly",'--mount',"type=bind,source=$((Resolve-Path labs/tiktok/ui-combined-offline).Path),target=/newlab,readonly",'--mount',"type=bind,source=$((Resolve-Path labs/tiktok/photo-dns-diagnostics-fix/proxy_collect.py).Path),target=/lab/proxy_collect.py,readonly",'--mount',"type=bind,source=$((Resolve-Path $ev).Path),target=/control")
 $common+=@('--mount',"type=bind,source=$((Resolve-Path labs/tiktok/ui-backend-offline/start.sh).Path),target=/newlab/start.sh,readonly",'--mount',"type=bind,source=$((Resolve-Path labs/tiktok/ui-backend-offline/sitecustomize.py).Path),target=/newlab/sitecustomize.py,readonly")
 $repoMounts=@(foreach($root in @('apps/egress','apps/web','apps/media/src','apps/worker/src','apps/api/src','packages/shared/src','prisma','labs/tiktok/photo-app-source-executor','labs/tiktok/ui-backend-offline','labs/tiktok/ui-combined-offline')){'--mount';"type=bind,source=$((Resolve-Path $root).Path),target=/repo/$root,readonly"})
 foreach($file in @('package.json','package-lock.json','tsconfig.json','labs/tiktok/photo-dns-diagnostics-fix/proxy_collect.py')){$repoMounts+=@('--mount',"type=bind,source=$((Resolve-Path $file).Path),target=/repo/$file,readonly")}
 foreach($file in $build){$rel=[IO.Path]::GetRelativePath((Get-Location).Path,$file.FullName).Replace('\','/');$repoMounts+=@('--mount',"type=bind,source=$($file.FullName),target=/repo/$rel,readonly")}
 $appMounts=@(foreach($root in @('apps/web','apps/media/src','apps/worker/src','apps/api/src','packages/shared/src','prisma')){'--mount';"type=bind,source=$((Resolve-Path $root).Path),target=/app/$root,readonly"})
 $appMounts+=@('--mount',"type=bind,source=$((Resolve-Path labs/tiktok/photo-app-source-executor/offline/media_entry.py).Path),target=/app/infra/media_adapter.py,readonly",'--mount',"type=bind,source=$((Resolve-Path docs/evidence/ui-a-app-integration-20261016/build/web).Path),target=/build,readonly")
 function Create([string]$role,[string]$network,[string[]]$command){
  $proxy=$role -eq 'proxy';$image=if($proxy){$proxyImage}else{$appImage};$mem=if($proxy){'96m'}else{'512m'};$cpu=if($proxy){'0.25'}else{'0.75'};$uid=if($proxy){'65534:65534'}else{'1000:1000'};$pids=if($proxy){'96'}else{'160'}
  $extra=if($proxy){@('--network-alias','egress','-e',"TIKTOK_EGRESS_CONTROL_NETWORKS=$controlSubnet",'-e','PYTHONPATH=/newlab:/offline:/repo/apps/egress/src:/repo/apps/egress/vendor','-e','STEP5_OFFLINE_DNS=1')}
  else{@('-e','PYTHONPATH=/app/apps/media/src','-e','MEDIA_ROOT=/media','-e','MEDIA_PROXY=http://egress:8888','-e','NODE_OPTIONS=--max-old-space-size=128','-e','DATABASE_URL=postgresql://gate_fixture:lab-public-only-password@postgres:5432/step5_executor','-e','REDIS_URL=redis://redis:6379/7','-e','APP_ORIGIN=http://127.0.0.1:5206','-e',"ADMIN_SESSION_SECRET=$adminSecret",'-e','TIKTOK_PHOTO_ENABLED=1','-e','TIKTOK_ADAPTER_ENABLED=1','-e','VERIFIED_PLATFORMS=tiktok,youtube','--tmpfs','/media:size=64m,uid=1000,gid=1000,nosuid,noexec','--tmpfs','/app/node_modules/.prisma:size=64m,uid=1000,gid=1000,nosuid,exec')+$appMounts}
  Native "create-$role" (@('create','--pull=never','--label',"com.wed-snap.run=$run",'--network',$network,'--ipc','private','--read-only','--user',$uid,'--memory',$mem,'--memory-swap',$mem,'--cpus',$cpu,'--pids-limit',$pids,'--cap-drop','ALL','--security-opt','no-new-privileges:true','--tmpfs','/tmp:size=32m,mode=1777,nosuid','-e','PYTHONDONTWRITEBYTECODE=1','-e','STEP5_OFFLINE_TEST=1','-e','TIKTOK_EGRESS_POLICY_ENABLED=1','-e',"TIKTOK_EGRESS_CONTROL_SECRET=$phaseSecret")+$common+$repoMounts+$extra+@($image)+$command)
 }
 $controlSubnet='127.0.0.0/8'
 $gen=Create 'generate' 'none' @('bash','-c','python3 /offline/generate.py generate && node /repo/labs/tiktok/ui-backend-offline/check.cjs && node --check /newlab/gateway.cjs');$ids+=,$gen
 Native 'generate-and-compile' @('start','-a',$gen)|Out-Null;Native 'remove-generator' @('rm',$gen)|Out-Null;$ids=@()
 $ingress=Native 'ingress-create' @('network','create','--driver','bridge','--label',"com.wed-snap.run=$run",("combined-ingress-$run"));$nets+=,$ingress
 $net=Native 'network-create' @('network','create','--internal','--label',"com.wed-snap.run=$run",("ui-backend-offline-$run"));$nets+=,$net
 $network=@((Native 'network-guard' @('network','inspect',$net)|ConvertFrom-Json))[0];if(!$network.Internal){throw 'NETWORK_GUARD'};$controlSubnet=$network.IPAM.Config[0].Subnet
 $pg=Native 'create-db' @('create','--pull=never','--label',"com.wed-snap.run=$run",'--network',$net,'--network-alias','postgres','--read-only','--user','999:999','--memory','128m','--memory-swap','128m','--cpus','0.25','--pids-limit','64','--cap-drop','ALL','--security-opt','no-new-privileges:true','--tmpfs','/var/lib/postgresql/data:size=128m,uid=999,gid=999,nosuid','--tmpfs','/var/run/postgresql:size=8m,uid=999,gid=999,nosuid','--tmpfs','/tmp:size=8m,uid=999,gid=999,nosuid','-e','POSTGRES_DB=step5_executor','-e','POSTGRES_USER=gate_fixture','-e','POSTGRES_PASSWORD=lab-public-only-password',$pgImage,'postgres','-c','shared_buffers=16MB','-c','max_connections=20');$ids+=,$pg
 $redis=Native 'create-redis' @('create','--pull=never','--label',"com.wed-snap.run=$run",'--network',$net,'--network-alias','redis','--read-only','--user','1000:1000','--memory','64m','--memory-swap','64m','--cpus','0.25','--pids-limit','32','--cap-drop','ALL','--security-opt','no-new-privileges:true','--tmpfs','/data:size=8m,uid=1000,gid=1000,nosuid',$redisImage,'redis-server','--save','','--appendonly','no','--maxmemory','32mb');$ids+=,$redis
 Native 'start-db' @('start',$pg,$redis)|Out-Null;Native 'db-ready' @('exec',$pg,'bash','-c','for i in {1..40}; do pg_isready -U gate_fixture -d step5_executor && exit 0; sleep .25; done; exit 1')|Out-Null
 $proxyID=Create 'proxy' $net @('/usr/bin/timeout','--signal=KILL','340s','python3','-I','/offline/proxy.py');$ids+=,$proxyID;Native 'start-proxy' @('start',$proxyID)|Out-Null
 $until=[DateTimeOffset]::UtcNow.AddSeconds(20);while(!(Test-Path "$ev/ready") -and [DateTimeOffset]::UtcNow -lt $until){Start-Sleep -Milliseconds 100};if(!(Test-Path "$ev/ready")){throw 'PROXY_START'}
 $app=Create 'app' $net @('/usr/bin/timeout','--signal=KILL','340s','python3','-I','/repo/labs/tiktok/ui-backend-offline/entry.py');$ids+=,$app
 $memory=0
 foreach($id in $ids){$g=@((Native 'guard' @('inspect',$id)|ConvertFrom-Json))[0];$memory+=$g.HostConfig.Memory
  if($g.Config.Labels.'com.wed-snap.run' -cne $run -or !$g.HostConfig.ReadonlyRootfs -or $g.HostConfig.Privileged -or $g.HostConfig.CapAdd -or $g.HostConfig.CapDrop -notcontains 'ALL' -or $g.HostConfig.SecurityOpt -notcontains 'no-new-privileges:true' -or $g.HostConfig.MemorySwap -ne $g.HostConfig.Memory -or @($g.NetworkSettings.Networks.PSObject.Properties).Count -ne 1){throw 'GUARD'}
  $ports=@($g.HostConfig.PortBindings.PSObject.Properties);if($ports.Count){throw 'PRIVATE_PORT'}
  Scrub ($g|ConvertTo-Json -Depth 40)|Set-Content -LiteralPath "$ev/guard-$id.json"
 };if($memory -gt 1GB){throw 'MEMORY_GUARD'}
 @{totalMemoryBytes=$memory;containerRuntimeMiB=$memory/1MB;sourceRequests=0;publicDNSQueries=0;claimsCreated=0;networkInternal=$true;gatewayOrigin='http://127.0.0.1:5206';outsideOriginInterception='UNAVAILABLE';blockedOutsideOriginCount='UNKNOWN'}|ConvertTo-Json|Set-Content "$ev/backend-topology.json"
 Native 'start-app' @('start',$app)|Out-Null
 $until=[DateTimeOffset]::UtcNow.AddSeconds(60);while(!(Test-Path "$ev/backend.ready") -and !(Test-Path "$ev/result.json") -and [DateTimeOffset]::UtcNow -lt $until){Start-Sleep -Milliseconds 100};if(!(Test-Path "$ev/backend.ready")){Native 'app-logs' @('logs',$app)|Out-Null;throw 'BROWSER_START'}

 $appState=@((Native 'app-ip' @('inspect',$app)|ConvertFrom-Json))[0];$route=@($appState.NetworkSettings.Networks.PSObject.Properties|Where-Object{$_.Value.NetworkID -ceq $net});if($route.Count -ne 1){throw 'API_IP'};$apiIP=$route[0].Value.IPAddress
 $gateway=Native 'create-gateway' @('create','--pull=never','--label',"com.wed-snap.run=$run",'--network',$ingress,'--ipc','private','--read-only','--user','1000:1000','--memory','128m','--memory-swap','128m','--cpus','0.25','--pids-limit','48','--cap-drop','ALL','--security-opt','no-new-privileges:true','--tmpfs','/tmp:size=8m,nosuid','-p','127.0.0.1:5206:5206','-e','STEP5_OFFLINE_TEST=1','-e',"API_IPV4=$apiIP",'-e','NODE_OPTIONS=--max-old-space-size=64','--mount',"type=bind,source=$((Resolve-Path labs/tiktok/ui-combined-offline).Path),target=/newlab,readonly",'--mount',"type=bind,source=$((Resolve-Path docs/evidence/ui-a-app-integration-20261016/build/web).Path),target=/build,readonly",'--mount',"type=bind,source=$((Resolve-Path $ev).Path),target=/control",$appImage,'node','/newlab/gateway.cjs');$ids+=,$gateway
 Native 'gateway-connect-internal' @('network','connect',$net,$gateway)|Out-Null
 $g=@((Native 'gateway-guard' @('inspect',$gateway)|ConvertFrom-Json))[0];$ports=@($g.HostConfig.PortBindings.PSObject.Properties)
 if($g.Config.User -cne '1000:1000' -or !$g.HostConfig.ReadonlyRootfs -or $g.HostConfig.Privileged -or $g.HostConfig.CapAdd -or $g.HostConfig.CapDrop -notcontains 'ALL' -or $g.HostConfig.SecurityOpt -notcontains 'no-new-privileges:true' -or $g.HostConfig.Memory -ne 128MB -or $g.HostConfig.MemorySwap -ne 128MB -or @($g.NetworkSettings.Networks.PSObject.Properties).Count -ne 2 -or $ports.Count -ne 1 -or $ports[0].Value[0].HostIp -cne '127.0.0.1' -or $ports[0].Value[0].HostPort -cne '5206'){throw 'GATEWAY_GUARD'}
 $g|ConvertTo-Json -Depth 40|Set-Content "$ev/guard-gateway.json";$memory+=128MB
 @{containerRuntimeMiB=$memory/1MB;ceilingMiB=1024;measuredPeakMiB='UNKNOWN';internalNetwork=$net;ingressNetwork=$ingress;fixedAPIIPv4=$apiIP;apiPort=3000;published='127.0.0.1:5206';sourceRequests=0;publicDNSQueries=0;claimsCreated=0;outsideOriginInterception='UNAVAILABLE';blockedOutsideOriginCount='UNKNOWN'}|ConvertTo-Json|Set-Content "$ev/topology.json"
 if($memory -gt 1GB){throw 'TOTAL_MEMORY'};Native 'start-gateway' @('start',$gateway)|Out-Null
 $until=[DateTimeOffset]::UtcNow.AddSeconds(10);while(!(Test-Path "$ev/browser.ready") -and [DateTimeOffset]::UtcNow -lt $until){Start-Sleep -Milliseconds 100};if(!(Test-Path "$ev/browser.ready")){throw 'GATEWAY_START'}
 $client=[Net.Http.HttpClient]::new();$client.Timeout=[TimeSpan]::FromSeconds(5)
 try{$r=$client.GetAsync('http://127.0.0.1:5206/api/v1/health').GetAwaiter().GetResult();$status=[int]$r.StatusCode;$r.Content.ReadAsByteArrayAsync().GetAwaiter().GetResult()|Out-Null;$r.Dispose();@{status=$status;stage='HOST_BEFORE_BROWSER_ANALYZE';utc=[DateTimeOffset]::UtcNow.ToString('o')}|ConvertTo-Json|Set-Content "$ev/host-ready.json";if($status -ne 200){throw 'HOST_READINESS'}}finally{$client.Dispose()}
 Write-Output 'BROWSER_READY http://127.0.0.1:5206'
 $decision=Wait-BrowserHandshake $handshakeRoot
 if($decision.actualExit -ne 0){[IO.File]::WriteAllText("$handshakeRoot/browser-abort",'abort');throw 'BROWSER_DECISION'}
 [IO.File]::WriteAllText("$handshakeRoot/browser-accepted",'accepted')
 while(!(Test-Path "$ev/result.json") -and [DateTimeOffset]::UtcNow -lt $deadline.AddSeconds(-21)){Start-Sleep -Milliseconds 100};if(!(Test-Path "$ev/result.json")){throw 'WORKFLOW_DEADLINE'}
 $exit=Native 'gateway-wait' @('wait',$gateway);Native 'gateway-logs' @('logs',$gateway)|Out-Null;if($exit -cne '0'){throw 'GATEWAY_NATIVE_EXIT'}
 $exit=Native 'app-wait' @('wait',$app);Native 'app-logs' @('logs',$app)|Out-Null;if($exit -cne '0'){throw 'APP_NATIVE_EXIT'}
 [IO.File]::WriteAllText((Join-Path (Resolve-Path $ev).Path 'stop'),'stop');$exit=Native 'proxy-wait' @('wait',$proxyID);if($exit -cne '0'){throw 'PROXY_NATIVE_EXIT'}
 foreach($id in $ids){$g=@((Native 'state' @('inspect',$id)|ConvertFrom-Json))[0];if($g.State.OOMKilled){throw 'OOM'}}
 $result=Get-Content "$ev/result.json" -Raw|ConvertFrom-Json;if($result.status -cne 'PASS_UI_BACKEND_FIXTURE_OFFLINE'){throw 'WORKFLOW_FAIL'}
 $fixtureCounts=Get-Content "$ev/counts.json" -Raw|ConvertFrom-Json;if($fixtureCounts.metadata -ne 4 -or $fixtureCounts.JPEG -ne 1){throw 'FIXTURE_BUDGET'}
 $dns=@(Get-Content "$ev/fixture-dns.jsonl"|ForEach-Object{$_|ConvertFrom-Json});if(!$dns.Count -or @($dns|Where-Object {$_.event -cne 'FIXTURE_DNS' -or $_.publicQueries -ne 0}).Count){throw 'FIXTURE_DNS'}
 foreach($pin in $pins){if((Get-FileHash -LiteralPath $pin.path).Hash.ToLowerInvariant() -cne $pin.sha256){throw 'SOURCE_CHANGED'}}
 $success=$true
}catch{
 @{status='FAIL_STOPPED';code=$(if($_.Exception.Message -cmatch '^[A-Z_]{1,60}$'){$_.Exception.Message}else{'ORCHESTRATOR_ERROR'});utc=[DateTimeOffset]::UtcNow.ToString('o')}|ConvertTo-Json|Set-Content "$ev/orchestrator-error.json"
}finally{
 $at=[DateTimeOffset]::UtcNow;$cleanupDeadline=$at.AddSeconds(20);if($cleanupDeadline -gt $deadline.AddSeconds(-1)){$cleanupDeadline=$deadline.AddSeconds(-1)}
 if(!$success -and (Test-Path -LiteralPath $ev)){[IO.File]::WriteAllText((Join-Path (Resolve-Path $ev).Path 'browser-abort'),'abort')}

 if($proxyID){[IO.File]::WriteAllText((Join-Path (Resolve-Path $ev).Path 'stop'),'stop')}
 foreach($id in $ids){try{$g=@((Native 'cleanup-owner' @('inspect',$id)|ConvertFrom-Json))[0];if($g.Config.Labels.'com.wed-snap.run' -cne $run){throw 'OWNER'};Native 'remove-own' @('rm','-f',$id)|Out-Null}catch{$cleanupOK=$false}}
 foreach($id in $nets){try{$g=@((Native 'network-owner' @('network','inspect',$id)|ConvertFrom-Json))[0];if($g.Labels.'com.wed-snap.run' -cne $run){throw 'OWNER'};Native 'remove-network' @('network','rm',$id)|Out-Null}catch{$cleanupOK=$false}}
 try{$left=Native 'absent' @('ps','-aq','--filter',"label=com.wed-snap.run=$run");$netLeft=Native 'networks-absent' @('network','ls','-q','--filter',"label=com.wed-snap.run=$run");if($left -or $netLeft){$cleanupOK=$false}}catch{$cleanupOK=$false}
 @{run=$run;containers=$ids;networks=$nets;generator=$gen;ownResourcesLeft=$(if($cleanupOK){0}else{'UNKNOWN'});cleanupElapsedSeconds=([DateTimeOffset]::UtcNow-$at).TotalSeconds;cleanupLimitSeconds=20}|ConvertTo-Json -Depth 4|Set-Content "$ev/cleanup.json"
 $final=Complete-BrowserHandshake $handshakeRoot $(if($cleanupOK){'CLOSED'}else{'UNKNOWN'}) $(if($success){'PASS'}else{'FAIL'});if($final.actualExit -ne 0){$success=$false}
}
if(!$success -or !$cleanupOK){exit 1}
