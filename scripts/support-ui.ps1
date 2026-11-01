# Real UI/API/PG/Redis, one disposable loopback namespace. No image build/source.
param([ValidateSet('Start','Stop','Watchdog')][string]$Action='Start',[string]$Receipt,
 [ValidateRange(1024,65535)][int]$Port=5202,[string]$UiPath)
$ErrorActionPreference='Stop';$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$docker='C:\Program Files\Docker\Docker\resources\bin\docker.exe'
$appImage='sha256:5b994d8c9c4ed29ce550f0d60539a8071a2f2e233d9c840013c45802c08a7ba3'
$pgImage='sha256:38471f330eb885e04de130b768d6db4e10469e2311879c7e5c699f6d2d8a1c74'
$redisImage='sha256:a9cc41d6d01da2aa26c219e4f99ecbeead955a7b656c1c499cce8922311b2514'
function Native([string]$step,[string[]]$argv,[bool]$required=$true){
 $start=[DateTime]::UtcNow;$result=(& $docker @argv 2>&1|Out-String);$exit=$LASTEXITCODE
 @{step=$step;actualExit=$exit;utcStart=$start.ToString('o');utcEnd=[DateTime]::UtcNow.ToString('o');output=$result}|ConvertTo-Json -Compress|Add-Content -LiteralPath (Join-Path $out 'native.jsonl')
 if($required -and $exit){throw ('SUPPORT_UI_'+$step+'_EXIT_'+$exit)}
 return @{output=$result.Trim();exit=$exit}
}
if($Action -ne 'Start'){
 $Receipt=[IO.Path]::GetFullPath($Receipt);$out=Split-Path $Receipt -Parent
 if((Split-Path $out -Parent) -cne (Join-Path $root 'lab-runs') -or (Split-Path $out -Leaf) -notmatch '^support-ui-real-20261101-[a-f0-9]{32}$' -or (Split-Path $Receipt -Leaf) -cne 'receipt.json'){throw 'RECEIPT_OWNERSHIP'}
 $r=Get-Content -LiteralPath $Receipt -Raw|ConvertFrom-Json -DateKind String
 if($Action -eq 'Watchdog'){
  $delay=([DateTimeOffset]::Parse($r.cleanupDeadlineUtc)-[DateTimeOffset]::UtcNow).TotalSeconds
  if($delay -gt 0 -and $delay -lt 2000){Start-Sleep -Seconds ([int][math]::Ceiling($delay))}
 }
 if(Test-Path -LiteralPath (Join-Path $out 'cleanup.json')){return}
 foreach($cid in @($r.web,$r.api,$r.redis,$r.pg)|Where-Object {$_}){
  if($cid -notmatch '^[a-f0-9]{64}$'){throw 'CID'}
  $owner=(Native 'cleanup-owner' @('inspect',$cid,'--format','{{index .Config.Labels "com.wed-snap.support-ui"}}')).output
  if($owner -cne $r.run){throw 'CLEANUP_OWNER'}
  if($cid -eq $r.api -or $cid -eq $r.web){Native 'app-logs' @('logs','--tail','100',$cid) $false|Out-Null}
  Native 'remove-own' @('rm','-f',$cid)|Out-Null
 }
 foreach($net in @($r.frontNetwork,$r.network)|Where-Object {$_}){
  $owner=(Native 'network-owner' @('network','inspect',$net,'--format','{{index .Labels "com.wed-snap.support-ui"}}')).output
  if($owner -cne $r.run){throw 'NETWORK_OWNER'};Native 'remove-network' @('network','rm',$net)|Out-Null
 }
 $left=(Native 'absence' @('ps','-aq','--filter',('label=com.wed-snap.support-ui='+$r.run))).output
 $nets=(Native 'network-absence' @('network','ls','-q','--filter',('label=com.wed-snap.support-ui='+$r.run))).output
 if($left -or $nets){throw 'RESOURCES_LEFT'}
 $access=Join-Path $out 'operator-access.json';if(Test-Path -LiteralPath $access){Remove-Item -LiteralPath $access -Force}
 @{utc=[DateTime]::UtcNow.ToString('o');ownResourcesLeft=0;operatorAccessRemoved=$true;sourceRequests=0}|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $out 'cleanup.json')
 Write-Output ('SUPPORT_UI_CLEANED '+$out);return
}
$run=[guid]::NewGuid().ToString('N');$out=Join-Path $root ('lab-runs\support-ui-real-20261101-'+$run)
New-Item -ItemType Directory -Path $out|Out-Null
# Operator credentials inherit a private ACL in this owned disposable directory.
$acl=Get-Acl -LiteralPath $out;$acl.SetAccessRuleProtection($true,$false)
foreach($sid in @([Security.Principal.WindowsIdentity]::GetCurrent().User,[Security.Principal.SecurityIdentifier]::new('S-1-5-18'))){
 $acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new($sid,'FullControl','ContainerInherit,ObjectInherit','None','Allow'))
}
Set-Acl -LiteralPath $out -AclObject $acl
$probe=[Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback,$Port)
try{$probe.Start()}finally{$probe.Stop()}
$Receipt=Join-Path $out 'receipt.json';$prefix='ws-support-ui-'+$run
$r=@{run=$run;url=('http://127.0.0.1:'+$Port);pg=$null;redis=$null;api=$null;web=$null;network=$null;frontNetwork=$null;sourceRequests=0;createdUtc=[DateTime]::UtcNow.ToString('o');cleanupDeadlineUtc=[DateTime]::UtcNow.AddSeconds(1900).ToString('o')}
function SaveReceipt {$r|ConvertTo-Json|Set-Content -LiteralPath $Receipt}
$ui=if($UiPath){[IO.Path]::GetFullPath($UiPath)}else{Join-Path $root 'docs\evidence\support-page-admin-20261031\ui\web'}
if(!$ui.StartsWith($root+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase) -or !(Test-Path -LiteralPath (Join-Path $ui 'index.html'))){throw 'UI_ARTIFACT_PATH'}
$inputs=@('apps/api/src/app.module.ts','apps/api/src/controllers/support.controller.ts','apps/api/src/services/support-contract.ts','apps/api/src/services/support-image.ts','apps/api/src/services/support.service.ts','apps/api/src/security/support-upload.ts','tests/support-live.ts','scripts/support-ui.ps1')
@($inputs|ForEach-Object {@{path=$_;sha256=(Get-FileHash -LiteralPath (Join-Path $root $_)).Hash.ToLowerInvariant()}})|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $out 'source-pins.json')
@((@(Get-Item -LiteralPath (Join-Path $ui 'index.html'))+@(Get-ChildItem -LiteralPath (Join-Path $ui 'assets') -File))|ForEach-Object {@{name=$_.Name;bytes=$_.Length;sha256=(Get-FileHash -LiteralPath $_.FullName).Hash.ToLowerInvariant()}})|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $out 'ui-pins.json')
SaveReceipt
try{
 $r.network=(Native 'network-create' @('network','create','--internal','--label',('com.wed-snap.support-ui='+$run),$prefix)).output;SaveReceipt
 $r.frontNetwork=(Native 'frontend-network-create' @('network','create','--label',('com.wed-snap.support-ui='+$run),($prefix+'-front'))).output;SaveReceipt
 $r.pg=(Native 'pg-create' @('create','--name',($prefix+'-pg'),'--label',('com.wed-snap.support-ui='+$run),'--network',$prefix,'--network-alias','postgres','--user','999:999','--read-only','--cap-drop','ALL','--security-opt','no-new-privileges','--ipc','private','--memory','256m','--memory-swap','256m','--cpus','0.5','--pids-limit','64',
 '--tmpfs','/var/lib/postgresql/data:rw,nosuid,nodev,size=128m,uid=999,gid=999','--tmpfs','/var/run/postgresql:rw,nosuid,nodev,size=8m,uid=999,gid=999','--tmpfs','/tmp:rw,nosuid,nodev,size=8m,uid=999,gid=999',
 '--env','POSTGRES_USER=support_lab','--env','POSTGRES_DB=support_lab','--env','POSTGRES_PASSWORD=public-loopback-lab-only',$pgImage,'postgres','-c','shared_buffers=16MB','-c','max_connections=20')).output;SaveReceipt
 $r.redis=(Native 'redis-create' @('create','--name',($prefix+'-redis'),'--label',('com.wed-snap.support-ui='+$run),'--network',$prefix,'--network-alias','redis','--user','999:999','--read-only','--cap-drop','ALL','--security-opt','no-new-privileges','--ipc','private','--memory','96m','--memory-swap','96m','--cpus','0.25','--pids-limit','40',
 '--tmpfs','/data:rw,nosuid,nodev,size=16m,uid=999,gid=999',$redisImage,'redis-server','--save','','--appendonly','no','--maxmemory','32mb','--maxmemory-policy','noeviction')).output;SaveReceipt
 Native 'pg-start' @('start',$r.pg)|Out-Null;Native 'redis-start' @('start',$r.redis)|Out-Null
 $ready=$false;$end=[DateTime]::UtcNow.AddSeconds(25)
 while([DateTime]::UtcNow -lt $end){$check=Native 'pg-ready' @('exec',$r.pg,'pg_isready','-U','support_lab','-d','support_lab') $false;if(!$check.exit){$ready=$true;break};Start-Sleep -Milliseconds 500}
 if(!$ready){throw 'PG_DEADLINE'}
 $args=@('create','--name',($prefix+'-api'),'--label',('com.wed-snap.support-ui='+$run),'--network',$prefix,'--network-alias','api','--user','1000:1000','--read-only','--cap-drop','ALL','--security-opt','no-new-privileges','--ipc','private','--memory','384m','--memory-swap','384m','--cpus','0.75','--pids-limit','96',
 '--tmpfs','/tmp:rw,noexec,nosuid,nodev,size=32m,uid=1000,gid=1000','--env','TRUSTED_PROXY_HOSTS=web',
 '--env','SUPPORT_LIVE_GUARD=own-loopback-support-20261101','--env',('APP_ORIGIN='+$r.url),'--env',('SUPPORT_LIVE_PORT='+$Port),'--env','COOKIE_SECURE=false',
 '--env','DATABASE_URL=postgresql://support_lab:public-loopback-lab-only@postgres:5432/support_lab','--env','REDIS_URL=redis://redis:6379/0',
 '--env','ADMIN_SESSION_SECRET=support-loopback-only-signing-not-production-secret','--env','VERIFIED_PLATFORMS=',
 '--env','TIKTOK_ADAPTER_ENABLED=0','--env','TIKTOK_PHOTO_ENABLED=0','--env','TIKTOK_VIDEO_ENABLED=0','--env','TIKTOK_EGRESS_POLICY_ENABLED=0','--env','TIKTOK_PREVIEW_ENABLED=0',
 '--mount',('type=bind,source='+$out+',target=/out'),'--mount',('type=bind,source='+$ui+',target=/ui,readonly'))
 foreach($folder in @('apps/api/src','packages/shared/src')){$args+=@('--mount',('type=bind,source='+(Join-Path $root $folder)+',target=/app/'+$folder+',readonly'))}
 $args+=@('--mount',('type=bind,source='+(Join-Path $root 'tests/support-live.ts')+',target=/app/tests/support-live.ts,readonly'),$appImage,
 '/usr/bin/timeout','--signal=TERM','--kill-after=5s','1800s','sh','-ec','set -eu; node node_modules/prisma/build/index.js migrate deploy; exec node node_modules/tsx/dist/cli.mjs tests/support-live.ts')
 $r.api=(Native 'api-create' $args).output;SaveReceipt
 foreach($cid in @($r.api,$r.pg,$r.redis)){
  if($cid -notmatch '^[a-f0-9]{64}$'){throw 'CID'}
  $guard=(Native 'guard' @('inspect',$cid,'--format','{{json .HostConfig}}')).output|ConvertFrom-Json
  if(!$guard.ReadonlyRootfs -or $guard.Memory -le 0 -or $guard.Memory -ne $guard.MemorySwap -or $guard.CapDrop -notcontains 'ALL' -or $guard.Privileged -or $guard.NetworkMode -ne $prefix){throw 'GUARD'}
 }
 Native 'api-start' @('start',$r.api)|Out-Null
 $webArgs=@('create','--name',($prefix+'-web'),'--label',('com.wed-snap.support-ui='+$run),'--network',($prefix+'-front'),'--user','1000:1000','--read-only','--cap-drop','ALL','--security-opt','no-new-privileges','--ipc','private','--memory','128m','--memory-swap','128m','--cpus','0.25','--pids-limit','48','--publish',('127.0.0.1:'+$Port+':'+$Port),
 '--tmpfs','/tmp:rw,noexec,nosuid,nodev,size=32m,uid=1000,gid=1000','--env','NODE_OPTIONS=--max-old-space-size=80',
 '--mount',('type=bind,source='+$ui+',target=/ui,readonly'),'--mount',('type=bind,source='+(Join-Path $root 'apps/web/vite.config.ts')+',target=/app/apps/web/vite.config.ts,readonly'),
 $appImage,'/usr/bin/timeout','--signal=TERM','--kill-after=5s','1800s','node','node_modules/vite/bin/vite.js','preview','--config','apps/web/vite.config.ts','--configLoader','runner','--outDir','/ui','--host','0.0.0.0','--port',$Port.ToString(),'--strictPort')
 $r.web=(Native 'web-create' $webArgs).output;SaveReceipt
 Native 'web-private-connect' @('network','connect','--alias','web',$prefix,$r.web)|Out-Null
 Native 'web-start' @('start',$r.web)|Out-Null
 $ready=$false;$end=[DateTime]::UtcNow.AddSeconds(45)
 while([DateTime]::UtcNow -lt $end){
  try{$health=Invoke-WebRequest -Uri ($r.url+'/api/v1/health') -NoProxy -TimeoutSec 3;if($health.StatusCode -eq 200){$ready=$true;break}}
  catch{@{utc=[DateTime]::UtcNow.ToString('o');stage='loopback-health';exceptionClass=$_.Exception.GetType().Name;status=if($_.Exception.Response){[int]$_.Exception.Response.StatusCode}else{$null}}|ConvertTo-Json -Compress|Add-Content -LiteralPath (Join-Path $out 'readiness.jsonl')}
  Start-Sleep -Milliseconds 500
 }
 if(!$ready){
  Native 'start-logs' @('logs','--tail','40',$r.api)|Out-Null
  Native 'web-start-logs' @('logs','--tail','40',$r.web)|Out-Null
  Native 'internal-health' @('exec',$r.api,'node','-e',"fetch('http://127.0.0.1:3000/api/v1/health',{signal:AbortSignal.timeout(3000)}).then(async r=>console.log(JSON.stringify({status:r.status,body:await r.json()}))).catch(()=>process.exit(20))") $false|Out-Null
  Native 'port-binding' @('inspect',$r.web,'--format','{{json .NetworkSettings.Ports}}')|Out-Null
  throw 'API_READY_DEADLINE'
 }
 @{utc=[DateTime]::UtcNow.ToString('o');status=200;marker=$health.Headers['X-Wed-Support-Lab'];fakeAPI=$false;sourceDisabled=$true}|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $out 'ready.json')
 $pwsh=(Get-Process -Id $PID).Path
 $watchdog=Start-Process -FilePath $pwsh -WindowStyle Hidden -ArgumentList @('-NoProfile','-File',('"'+$PSCommandPath+'"'),'-Action','Watchdog','-Receipt',('"'+$Receipt+'"')) -PassThru
 $r.watchdogPid=$watchdog.Id;SaveReceipt
 Write-Output ('SUPPORT_UI_READY '+$r.url+' receipt='+$Receipt+' cleanupDeadline='+$r.cleanupDeadlineUtc)
}catch{
 & $PSCommandPath -Action Stop -Receipt $Receipt
 throw
}
