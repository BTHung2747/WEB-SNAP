param([ValidateSet('Start','Matrix','Typecheck','Logs','Stop')][string] $Phase)
$ErrorActionPreference='Stop'
$metaRoot=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
if((Get-Location).Path -ne $metaRoot -or $metaRoot -ne 'D:\WED SNAP'){throw 'Wrong repository'}
$metaProject='wed-snap-metadata-lab'
$metaArgs=@('compose','-p',$metaProject,'--project-directory',$metaRoot,'--env-file','infra/metadata-lab.env.example','-f','infra/compose.metadata-lab.yaml')
$savedSha=[Environment]::GetEnvironmentVariable('WED_METADATA_LAB_SHA','Process')
$sourcePaths=@('prisma/schema.prisma','packages/shared/src/core.ts','apps/api/src/services/jobs.service.ts','apps/worker/src/processor.ts','apps/worker/src/lifecycle.ts')
$fingerprint=($sourcePaths|ForEach-Object{ $_+':'+(Get-FileHash -LiteralPath $_).Hash.ToLowerInvariant() }) -join '|'
$shaObject=[Security.Cryptography.SHA256]::Create()
$metaSha=([BitConverter]::ToString($shaObject.ComputeHash([Text.Encoding]::UTF8.GetBytes($fingerprint)))).Replace('-','').ToLowerInvariant()
$shaObject.Dispose()
$images=@{}
$bindPairs=@(@('apps/api','/app/apps/api'),@('apps/worker','/app/apps/worker'),@('packages/shared','/app/packages/shared'),@('prisma','/app/prisma'),@('tests/p22','/app/tests/p22'),@('tsconfig.json','/app/tsconfig.json'),@('tests/p22/fixture_adapter.py','/app/infra/media_adapter.py'))
function Invoke-Metadata([string[]] $ArgsList){Write-Host ('COMMAND docker '+($metaArgs+$ArgsList -join ' ')); & docker @metaArgs @ArgsList; if($LASTEXITCODE -ne 0){throw 'Metadata lab command failed; raw retained'}}
function Assert-Actual {
  $allIds=@(& docker @metaArgs ps -a -q);if($LASTEXITCODE -ne 0 -or $allIds.Count -ne 3){throw 'Require exactly3 test containers'}
  $network=@(((& docker network inspect wed-snap-metadata-lab_lab)-join "`n"|ConvertFrom-Json))[0]
  if($LASTEXITCODE -ne 0 -or -not $network.Internal -or $network.Driver -ne 'bridge' -or $network.Labels.'com.docker.compose.project' -ne $metaProject -or @($network.Containers.PSObject.Properties.Name|Where-Object{$_ -and $allIds -notcontains $_}).Count){throw 'Network identity/isolation FAIL'}
  foreach($service in @('db','redis','lab')){
    $ids=@(& docker @metaArgs ps -a -q $service);if($LASTEXITCODE -ne 0 -or $ids.Count -ne 1){throw 'Ambiguous test container'}
    $c=@(((& docker inspect $ids[0])-join "`n"|ConvertFrom-Json))[0]
    $image=$cfg.services.$service.image
    if($c.Config.Labels.'com.docker.compose.project' -ne $metaProject -or $c.Config.Labels.'com.docker.compose.service' -ne $service -or $c.Image -ne $images[$image] -or $c.Config.Image -ne $image -or $c.HostConfig.PidMode -ne '' -or $c.HostConfig.Privileged -or @($c.HostConfig.PortBindings.PSObject.Properties).Count){throw 'Actual image/project/ports/PID FAIL'}
    if(@($c.NetworkSettings.Networks.PSObject.Properties).Count -ne 1 -or $c.NetworkSettings.Networks.PSObject.Properties.Name -ne 'wed-snap-metadata-lab_lab'){throw 'Foreign network'}
    $expectedMemory=if($service -eq 'db'){201326592}elseif($service -eq 'redis'){100663296}else{671088640}
    $expectedPids=if($service -eq 'db'){64}elseif($service -eq 'redis'){32}else{96}
    if($c.HostConfig.Memory -ne $expectedMemory -or $c.HostConfig.PidsLimit -ne $expectedPids -or $c.HostConfig.NanoCpus -ne [long]([double]$cfg.services.$service.cpus*1000000000)){throw 'Actual resource guard FAIL'}
    if($service -eq 'lab'){
      if($c.Config.User -ne 'node' -or $c.Config.WorkingDir -ne '/app' -or -not $c.HostConfig.ReadonlyRootfs -or $c.HostConfig.CapDrop -notcontains 'ALL' -or $c.HostConfig.SecurityOpt -notcontains 'no-new-privileges:true' -or ($c.Config.Cmd -join ' ') -ne 'node -e setInterval(() => {}, 60000)'){throw 'Runtime command/privileges FAIL'}
      foreach($value in @('P22_GUARD=wed-snap-metadata-lab',('P22_SOURCE_SHA='+$metaSha),'DATABASE_URL=postgresql://p22@db:5432/wed_snap_metadata_test','REDIS_URL=redis://redis:6379/14','MEDIA_ROOT=/media','APP_ORIGIN=http://p22.local','VERIFIED_PLATFORMS=youtube','ADMIN_SESSION_SECRET=p22-isolated-fixture-not-a-production-secret','NODE_OPTIONS=--max-old-space-size=384')){if($c.Config.Env -notcontains $value){throw 'Runtime env/source FAIL'}}
      if(@($c.Config.Env|Where-Object{$_ -match '^(HTTP_PROXY|HTTPS_PROXY|ALL_PROXY|POSTGRES_PASSWORD)='}).Count){throw 'Foreign proxy/env'}
      $binds=@($c.Mounts|Where-Object Type -eq bind)
      if($binds.Count -ne $bindPairs.Count -or @($c.Mounts|Where-Object{$_.Type -notin @('bind','tmpfs')}).Count -or @($c.HostConfig.Tmpfs.PSObject.Properties).Count -ne 3){throw 'Unexpected mounts/data'}
      foreach($pair in $bindPairs){$path=(Resolve-Path -LiteralPath $pair[0]).Path.Replace('\','/');$desktop='/run/desktop/mnt/host/d/'+$path.Substring(3);$m=@($binds|Where-Object Destination -eq $pair[1]);if($m.Count -ne 1 -or $m[0].RW -or @($path,$desktop) -notcontains $m[0].Source.Replace('\','/')){throw 'Actual source RO FAIL'}}
      foreach($target in @('/tmp','/media','/app/node_modules/.prisma')){if(-not $c.HostConfig.Tmpfs.$target -or $c.HostConfig.Tmpfs.$target -notmatch 'uid=1000' -or $c.HostConfig.Tmpfs.$target -notmatch 'gid=1000'){throw 'Private tmpfs/client/media FAIL'}}
      if($c.HostConfig.Tmpfs.'/app/node_modules/.prisma' -notmatch '\bexec\b'){throw 'Client tmpfs cannot load cached query engine'}
    }else{
      $volume=if($service -eq 'db'){'metadata_db'}else{'metadata_redis'};$dest=if($service -eq 'db'){'/var/lib/postgresql/data'}else{'/data'}
      if(@($c.Mounts).Count -ne 1 -or $c.Mounts[0].Type -ne 'volume' -or $c.Mounts[0].Name -ne ($metaProject+'_'+$volume) -or $c.Mounts[0].Destination -ne $dest){throw 'Foreign data volume'}
      $v=@(((& docker volume inspect $c.Mounts[0].Name)-join "`n"|ConvertFrom-Json))[0];if($v.Labels.'com.docker.compose.project' -ne $metaProject){throw 'Volume label FAIL'}
      if($service -eq 'db' -and (($c.Config.Cmd -join ' ') -ne 'postgres' -or $c.Config.Env -notcontains 'POSTGRES_DB=wed_snap_metadata_test' -or $c.Config.Env -notcontains 'POSTGRES_USER=p22' -or $c.Config.Env -notcontains 'POSTGRES_HOST_AUTH_METHOD=trust')){throw 'DB command/env FAIL'}
      if($service -eq 'redis' -and ($c.Config.Cmd -join ' ') -ne 'redis-server --appendonly yes --maxmemory 64mb --maxmemory-policy noeviction'){throw 'Redis command FAIL'}
    }
    Write-Host ('PASS actual '+(@{project=$metaProject;service=$service;id=$c.Id;image=$c.Image;command=$c.Config.Cmd;workdir=$c.Config.WorkingDir;state=$c.State.Status;sourceSHA=$metaSha;pidPrivate=$true;ports=0;internal=$true;mainData=$false}|ConvertTo-Json -Compress))
  }
}
function Assert-Datastores {
  $identity=& docker @metaArgs exec -T db psql -U p22 -d wed_snap_metadata_test -Atc 'SELECT current_database()'
  if($LASTEXITCODE -ne 0 -or ($identity -join '').Trim() -ne 'wed_snap_metadata_test'){throw 'Actual database identity FAIL'}
  $redisIdentity=& docker @metaArgs exec -T redis redis-cli -n 14 CLIENT INFO
  if($LASTEXITCODE -ne 0 -or ($redisIdentity -join '') -notmatch '\bdb=14\b'){throw 'Actual Redis identity FAIL'}
  Write-Host 'PASS actual datastore identity wed_snap_metadata_test / dedicated Redis DB14'
}
try{
  [Environment]::SetEnvironmentVariable('WED_METADATA_LAB_SHA',$metaSha,'Process')
  Write-Host ('P22 '+$Phase+' UTC '+[DateTime]::UtcNow.ToString('o')+' VN '+[DateTimeOffset]::UtcNow.ToOffset([TimeSpan]::FromHours(7)).ToString('o')+' PowerShell '+$PSVersionTable.PSVersion)
  $raw=& docker @metaArgs config --format json;if($LASTEXITCODE -ne 0){throw 'Resolved config FAIL'};$cfg=($raw -join "`n")|ConvertFrom-Json
  if($cfg.name -ne $metaProject -or @($cfg.services.PSObject.Properties).Count -ne 3 -or -not $cfg.networks.lab.internal -or $cfg.networks.lab.name -ne 'wed-snap-metadata-lab_lab' -or @($cfg.volumes.PSObject.Properties).Count -ne 2){throw 'Resolved project/network/data FAIL'}
  foreach($service in @('db','redis','lab')){
    $s=$cfg.services.$service;$expected=if($service -eq 'db'){'postgres:16.10-bookworm'}elseif($service -eq 'redis'){'redis:7.4.6-bookworm'}else{'wed-snap-p3-test:local'}
    if($s.image -ne $expected -or $s.pull_policy -ne 'never' -or $s.build -or $s.entrypoint -or ($service -eq 'db' -and $s.command) -or @($s.ports|Where-Object{$_}).Count -or $s.pid -or $s.privileged -or @($s.networks.PSObject.Properties).Count -ne 1 -or $s.networks.PSObject.Properties.Name -ne 'lab'){throw 'Resolved runtime/network/ports FAIL'}
    $images[$expected]=@(((& docker image inspect $expected)-join "`n"|ConvertFrom-Json))[0].Id;if($LASTEXITCODE -ne 0 -or -not $images[$expected]){throw 'Cached image absent; no build/pull allowed'}
  }
  $s=$cfg.services.lab
  if($s.user -ne 'node' -or -not $s.read_only -or ($s.command -join ' ') -ne 'node -e setInterval(() => {}, 60000)' -or @($s.volumes).Count -ne $bindPairs.Count -or @($s.tmpfs).Count -ne 3 -or $s.environment.DATABASE_URL -ne 'postgresql://p22@db:5432/wed_snap_metadata_test' -or $s.environment.REDIS_URL -ne 'redis://redis:6379/14' -or $s.environment.MEDIA_ROOT -ne '/media'){throw 'Resolved lab env/mounts FAIL'}
  foreach($pair in $bindPairs){$m=@($s.volumes|Where-Object target -eq $pair[1]);if($m.Count -ne 1 -or $m[0].type -ne 'bind' -or -not $m[0].read_only -or $m[0].source.Replace('\','/') -ne (Resolve-Path -LiteralPath $pair[0]).Path.Replace('\','/')){throw 'Resolved source RO FAIL'}}
  foreach($service in @('db','redis')){$volume=if($service -eq 'db'){'metadata_db'}else{'metadata_redis'};$dest=if($service -eq 'db'){'/var/lib/postgresql/data'}else{'/data'};$v=@($cfg.services.$service.volumes);if($v.Count -ne 1 -or $v[0].type -ne 'volume' -or $v[0].source -ne $volume -or $v[0].target -ne $dest -or $cfg.volumes.$volume.name -ne ($metaProject+'_'+$volume)){throw 'Resolved data volumes FAIL'}}
  Write-Host ('PASS resolved/cached '+$metaSha+' / sourceRO/internal/no ports/no main .env/private tmpfs Prisma client')
  if($Phase -eq 'Start'){
    if(& docker @metaArgs ps -a -q){throw 'Existing lab; guarded Stop first'}
    Invoke-Metadata @('create','--no-build');Assert-Actual
    Invoke-Metadata @('start','db','redis')
    $deadline=[DateTime]::UtcNow.AddSeconds(30)
    do{& docker @metaArgs exec -T db pg_isready -U p22 -d wed_snap_metadata_test;if($LASTEXITCODE -eq 0){break};Start-Sleep -Milliseconds 500}while([DateTime]::UtcNow -lt $deadline)
    if($LASTEXITCODE -ne 0){throw 'DB not ready'}
    Assert-Actual;Assert-Datastores;Invoke-Metadata @('start','lab');Assert-Actual;Assert-Datastores
    Invoke-Metadata @('exec','-T','lab','node_modules/.bin/prisma','generate','--schema','prisma/schema.prisma')
    Assert-Actual;Assert-Datastores
    Invoke-Metadata @('exec','-T','lab','node_modules/.bin/prisma','migrate','deploy','--schema','prisma/schema.prisma')
  }elseif($Phase -eq 'Matrix'){
    Assert-Actual;Assert-Datastores
    Invoke-Metadata @('exec','-T','lab','node_modules/.bin/tsx','--tsconfig','tests/p22/tsconfig.json','tests/p22/metadata.integration.ts')
  }elseif($Phase -eq 'Typecheck'){
    Assert-Actual;Assert-Datastores
    Invoke-Metadata @('exec','-T','lab','node_modules/.bin/tsc','-p','tests/p22/tsconfig.json')
  }elseif($Phase -eq 'Logs'){
    Assert-Actual
    Invoke-Metadata @('logs','--timestamps','--no-color')
  }elseif($Phase -eq 'Stop'){
    Assert-Actual;Invoke-Metadata @('stop');Assert-Actual
    Invoke-Metadata @('rm','-f')
    Write-Host 'PASS stopped/removed only metadata lab containers; DB/Redis volumes/logs retained, no reset/down-v/flush'
  }
}finally{[Environment]::SetEnvironmentVariable('WED_METADATA_LAB_SHA',$savedSha,'Process')}
