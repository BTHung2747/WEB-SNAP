param([ValidateSet('Start','Launch','Typecheck','Logs','Cleanup','Stop','Baseline','Matrix','Generate','Contracts','Supplement','Verify','FinalizeChecks')][string]$Phase)
$ErrorActionPreference='Stop'
$labRoot=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
if((Get-Location).Path -ne $labRoot -or $labRoot -ne 'D:\WED SNAP'){throw 'Wrong repository; native PowerShell required'}
$project='wed-snap-ad-statistics-lab'
$argsLab=@('compose','-p',$project,'--project-directory',$labRoot,'--env-file','infra/ad-statistics-lab.env.example','-f','infra/compose.ad-statistics-lab.yaml')
$oldSha=$env:WED_AD_STATISTICS_SHA
$sources=@('apps/api/src/main.ts','apps/api/src/openapi.ts','apps/api/src/app.module.ts','apps/api/src/controllers/admin.controller.ts','apps/api/src/controllers/session.controller.ts','apps/api/src/services/admin.service.ts','apps/api/src/services/session.service.ts','apps/api/src/auth/session.ts','apps/api/src/validation.ts','apps/api/src/filters/safe-errors.filter.ts','apps/api/src/security/client-ip.ts','packages/shared/src/core.ts','prisma/schema.prisma','apps/web/src/pages/Admin.tsx','apps/web/src/lib/api.ts','apps/web/src/styles/admin.css')
$fingerprint=($sources|ForEach-Object{$_+':'+(Get-FileHash -LiteralPath $_).Hash.ToLowerInvariant()}) -join '|'
$algorithm=[Security.Cryptography.SHA256]::Create();$sourceSHA=([BitConverter]::ToString($algorithm.ComputeHash([Text.Encoding]::UTF8.GetBytes($fingerprint)))).Replace('-','').ToLowerInvariant();$algorithm.Dispose()
$pins=@{'wed-snap-p3-test:local'='sha256:f2a71e620a0c6a99261a184ad39352e4bbf26954e34ccb1cddcb25ffefa115f1';'postgres:16.10-bookworm'='sha256:38471f330eb885e04de130b768d6db4e10469e2311879c7e5c699f6d2d8a1c74';'redis:7.4.6-bookworm'='sha256:a9cc41d6d01da2aa26c219e4f99ecbeead955a7b656c1c499cce8922311b2514'}
$memory=@{api=536870912;web=402653184;db=201326592;redis=100663296};$cpu=@{api=.75;web=.5;db=.5;redis=.25}
$pairs=@{api=@(@('apps/api','/app/apps/api'),@('apps/web','/app/apps/web'),@('packages/shared','/app/packages/shared'),@('prisma','/app/prisma'),@('tests/p30','/app/tests/p30'),@('tsconfig.json','/app/tsconfig.json'),@('docs/openapi.json','/app/docs/openapi.json'));web=@(@('apps/web','/app/apps/web'),@('tests/p30','/app/tests/p30'))}
$commands=@{api='node -e setInterval(() => {}, 60000)';web='node_modules/.bin/vite --config tests/p30/vite.config.ts --configLoader runner';db='postgres';redis='redis-server --appendonly yes --maxmemory 64mb --maxmemory-policy noeviction'}
function Protect {
 $p=Get-Content docs/evidence/p30-20261004-protected-before.json -Raw|ConvertFrom-Json
 foreach($f in $p.protected){if((Get-FileHash -LiteralPath $f.path).Hash.ToLowerInvariant() -ne $f.sha){throw ('Protected file changed '+$f.path)}}
 Write-Host ('PASS protected '+$p.protected.Count+' baseline hashes/history19-29; outside allowed R11 paths')
}
function Call([string[]]$a){Write-Host ('COMMAND docker '+($argsLab+$a -join ' '));& docker @argsLab @a;if($LASTEXITCODE -ne 0){throw 'Lab command failed; preserve raw'}}
function Decode([string[]]$raw){return @(($raw -join "`n"|ConvertFrom-Json))[0]}
function Actual {
 $ids=@(& docker @argsLab ps -a -q);if($LASTEXITCODE -ne 0 -or $ids.Count -ne 4){throw 'Exactly4 own containers required'}
 $script:containers=@{}
 foreach($n in @('lab','frontend')){
  $net=Decode (& docker network inspect ($project+'_'+$n));if($LASTEXITCODE -ne 0 -or $net.Labels.'com.docker.compose.project' -ne $project -or $net.Driver -ne 'bridge' -or [bool]$net.Internal -ne ($n -eq 'lab') -or @($net.Containers.PSObject.Properties.Name|Where-Object{$_ -and $ids -notcontains $_}).Count){throw 'Foreign network/member'}
 }
 foreach($svc in @('api','web','db','redis')){
  $id=@(& docker @argsLab ps -a -q $svc);if($id.Count -ne 1){throw 'Ambiguous identity'};$c=Decode (& docker inspect $id[0]);if($LASTEXITCODE -ne 0){throw 'Inspect failure'};$containers[$svc]=$c;$s=$cfg.services.$svc
  if($c.Config.Labels.'com.docker.compose.project' -ne $project -or $c.Config.Labels.'com.docker.compose.service' -ne $svc -or $c.Image -ne $pins[$s.image] -or $c.Config.Image -ne $s.image -or $c.HostConfig.PidMode -ne '' -or $c.HostConfig.Privileged -or -not $c.HostConfig.ReadonlyRootfs -or ($c.Config.Cmd -join ' ') -ne $commands[$svc]){throw 'Actual image/cmd/project/rootfs/PID failure'}
  if($c.HostConfig.Memory -ne $memory[$svc] -or $c.HostConfig.NanoCpus -ne [long]($cpu[$svc]*1e9) -or $c.HostConfig.PidsLimit -ne $(if($svc -eq 'redis'){32}else{64})){throw 'Actual resource failure'}
  $netNames=@($c.NetworkSettings.Networks.PSObject.Properties.Name);$wantNets=if($svc -eq 'web'){@(($project+'_lab'),($project+'_frontend'))}else{@($project+'_lab')}
  if(@(Compare-Object $wantNets $netNames).Count){throw 'Foreign network'}
  $ports=@($c.HostConfig.PortBindings.PSObject.Properties)
  if($svc -eq 'web'){if($ports.Count -ne 1 -or $ports[0].Name -ne '5181/tcp' -or @($ports[0].Value).Count -ne 1 -or $ports[0].Value[0].HostIp -ne '127.0.0.1' -or $ports[0].Value[0].HostPort -ne '5181'){throw 'Wrong web port'}}elseif($ports.Count){throw 'Datastore/API published'}
  foreach($entry in $s.environment.PSObject.Properties){if($c.Config.Env -notcontains ($entry.Name+'='+$entry.Value)){throw 'Actual env/source mismatch'}}
  if(@($c.Config.Env|Where-Object{$_ -match '^(HTTP_PROXY|HTTPS_PROXY|ALL_PROXY|POSTGRES_PASSWORD)='}).Count -or @($c.HostConfig.VolumesFrom|Where-Object{$_}).Count){throw 'Foreign env/mount'}
  if($svc -in @('api','web')){
   if($c.Config.User -ne 'node' -or $c.Config.WorkingDir -ne '/app' -or $c.HostConfig.CapDrop -notcontains 'ALL' -or $c.HostConfig.SecurityOpt -notcontains 'no-new-privileges:true'){throw 'App privileges'}
   $binds=@($c.Mounts|Where-Object Type -eq bind);$expectedPairs=$pairs[$svc]
   if($Phase -eq 'Stop' -and $svc -eq 'api' -and $c.Id -eq '05e800e88410d584c5bc5e2f474a7920991c8ed9ec34c70ff26a1e3c7a8841b3' -and $binds.Count -eq 6){$expectedPairs=@($expectedPairs|Where-Object{$_[0] -ne 'apps/web'});Write-Host 'Stop-only exact failed-bootstrap container guard: original6RO mounts, no web source; no fixture seeded'}
   if($binds.Count -ne $expectedPairs.Count -or @($c.Mounts|Where-Object{$_.Type -notin @('bind','tmpfs')}).Count){throw 'App foreign data mounts'}
   foreach($pair in $expectedPairs){$p=(Resolve-Path -LiteralPath $pair[0]).Path.Replace('\','/');$desktop='/run/desktop/mnt/host/d/'+$p.Substring(3);$m=@($binds|Where-Object Destination -eq $pair[1]);if($m.Count -ne 1 -or $m[0].RW -or @($p,$desktop) -notcontains $m[0].Source.Replace('\','/')){throw 'Source not RO/exact'}}
  }else{
   $vName=if($svc -eq 'db'){'statistics_db'}else{'statistics_redis'};$dest=if($svc -eq 'db'){'/var/lib/postgresql/data'}else{'/data'};$vols=@($c.Mounts|Where-Object Type -eq volume)
   if($vols.Count -ne 1 -or $vols[0].Name -ne ($project+'_'+$vName) -or $vols[0].Destination -ne $dest -or @($c.Mounts|Where-Object{$_.Type -notin @('volume','tmpfs')}).Count){throw 'Foreign datastore volume'}
   $v=Decode (& docker volume inspect $vols[0].Name);if($LASTEXITCODE -ne 0 -or $v.Labels.'com.docker.compose.project' -ne $project){throw 'Foreign volume label'}
  }
  $tmp=@($c.HostConfig.Tmpfs.PSObject.Properties);if($tmp.Count -ne @($s.tmpfs).Count){throw 'Actual tmpfs count'}
  foreach($t in $s.tmpfs){$target=($t -split ':',2)[0];$options=($t -split ':',2)[1] -split ',';foreach($opt in $options){if(($c.HostConfig.Tmpfs.$target -split ',') -notcontains $opt){throw 'Actual bounded/private tmpfs'}}}
  Write-Host ('PASS actual '+(@{project=$project;service=$svc;id=$c.Id;image=$c.Image;state=$c.State.Status;sourceRO=$true;memory=$c.HostConfig.Memory;cmd=$c.Config.Cmd;pidPrivate=$true;port=if($svc -eq 'web'){'127.0.0.1:5181'}else{'none'}}|ConvertTo-Json -Compress))
 }
}
function Stores {
 $name=((& docker @argsLab exec -T db psql -U p30 -d wed_snap_ad_statistics_test -Atc 'SELECT current_database()')-join '').Trim();if($LASTEXITCODE -ne 0 -or $name -ne 'wed_snap_ad_statistics_test'){throw 'DB identity'}
 $ri=(& docker @argsLab exec -T redis redis-cli -n 13 CLIENT INFO)-join '';if($LASTEXITCODE -ne 0 -or $ri -notmatch '\bdb=13\b'){throw 'Redis index'}
 $script:cluster=((& docker @argsLab exec -T db psql -U p30 -d wed_snap_ad_statistics_test -Atc 'SELECT system_identifier FROM pg_control_system()')-join '').Trim();if($LASTEXITCODE -ne 0 -or $cluster -notmatch '^\d+$'){throw 'Cluster'}
 $info=(& docker @argsLab exec -T redis redis-cli INFO server)-join "`n";if($LASTEXITCODE -ne 0 -or $info -notmatch 'run_id:([a-f0-9]{40})'){throw 'Redis run identity'};$script:run=$Matches[1]
 Write-Host 'PASS datastore current_database=wed_snap_ad_statistics_test Redis CLIENT INFO db13; cluster/run verified'
}
function Empty {
 $models=@((Get-Content prisma/schema.prisma|Select-String '^model (\w+)').Matches|ForEach-Object{$_.Groups[1].Value})
 $tables=@(& docker @argsLab exec -T db psql -U p30 -d wed_snap_ad_statistics_test -Atc "SELECT tablename FROM pg_tables WHERE schemaname='public'");if($LASTEXITCODE -ne 0){throw 'Table inspection'}
 foreach($t in @($tables|Where-Object{$_ -and $_ -ne '_prisma_migrations'})){if($models -notcontains $t){throw 'Foreign table'};$sql='SELECT count(*) FROM "'+$t+'"';$count=(($sql|& docker @argsLab exec -T db psql -U p30 -d wed_snap_ad_statistics_test -At)-join '').Trim();if($LASTEXITCODE -ne 0 -or $count -ne '0'){throw 'Nonempty lab; never reset'}}
 $keyspace=(& docker @argsLab exec -T redis redis-cli INFO keyspace)-join "`n";if($LASTEXITCODE -ne 0 -or $keyspace -match '(?m)^db\d+:'){throw 'Nonempty Redis; never flush'}
 Write-Host 'PASS empty own tables/Redis before migrate/seed; no reset'
}
function Launch {
  Actual;Stores;Empty
  $coord=@{sourceSHA=$sourceSHA;sources=$sources;dbIP=$containers.db.NetworkSettings.Networks.($project+'_lab').IPAddress;redisIP=$containers.redis.NetworkSettings.Networks.($project+'_lab').IPAddress;cluster=$cluster;redisRun=$run}|ConvertTo-Json -Depth 4 -Compress
  $coord | & docker @argsLab exec -T api node tests/p30/coordinates.cjs
  if($LASTEXITCODE -ne 0){throw 'Private coordinates write'}
  Call @('exec','-T','api','node','tests/p30/launch.cjs')
  $until=[DateTime]::UtcNow.AddSeconds(30);do{& docker @argsLab exec -T api node tests/p30/ready.cjs;if($LASTEXITCODE -eq 0){break};Start-Sleep -Milliseconds 500}while([DateTime]::UtcNow -lt $until)
  if($LASTEXITCODE -ne 0){Call @('exec','-T','api','cat','/tmp/p30/server.log');throw 'Own API bootstrap not ready'}
  Call @('start','web');Actual;Write-Host 'READY http://p30.localhost:5181 / real backend, no fetch business fixtures'
}
try{
 $env:WED_AD_STATISTICS_SHA=$sourceSHA;Write-Host ('P30 '+$Phase+' UTC '+[DateTime]::UtcNow.ToString('o')+' VN '+[DateTimeOffset]::UtcNow.ToOffset([TimeSpan]::FromHours(7)).ToString('o')+' PowerShell '+$PSVersionTable.PSVersion+' sourceSHA '+$sourceSHA);Protect
 $raw=& docker @argsLab config --format json;if($LASTEXITCODE -ne 0){throw 'Resolved failure'};$cfg=($raw -join "`n")|ConvertFrom-Json
 if($cfg.name -ne $project -or @($cfg.services.PSObject.Properties).Count -ne 4 -or @($cfg.networks.PSObject.Properties).Count -ne 2 -or -not $cfg.networks.lab.internal -or $cfg.networks.frontend.internal -or @($cfg.volumes.PSObject.Properties).Count -ne 2){throw 'Resolved topology'}
 $total=0
 foreach($svc in @('api','web','db','redis')){
  $s=$cfg.services.$svc;$image=if($svc -eq 'db'){'postgres:16.10-bookworm'}elseif($svc -eq 'redis'){'redis:7.4.6-bookworm'}else{'wed-snap-p3-test:local'}
  if($s.image -ne $image -or $s.pull_policy -ne 'never' -or $s.build -or $s.entrypoint -or $s.privileged -or $s.pid -or -not $s.read_only -or [long]$s.mem_limit -ne $memory[$svc] -or [double]$s.cpus -ne $cpu[$svc] -or $s.pids_limit -ne $(if($svc -eq 'redis'){32}else{64})){throw 'Resolved image/resources'}
  $im=Decode (& docker image inspect $image);if($LASTEXITCODE -ne 0 -or $im.Id -ne $pins[$image] -or $im.Os -ne 'linux'){throw 'Cached pinned image absent; no build/pull'};$total+=[long]$s.mem_limit
  if($svc -ne 'db' -and ($s.command -join ' ') -ne $commands[$svc]){throw 'Resolved cmd'}
  $n=@($s.networks.PSObject.Properties.Name);$want=if($svc -eq 'web'){@('lab','frontend')}else{@('lab')};if(@(Compare-Object $n $want).Count){throw 'Resolved network'}
  if($svc -eq 'web'){if(@($s.ports).Count -ne 1 -or $s.ports[0].host_ip -ne '127.0.0.1' -or $s.ports[0].published -ne '5181' -or $s.ports[0].target -ne 5181){throw 'Resolved port'}}elseif(@($s.ports|Where-Object{$_}).Count){throw 'Resolved published datastore/API'}
  if($svc -in @('api','web')){if($s.user -ne 'node' -or $s.cap_drop -notcontains 'ALL' -or $s.security_opt -notcontains 'no-new-privileges:true' -or @($s.volumes).Count -ne $pairs[$svc].Count){throw 'Resolved app privileges/mounts'};foreach($pair in $pairs[$svc]){$m=@($s.volumes|Where-Object target -eq $pair[1]);if($m.Count -ne 1 -or $m[0].type -ne 'bind' -or -not $m[0].read_only -or $m[0].source.Replace('\','/') -ne (Resolve-Path -LiteralPath $pair[0]).Path.Replace('\','/')){throw 'Resolved sourceRO'}};if($s.environment.P30_GUARD -ne $project -or $s.environment.P30_SOURCE_SHA -ne $sourceSHA){throw 'Resolved source env'}}
 }
 if($total -gt 1342177280 -or $cfg.services.api.environment.DATABASE_URL -ne 'postgresql://p30@db:5432/wed_snap_ad_statistics_test' -or $cfg.services.api.environment.REDIS_URL -ne 'redis://redis:6379/13' -or $cfg.services.api.environment.APP_ORIGIN -ne 'http://p30.localhost:5181' -or $cfg.services.api.environment.ADMIN_SESSION_SECRET -ne 'p30-unused-sentinel-replaced-in-memory' -or @($cfg.services.web.environment.PSObject.Properties).Count -ne 3){throw 'Resolved env/budget'}
 Write-Host ('PASS resolved/pinned cached/sourceRO/no mainenv totalMiB '+($total/1MB)+' ports only loopback5181')
 if($Phase -eq 'Start'){
  if(& docker @argsLab ps -a -q){throw 'Existing own lab; guarded Stop first'}
  foreach($p in @('wed-snap-admin-ui-lab','wed-snap-admin-http-lab')){if(& docker ps -q --filter ('label=com.docker.compose.project='+$p)){throw 'Historical lab running; do not manipulate it'}}
  if(Get-NetTCPConnection -LocalPort 5181 -State Listen -ErrorAction SilentlyContinue){throw '5181 occupied; no main fallback'}
  Call @('create','--no-build');Actual;Call @('start','db','redis')
  $until=[DateTime]::UtcNow.AddSeconds(30);do{& docker @argsLab exec -T db pg_isready -U p30 -d wed_snap_ad_statistics_test;if($LASTEXITCODE -eq 0){break};Start-Sleep -Milliseconds 500}while([DateTime]::UtcNow -lt $until);if($LASTEXITCODE -ne 0){throw 'DB readiness'}
  Actual;Stores;Empty;Call @('start','api');Actual;Stores
  Call @('exec','-T','api','node_modules/.bin/prisma','generate','--schema','prisma/schema.prisma');Actual;Stores;Empty
  Call @('exec','-T','api','node_modules/.bin/prisma','migrate','deploy','--schema','prisma/schema.prisma');Actual;Stores;Empty
  Launch
 }elseif($Phase -eq 'Launch'){
  Launch
 }elseif($Phase -eq 'FinalizeChecks'){
  Actual;Stores
  $generatorSHA30=((& docker @argsLab exec -T api node tests/p30/hash-generated.cjs) -join '').Trim()
  if($LASTEXITCODE -ne 0 -or $generatorSHA30 -ne (Get-FileHash docs/openapi.json).Hash.ToLowerInvariant()){throw 'Exported snapshot differs from production generator'}
  Write-Host ('PASS host snapshot matches private generated bytes '+$generatorSHA30)
  Call @('exec','-T','api','node','tests/p30/contracts.cjs')
  Call @('exec','-T','api','node_modules/.bin/tsc','-p','tests/p30/tsconfig.server.json')
  Call @('exec','-T','web','node_modules/.bin/tsc','-p','apps/web/tsconfig.json')
  Call @('exec','-T','web','node_modules/.bin/tsc','-p','tests/p30/tsconfig.web.json')
  Write-Host 'PASS FinalizeChecks preservation/refs/API-shared-web-tests sequential'
 }elseif($Phase -eq 'Verify'){
  Actual;Stores
  Call @('exec','-T','api','node','tests/p30/matrix.cjs','final')
  Call @('exec','-T','api','node','tests/p30/matrix.cjs','generate')
  $json30=(& docker @argsLab exec -T api cat /tmp/p30/openapi.json) -join "`n"
  if($LASTEXITCODE -ne 0){throw 'Generator read'}
  if(@(($json30|ConvertFrom-Json).paths.PSObject.Properties).Count -ne 20){throw 'Inventory'}
  [IO.File]::WriteAllText((Join-Path $labRoot 'docs/openapi.json'),$json30+"`n",(New-Object Text.UTF8Encoding($false)))
  $generatorSHA30=((& docker @argsLab exec -T api node tests/p30/hash-generated.cjs) -join '').Trim()
  if($LASTEXITCODE -ne 0 -or $generatorSHA30 -ne (Get-FileHash docs/openapi.json).Hash.ToLowerInvariant()){throw 'Exported snapshot differs from production generator'}
  Write-Host ('PASS host snapshot matches private generated bytes '+$generatorSHA30)
  Call @('exec','-T','api','node','tests/p30/contracts.cjs')
  Call @('exec','-T','api','node_modules/.bin/tsc','-p','tests/p30/tsconfig.server.json')
  Call @('exec','-T','web','node_modules/.bin/tsc','-p','apps/web/tsconfig.json')
  Call @('exec','-T','web','node_modules/.bin/tsc','-p','tests/p30/tsconfig.web.json')
  Write-Host 'PASS Verify matrix/generator-repeat/contracts/API-shared-web-tests sequential'
 }elseif($Phase -in @('Baseline','Matrix','Generate')){
  Actual;Stores;Call @('exec','-T','api','node','tests/p30/matrix.cjs',$(if($Phase -eq 'Baseline'){'baseline'}elseif($Phase -eq 'Generate'){'generate'}else{'final'}))
  if($Phase -eq 'Generate'){
   $json30=(& docker @argsLab exec -T api cat /tmp/p30/openapi.json) -join "`n"
   if($LASTEXITCODE -ne 0){throw 'Own generator read'}
   $doc30=$json30|ConvertFrom-Json
   if(@($doc30.paths.PSObject.Properties).Count -ne 20){throw 'Generated inventory'}
   [IO.File]::WriteAllText((Join-Path $labRoot 'docs/openapi.json'),$json30+"`n",(New-Object Text.UTF8Encoding($false)))
   Write-Host 'PASS snapshot generated via production factory; no hand-edited snapshot'
  }
 }elseif($Phase -eq 'Contracts'){
  Actual;Stores
  $generatorSHA30=((& docker @argsLab exec -T api node tests/p30/hash-generated.cjs) -join '').Trim()
  if($LASTEXITCODE -ne 0 -or $generatorSHA30 -ne (Get-FileHash docs/openapi.json).Hash.ToLowerInvariant()){throw 'Exported snapshot differs from production generator'}
  Write-Host ('PASS host snapshot matches private generated bytes '+$generatorSHA30)
  Call @('exec','-T','api','node','tests/p30/contracts.cjs')
 }elseif($Phase -eq 'Supplement'){
  Actual;Stores;Call @('exec','-T','api','node','tests/p30/supplement.cjs')
 }elseif($Phase -eq 'Typecheck'){
  Actual;Stores;Call @('exec','-T','api','node_modules/.bin/tsc','-p','tests/p30/tsconfig.server.json');Call @('exec','-T','web','node_modules/.bin/tsc','-p','apps/web/tsconfig.json');Call @('exec','-T','web','node_modules/.bin/tsc','-p','tests/p30/tsconfig.web.json');Write-Host 'PASS API/shared/web/p30 checks sequential'
 }elseif($Phase -eq 'Logs'){
  Actual;Call @('exec','-T','api','node','tests/p30/runtime.cjs');Call @('exec','-T','api','cat','/tmp/p30/server.log');Call @('logs','--timestamps','--no-color')
 }elseif($Phase -eq 'Cleanup'){
  Actual;Stores;Call @('exec','-T','api','node','tests/p30/cleanup.cjs');Call @('exec','-T','api','cat','/tmp/p30/server.log')
 }elseif($Phase -eq 'Stop'){
  Actual;Call @('stop');Actual;Call @('rm','-f');if(& docker @argsLab ps -a -q){throw 'Own containers remain'};Write-Host 'PASS own4 stopped/removed; volumes/networks retained, no reset/flush/down-v/prune'
 }
 Protect;Write-Host ('P30_COMMAND_EXIT 0 '+$Phase+' UTC '+[DateTime]::UtcNow.ToString('o'))
}finally{$env:WED_AD_STATISTICS_SHA=$oldSha}



