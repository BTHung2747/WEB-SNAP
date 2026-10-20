param([ValidateSet('Start','Matrix','Typecheck','Logs','Stop')][string]$Phase)
$ErrorActionPreference='Stop'
$labRoot=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
if((Get-Location).Path -ne $labRoot -or $labRoot -ne 'D:\WED SNAP'){throw 'Native repository required'}
$project='wed-snap-worker-shutdown-lab'
$argsLab=@('compose','-p',$project,'--project-directory',$labRoot,'--env-file','infra/worker-shutdown-lab.env.example','-f','infra/compose.worker-shutdown-lab.yaml')
$sources=@('apps/worker/src/main.ts','apps/worker/src/processor.ts','apps/worker/src/adapter.ts','apps/worker/src/lifecycle.ts','apps/worker/src/process-registry.ts','packages/shared/src/core.ts','prisma/schema.prisma','tests/p36/shutdown.ts','tests/p36/expected.json')
if(Test-Path apps/worker/src/ad-event-retention.ts){$sources+=@('apps/worker/src/ad-event-retention.ts')}
if(Test-Path apps/worker/src/worker-metrics-retention.ts){$sources+=@('apps/worker/src/worker-metrics-retention.ts','prisma/migrations/202610040001_worker_metrics_retention_index/migration.sql')}
$fingerprint=($sources|ForEach-Object{$_+':'+(Get-FileHash -LiteralPath $_).Hash.ToLowerInvariant()}) -join '|'
$algorithm=[Security.Cryptography.SHA256]::Create();$sourceSHA=([BitConverter]::ToString($algorithm.ComputeHash([Text.Encoding]::UTF8.GetBytes($fingerprint)))).Replace('-','').ToLowerInvariant();$algorithm.Dispose()
$oldSha=$env:WED_WORKER_SHUTDOWN_SHA
$pins=@{'wed-snap-p3-test:local'='sha256:f2a71e620a0c6a99261a184ad39352e4bbf26954e34ccb1cddcb25ffefa115f1';'postgres:16.10-bookworm'='sha256:38471f330eb885e04de130b768d6db4e10469e2311879c7e5c699f6d2d8a1c74';'redis:7.4.6-bookworm'='sha256:a9cc41d6d01da2aa26c219e4f99ecbeead955a7b656c1c499cce8922311b2514'}
$memory=@{lab=536870912;db=201326592;redis=100663296};$cpu=@{lab=.75;db=.5;redis=.25}
$pairs=@(@('apps/worker','/app/apps/worker'),@('packages/shared','/app/packages/shared'),@('prisma','/app/prisma'),@('tests/p36','/app/tests/p36'),@('tsconfig.json','/app/tsconfig.json'))
$commands=@{lab='node -e setInterval(() => {}, 60000)';db='postgres';redis='redis-server --appendonly yes --maxmemory 64mb --maxmemory-policy noeviction'}
function Call([string[]]$args34){
 Write-Host ('COMMAND docker '+($argsLab+$args34 -join ' '));$oldEap36=$ErrorActionPreference
 try{$ErrorActionPreference='Continue';& docker @argsLab @args34;$exit34=$LASTEXITCODE}finally{$ErrorActionPreference=$oldEap36}
 Write-Host ('P36_NATIVE_COMPLETION exit='+$exit34+' UTC='+[DateTime]::UtcNow.ToString('o')+' args='+($args34 -join ' '))
 if($exit34 -ne 0){throw 'Ownlab command failed; preserve raw/completion, no reset'}
}
function Decode([string[]]$text31){return @(($text31 -join "`n"|ConvertFrom-Json))[0]}
function Protect {
 $before36=Get-Content docs/evidence/p36-20261004-before.json -Raw|ConvertFrom-Json
 foreach($f36 in $before36.inventory){
  if($before36.allowedDocs -contains $f36.path){continue}
  $sha36=(Get-FileHash -LiteralPath $f36.path).Hash.ToLowerInvariant()
  if($sha36 -eq $f36.sha){continue}
  if($f36.path -ne 'apps/worker/src/main.ts'){throw ('Protected changed '+$f36.path)}
  $fix36=Get-Content docs/evidence/p36-20261004-fix.json -Raw|ConvertFrom-Json
  if($fix36.beforeSHA -ne $f36.sha -or $fix36.afterSHA -ne $sha36 -or -not $fix36.baselineProductionFailure -or (Get-FileHash docs/evidence/p36-20261004-baseline.log).Hash.ToLowerInvariant() -ne $fix36.baselineRawSHA){throw 'Only exact main fix proven by preserved baseline allowed'}
 }
 Write-Host ('PASS successor36 protected '+$before36.inventory.Count+' distinct paths, exact6docs/conditionalexactmain only; frozen19-35 unchanged')
}
function Actual {
 $ids31=@(& docker @argsLab ps -a -q);if($LASTEXITCODE -ne 0 -or $ids31.Count -ne 3){throw 'Exactly3 own containers required'}
 $net31=Decode (& docker network inspect ($project+'_lab'));if($LASTEXITCODE -ne 0 -or $net31.Labels.'com.docker.compose.project' -ne $project -or $net31.Driver -ne 'bridge' -or -not $net31.Internal -or @($net31.Containers.PSObject.Properties.Name|Where-Object{$_ -and $ids31 -notcontains $_}).Count){throw 'Foreign/noninternal network'}
 $script:containers=@{}
 foreach($svc31 in @('lab','db','redis')){
  $id31=@(& docker @argsLab ps -a -q $svc31);if($id31.Count -ne 1){throw 'Ambiguous identity'};$c31=Decode (& docker inspect $id31[0]);if($LASTEXITCODE -ne 0){throw 'Actual inspect failure'};$containers[$svc31]=$c31;$s31=$cfg.services.$svc31
  if($c31.Config.Labels.'com.docker.compose.project' -ne $project -or $c31.Config.Labels.'com.docker.compose.service' -ne $svc31 -or $c31.Image -ne $pins[$s31.image] -or $c31.Config.Image -ne $s31.image -or $c31.HostConfig.PidMode -ne '' -or $c31.HostConfig.Privileged -or -not $c31.HostConfig.ReadonlyRootfs -or ($c31.Config.Cmd -join ' ') -ne $commands[$svc31]){throw 'Actual image/project/PID/rootfs/cmd'}
  if($c31.HostConfig.Memory -ne $memory[$svc31] -or $c31.HostConfig.NanoCpus -ne [long]($cpu[$svc31]*1e9) -or $c31.HostConfig.PidsLimit -ne $(if($svc31 -eq 'lab'){192}elseif($svc31 -eq 'redis'){32}else{64})){throw 'Actual resources'}
  if(@($c31.NetworkSettings.Networks.PSObject.Properties).Count -ne 1 -or -not $c31.NetworkSettings.Networks.($project+'_lab') -or @($c31.HostConfig.PortBindings.PSObject.Properties).Count -or @($c31.HostConfig.VolumesFrom|Where-Object{$_}).Count){throw 'Foreign network/ports/volumesFrom'}
  foreach($env31 in $s31.environment.PSObject.Properties){if($c31.Config.Env -notcontains ($env31.Name+'='+$env31.Value)){throw 'Actual env/source mismatch'}}
  if(@($c31.Config.Env|Where-Object{$_ -match '^(HTTP_PROXY|HTTPS_PROXY|ALL_PROXY|POSTGRES_PASSWORD)='}).Count){throw 'Foreign proxy/password env'}
  if($svc31 -eq 'lab'){
   if($c31.Config.User -ne 'node' -or $c31.Config.WorkingDir -ne '/app' -or $c31.HostConfig.CapDrop -notcontains 'ALL' -or $c31.HostConfig.SecurityOpt -notcontains 'no-new-privileges:true'){throw 'App privileges'}
   $bind31=@($c31.Mounts|Where-Object Type -eq bind);if($bind31.Count -ne $pairs.Count -or @($c31.Mounts|Where-Object{$_.Type -notin @('bind','tmpfs')}).Count){throw 'Foreign source/data mount'}
   foreach($pair31 in $pairs){$p36=(Resolve-Path -LiteralPath $pair31[0]).Path.Replace('\','/');$desktop36='/run/desktop/mnt/host/d/'+$p36.Substring(3);$m31=@($bind31|Where-Object Destination -eq $pair31[1]);if($m31.Count -ne 1 -or $m31[0].RW -or @($p36,$desktop36) -notcontains $m31[0].Source.Replace('\','/')){throw 'Exact sourceRO required'}}
  }else{
   $v31=if($svc31 -eq 'db'){'retention_db'}else{'retention_redis'};$dest31=if($svc31 -eq 'db'){'/var/lib/postgresql/data'}else{'/data'};$vol31=@($c31.Mounts|Where-Object Type -eq volume)
   if($vol31.Count -ne 1 -or $vol31[0].Name -ne ($project+'_'+$v31) -or $vol31[0].Destination -ne $dest31 -or @($c31.Mounts|Where-Object{$_.Type -notin @('volume','tmpfs')}).Count){throw 'Foreign data volume'}
   $info31=Decode (& docker volume inspect $vol31[0].Name);if($LASTEXITCODE -ne 0 -or $info31.Labels.'com.docker.compose.project' -ne $project){throw 'Foreign volume label'}
  }
  if(@($c31.HostConfig.Tmpfs.PSObject.Properties).Count -ne @($s31.tmpfs).Count){throw 'Tmpfs count'}
  foreach($t31 in $s31.tmpfs){$target31=($t31 -split ':',2)[0];foreach($opt31 in (($t31 -split ':',2)[1] -split ',')){if(($c31.HostConfig.Tmpfs.$target31 -split ',') -notcontains $opt31){throw 'Tmpfs size/options not exact'}}}
  Write-Host ('PASS actual '+(@{project=$project;service=$svc31;id=$c31.Id;image=$c31.Image;state=$c31.State.Status;sourceRO=$true;pidPrivate=$true;rootfsRO=$true;memory=$c31.HostConfig.Memory;ports=0;cmd=$c31.Config.Cmd}|ConvertTo-Json -Compress))
 }
}
function Stores {
 $dbIP36=$containers.db.NetworkSettings.Networks.($project+'_lab').IPAddress;if($dbIP36 -notmatch '^\d+\.\d+\.\d+\.\d+$'){throw 'Actual numeric DB address'}
 $db31=((& docker @argsLab exec -T db psql -h $dbIP36 -U p36 -d wed_snap_worker_shutdown_test -Atc 'SELECT current_database()')-join '').Trim();if($LASTEXITCODE -ne 0 -or $db31 -ne 'wed_snap_worker_shutdown_test'){throw 'DB identity'}
 $ip36=((& docker @argsLab exec -T db psql -h $dbIP36 -U p36 -d wed_snap_worker_shutdown_test -Atc 'SELECT host(inet_server_addr())')-join '').Trim()
 if($LASTEXITCODE -ne 0 -or $ip36 -ne $dbIP36){throw 'DB numeric address mismatch'}
 $script:cluster=((& docker @argsLab exec -T db psql -h $dbIP36 -U p36 -d wed_snap_worker_shutdown_test -Atc 'SELECT system_identifier FROM pg_control_system()')-join '').Trim();if($LASTEXITCODE -ne 0 -or $cluster -notmatch '^\d+$'){throw 'DB cluster'}
 $ri31=(& docker @argsLab exec -T redis redis-cli -n 9 CLIENT INFO)-join '';if($LASTEXITCODE -ne 0 -or $ri31 -notmatch '\bdb=9\b'){throw 'Redis DB identity'}
 $server31=(& docker @argsLab exec -T redis redis-cli INFO server)-join "`n";if($LASTEXITCODE -ne 0 -or $server31 -notmatch 'run_id:([a-f0-9]{40})'){throw 'Redis run identity'};$script:run=$Matches[1]
 Write-Host 'PASS own database wed_snap_worker_shutdown_test cluster + Redis CLIENT INFO db9/run_id'
}
function Empty {
 $models31=@((Get-Content prisma/schema.prisma|Select-String '^model (\w+)').Matches|ForEach-Object{$_.Groups[1].Value})
 $tables31=@(& docker @argsLab exec -T db psql -U p36 -d wed_snap_worker_shutdown_test -Atc "SELECT tablename FROM pg_tables WHERE schemaname='public'");if($LASTEXITCODE -ne 0){throw 'Own table inspection'}
 foreach($t31 in @($tables31|Where-Object{$_ -and $_ -ne '_prisma_migrations'})){if($models31 -notcontains $t31){throw 'Foreign table'};$sql31='SELECT count(*) FROM "'+$t31+'"';$count31=(($sql31|& docker @argsLab exec -T db psql -U p36 -d wed_snap_worker_shutdown_test -At)-join '').Trim();if($LASTEXITCODE -ne 0 -or $count31 -ne '0'){throw 'Nonempty own lab; never reset'}}
 $keys31=(& docker @argsLab exec -T redis redis-cli INFO keyspace)-join "`n";if($LASTEXITCODE -ne 0 -or $keys31 -match '(?m)^db\d+:'){throw 'Nonempty Redis; never flush'}
 Write-Host 'PASS empty own tables/Redis before generate/migrate/fixtures, no reset'
}
try{
 $env:WED_WORKER_SHUTDOWN_SHA=$sourceSHA;Write-Host ('P36 '+$Phase+' UTC '+[DateTime]::UtcNow.ToString('o')+' VN '+[DateTimeOffset]::UtcNow.ToOffset([TimeSpan]::FromHours(7)).ToString('o')+' PowerShell '+$PSVersionTable.PSVersion+' sourceSHA '+$sourceSHA);Protect
 $raw31=& docker @argsLab config --format json;if($LASTEXITCODE -ne 0){throw 'Resolved failure'};$cfg=($raw31 -join "`n")|ConvertFrom-Json
 if($cfg.name -ne $project -or @($cfg.services.PSObject.Properties).Count -ne 3 -or @($cfg.networks.PSObject.Properties).Count -ne 1 -or -not $cfg.networks.lab.internal -or @($cfg.volumes.PSObject.Properties).Count -ne 2){throw 'Resolved topology'}
 $total31=0
 foreach($svc31 in @('lab','db','redis')){
  $s31=$cfg.services.$svc31;$image31=if($svc31 -eq 'db'){'postgres:16.10-bookworm'}elseif($svc31 -eq 'redis'){'redis:7.4.6-bookworm'}else{'wed-snap-p3-test:local'}
  if($s31.image -ne $image31 -or $s31.pull_policy -ne 'never' -or $s31.build -or $s31.entrypoint -or $s31.privileged -or $s31.pid -or -not $s31.read_only -or [long]$s31.mem_limit -ne $memory[$svc31] -or [double]$s31.cpus -ne $cpu[$svc31] -or $s31.pids_limit -ne $(if($svc31 -eq 'lab'){192}elseif($svc31 -eq 'redis'){32}else{64}) -or ($svc31 -ne 'db' -and ($s31.command -join ' ') -ne $commands[$svc31])){throw 'Resolved image/cmd/resources'}
  $im31=Decode (& docker image inspect $image31);if($LASTEXITCODE -ne 0 -or $im31.Id -ne $pins[$image31] -or $im31.Os -ne 'linux'){throw 'Cached pinned image unavailable; no build/pull'}
  $total31+=[long]$s31.mem_limit
  if(@($s31.networks.PSObject.Properties).Count -ne 1 -or $s31.networks.PSObject.Properties.Name -notcontains 'lab' -or @($s31.ports|Where-Object{$_}).Count){throw 'Resolved network/ports'}
  if($svc31 -eq 'lab'){
   if($s31.user -ne 'node' -or $s31.cap_drop -notcontains 'ALL' -or $s31.security_opt -notcontains 'no-new-privileges:true' -or @($s31.volumes).Count -ne $pairs.Count){throw 'Resolved source privileges'}
   foreach($pair31 in $pairs){$m31=@($s31.volumes|Where-Object target -eq $pair31[1]);if($m31.Count -ne 1 -or $m31[0].type -ne 'bind' -or -not $m31[0].read_only -or $m31[0].source.Replace('\','/') -ne (Resolve-Path -LiteralPath $pair31[0]).Path.Replace('\','/')){throw 'Resolved sourceRO exact'}}
  }
 }
 if($total31 -gt 838860800 -or $cfg.services.lab.environment.SWEEP_SECONDS -ne '2' -or $cfg.services.lab.environment.P36_GUARD -ne $project -or $cfg.services.lab.environment.P36_SOURCE_SHA -ne $sourceSHA -or $cfg.services.lab.environment.DATABASE_URL -ne 'postgresql://p36@db:5432/wed_snap_worker_shutdown_test' -or $cfg.services.lab.environment.REDIS_URL -ne 'redis://redis:6379/9' -or $cfg.services.lab.environment.MEDIA_ROOT -ne '/tmp/p36-media' -or $cfg.services.lab.environment.ADMIN_SESSION_SECRET -ne 'p36-unused-sentinel-replaced-in-memory'){throw 'Resolved env/memory/media'}
 Write-Host ('PASS resolved cached/sourceRO/privatePID/no ports/internal ownlab totalMiB '+($total31/1MB))
 if($Phase -eq 'Start'){
  if(& docker @argsLab ps -a -q){throw 'Existing own containers; guarded Stop first'}
  foreach($historical31 in @('wed-snap-ad-statistics-lab','wed-snap-admin-browser-lab','wed-snap-worker-scheduler-lab','wed-snap-worker-metrics-retention-lab')){if(& docker ps -q --filter ('label=com.docker.compose.project='+$historical31)){throw 'Historical lab running; do not manipulate it'}}
  Call @('create','--no-build');Actual;Call @('start','db','redis')
  $until31=[DateTime]::UtcNow.AddSeconds(30);do{& docker @argsLab exec -T db pg_isready -U p36 -d wed_snap_worker_shutdown_test;if($LASTEXITCODE -eq 0){break};Start-Sleep -Milliseconds 500}while([DateTime]::UtcNow -lt $until31);if($LASTEXITCODE -ne 0){throw 'Own DB not ready'}
  Actual;Stores;Empty;Call @('start','lab');Actual;Stores
  Call @('exec','-T','lab','node_modules/.bin/prisma','generate','--schema','prisma/schema.prisma');Actual;Stores;Empty
  Call @('exec','-T','lab','node_modules/.bin/prisma','migrate','deploy','--schema','prisma/schema.prisma');Actual;Stores;Empty
  $coord31=@{sourceSHA=$sourceSHA;sources=$sources;dbIP=$containers.db.NetworkSettings.Networks.($project+'_lab').IPAddress;redisIP=$containers.redis.NetworkSettings.Networks.($project+'_lab').IPAddress;cluster=$cluster;redisRun=$run}|ConvertTo-Json -Depth 5 -Compress
  $coord31|& docker @argsLab exec -T lab node tests/p36/coordinates.cjs;if($LASTEXITCODE -ne 0){throw 'Own coordinates write'}
  Write-Host 'READY ownlab36 no ports; Matrix may spawn exact production worker entrypoint ownchild only, no media jobs/main endpoints'
 }elseif($Phase -eq 'Matrix'){
  Actual;Stores;Empty;Call @('exec','-T','lab','node_modules/.bin/tsx','--tsconfig','tests/p36/tsconfig.json','tests/p36/shutdown.ts');Empty
 }elseif($Phase -eq 'Typecheck'){
  Actual;Stores;Call @('exec','-T','lab','node_modules/.bin/tsc','-p','tests/p36/tsconfig.json');Write-Host 'PASS worker/shared/tests36 typecheck sequential'
 }elseif($Phase -eq 'Logs'){
  Actual;Call @('logs','--timestamps','--no-color')
 }elseif($Phase -eq 'Stop'){
  Actual;Stores;Empty;Call @('stop');Actual;Call @('rm','-f');if(& docker @argsLab ps -a -q){throw 'Own containers remain'};Write-Host 'PASS own stores empty before own3 removed, volumes/network/raw retained; no main/reset/flush/down-v/prune'
 }
 Protect;Write-Host ('P36_COMMAND_EXIT 0 '+$Phase+' UTC '+[DateTime]::UtcNow.ToString('o'))
}finally{$env:WED_WORKER_SHUTDOWN_SHA=$oldSha}










