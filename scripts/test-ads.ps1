param([ValidateSet('Start','Backend','Typecheck','Stop')][string] $Phase)
$ErrorActionPreference='Stop'
$adsRoot=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
if((Get-Location).Path -ne $adsRoot -or $adsRoot -ne 'D:\WED SNAP'){throw 'Wrong repository'}
$adsProject='wed-snap-ads-lab'
$adsArgs=@('compose','-p',$adsProject,'--project-directory',$adsRoot,'--env-file','infra/ads-lab.env.example','-f','infra/compose.ads-lab.yaml')
$savedSha=[Environment]::GetEnvironmentVariable('WED_ADS_LAB_SHA','Process')
$adsSha=(Get-FileHash apps/api/src/services/ads.service.ts).Hash.ToLowerInvariant()
$images=@{}
function Invoke-Ads([string[]] $ArgsList){Write-Host ('COMMAND docker '+($adsArgs+$ArgsList -join ' ')); & docker @adsArgs @ArgsList; if($LASTEXITCODE -ne 0){throw 'Ads lab command failed (raw retained)'}}
function Assert-Actual {
  $allIds=@(& docker @adsArgs ps -a -q)
  if($LASTEXITCODE -ne 0 -or $allIds.Count -ne 3){throw 'Require exactly three lab containers'}
  foreach($service in @('db','redis','lab')){
    $ids=@(& docker @adsArgs ps -a -q $service)
    if($LASTEXITCODE -ne 0 -or $ids.Count -ne 1){throw 'Ambiguous lab container'}
    $c=@(((& docker inspect $ids[0]) -join "`n" | ConvertFrom-Json))[0]
    $image=$cfg.services.$service.image
    if($c.Config.Labels.'com.docker.compose.project' -ne $adsProject -or $c.Config.Labels.'com.docker.compose.service' -ne $service -or $c.Image -ne $images[$image] -or $c.Config.Image -ne $image -or $c.HostConfig.PidMode -ne '' -or $c.HostConfig.Privileged -or @($c.HostConfig.PortBindings.PSObject.Properties).Count){throw 'Actual identity/PID/ports FAIL'}
    if(@($c.NetworkSettings.Networks.PSObject.Properties).Count -ne 1 -or $c.NetworkSettings.Networks.PSObject.Properties.Name -ne 'wed-snap-ads-lab_lab'){throw 'Foreign network'}
    $n=@(((& docker network inspect wed-snap-ads-lab_lab)-join "`n"|ConvertFrom-Json))[0]
    if(-not $n.Internal -or $n.Labels.'com.docker.compose.project' -ne $adsProject){throw 'Network guard FAIL'}
    if(@($n.Containers.PSObject.Properties.Name | Where-Object { $_ -and $allIds -notcontains $_ }).Count){throw 'Foreign network endpoint'}
    if($service -eq 'lab'){
      if($c.Config.User -ne 'node' -or -not $c.HostConfig.ReadonlyRootfs -or $c.HostConfig.Memory -ne 536870912 -or $c.HostConfig.PidsLimit -ne 64 -or $c.HostConfig.CapDrop -notcontains 'ALL' -or ($c.Config.Cmd -join ' ') -ne 'node -e setInterval(() => {}, 60000)'){throw 'Lab command/resource guard FAIL'}
      foreach($v in @('P20_GUARD=wed-snap-ads-lab',('P20_SOURCE_SHA='+$adsSha),'DATABASE_URL=postgresql://p20@db:5432/wed_snap_ads_test','REDIS_URL=redis://redis:6379/14','MEDIA_ROOT=/tmp/p20-unused-media','APP_ORIGIN=http://p20.local','ADMIN_SESSION_SECRET=p20-isolated-fixture-not-a-production-secret')){if($c.Config.Env -notcontains $v){throw 'Env guard FAIL'}}
      if(@($c.Config.Env|Where-Object {$_ -match '^(HTTP_PROXY|HTTPS_PROXY|ALL_PROXY|POSTGRES_PASSWORD)='}).Count){throw 'Foreign env'}
      $binds=@($c.Mounts|Where-Object Type -eq bind)
      if($binds.Count -ne 4 -or @($c.Mounts|Where-Object {$_.Type -notin @('bind','tmpfs')}).Count){throw 'Unexpected data/media mount'}
      foreach($pair in @(@('apps/api','/app/apps/api'),@('packages/shared','/app/packages/shared'),@('prisma','/app/prisma'),@('tests/p20','/app/tests/p20'))){
        $path=(Resolve-Path $pair[0]).Path.Replace('\','/');$desktop='/run/desktop/mnt/host/d/'+$path.Substring(3)
        $m=@($binds|Where-Object Destination -eq $pair[1]);if($m.Count -ne 1 -or $m[0].RW -or @($path,$desktop) -notcontains $m[0].Source.Replace('\','/')){throw 'Source RO guard FAIL'}
      }
    }else{
      $expectedMemory=if($service -eq 'db'){201326592}else{100663296}
      $expectedPids=if($service -eq 'db'){64}else{32}
      if($c.HostConfig.Memory -ne $expectedMemory -or $c.HostConfig.PidsLimit -ne $expectedPids){throw 'Data service resources guard FAIL'}
      $vol=if($service -eq 'db'){'ads_db'}else{'ads_redis'}
      $dest=if($service -eq 'db'){'/var/lib/postgresql/data'}else{'/data'}
      if(@($c.Mounts).Count -ne 1 -or $c.Mounts[0].Type -ne 'volume' -or $c.Mounts[0].Name -ne ($adsProject+'_'+$vol) -or $c.Mounts[0].Destination -ne $dest){throw 'Foreign data volume'}
      $v=@(((& docker volume inspect $c.Mounts[0].Name)-join "`n"|ConvertFrom-Json))[0]
      if($v.Labels.'com.docker.compose.project' -ne $adsProject){throw 'Volume label guard FAIL'}
      if($service -eq 'db' -and ($c.Config.Env -notcontains 'POSTGRES_DB=wed_snap_ads_test' -or $c.Config.Env -notcontains 'POSTGRES_USER=p20')){throw 'Actual DB guard FAIL'}
      if($service -eq 'redis' -and ($c.Config.Cmd -join ' ') -ne 'redis-server --appendonly yes --maxmemory 64mb --maxmemory-policy noeviction'){throw 'Actual Redis guard FAIL'}
    }
    Write-Host ('PASS actual '+(@{project=$adsProject;service=$service;id=$c.Id;image=$c.Image;state=$c.State.Status;sourceSHA=$adsSha;pidPrivate=$true;ports=0;networkInternal=$true;mainDataMounted=$false}|ConvertTo-Json -Compress))
  }
}
try{
  [Environment]::SetEnvironmentVariable('WED_ADS_LAB_SHA',$adsSha,'Process')
  Write-Host ('P20 '+$Phase+' UTC '+[DateTime]::UtcNow.ToString('o')+' PowerShell '+$PSVersionTable.PSVersion)
  $cfg=(& docker @adsArgs config --format json)-join "`n"|ConvertFrom-Json
  if($LASTEXITCODE -ne 0 -or $cfg.name -ne $adsProject -or @($cfg.services.PSObject.Properties).Count -ne 3 -or -not $cfg.networks.lab.internal -or $cfg.networks.lab.name -ne 'wed-snap-ads-lab_lab'){throw 'Resolved project/network guard FAIL'}
  foreach($svc in @('db','redis','lab')){
    $s=$cfg.services.$svc
    $expectedImage=if($svc -eq 'db'){'postgres:16.10-bookworm'}elseif($svc -eq 'redis'){'redis:7.4.6-bookworm'}else{'wed-snap-p3-test:local'}
    if($s.image -ne $expectedImage -or @($s.networks.PSObject.Properties.Name).Count -ne 1 -or $s.networks.PSObject.Properties.Name -ne 'lab' -or $s.pid -or $s.privileged){throw 'Resolved image/network/PID guard FAIL'}
    if($s.pull_policy -ne 'never' -or $s.build -or @($s.ports | Where-Object { $_ }).Count){throw 'Build/pull/ports prohibited'}
    $images[$s.image]=@(((& docker image inspect $s.image)-join "`n"|ConvertFrom-Json))[0].Id
    if($LASTEXITCODE -ne 0 -or -not $images[$s.image]){throw 'Cached image missing'}
  }
  if($cfg.services.lab.environment.DATABASE_URL -ne 'postgresql://p20@db:5432/wed_snap_ads_test' -or $cfg.services.lab.environment.REDIS_URL -ne 'redis://redis:6379/14' -or @($cfg.services.lab.volumes).Count -ne 4 -or @($cfg.services.lab.volumes|Where-Object {$_.type -ne 'bind' -or -not $_.read_only}).Count -or @($cfg.volumes.PSObject.Properties).Count -ne 2){throw 'Resolved env/mount guard FAIL'}
  if($cfg.services.lab.user -ne 'node' -or -not $cfg.services.lab.read_only -or $cfg.services.lab.environment.MEDIA_ROOT -ne '/tmp/p20-unused-media' -or ($cfg.services.lab.command -join ' ') -ne 'node -e setInterval(() => {}, 60000)'){throw 'Resolved lab command/media/user guard FAIL'}
  foreach($svc in @('db','redis')){
    $volume=if($svc -eq 'db'){'ads_db'}else{'ads_redis'}
    $dest=if($svc -eq 'db'){'/var/lib/postgresql/data'}else{'/data'}
    $v=@($cfg.services.$svc.volumes)
    if($v.Count -ne 1 -or $v[0].type -ne 'volume' -or $v[0].source -ne $volume -or $v[0].target -ne $dest -or $cfg.volumes.$volume.name -ne ($adsProject+'_'+$volume)){throw 'Resolved foreign data mount'}
  }
  Write-Host 'PASS resolved/cached; actual created guard required before start/migrate/fixtures; no main .env/ports/worker/media'
  if($Phase -eq 'Start'){
    if(& docker @adsArgs ps -a -q){throw 'Existing lab; use guarded Stop first'}
    Invoke-Ads @('create','--no-build')
    Assert-Actual
    Invoke-Ads @('start','db','redis')
    $deadline=[DateTime]::UtcNow.AddSeconds(45)
    do { & docker @adsArgs exec -T db pg_isready -U p20 -d wed_snap_ads_test; if($LASTEXITCODE -eq 0){break};Start-Sleep -Milliseconds 500 }while([DateTime]::UtcNow -lt $deadline)
    if($LASTEXITCODE -ne 0){throw 'Lab DB not ready'}
    Assert-Actual
    Invoke-Ads @('start','lab')
    Assert-Actual
    Invoke-Ads @('exec','-T','lab','node_modules/.bin/prisma','migrate','deploy')
  }elseif($Phase -eq 'Backend'){
    Assert-Actual
    Invoke-Ads @('exec','-T','lab','node_modules/.bin/tsx','tests/p20/backend.ts')
  }elseif($Phase -eq 'Typecheck'){
    Assert-Actual
    Invoke-Ads @('exec','-T','lab','node_modules/.bin/tsc','-p','tests/p20/tsconfig.backend.json')
  }elseif($Phase -eq 'Stop'){
    Assert-Actual
    Invoke-Ads @('stop')
    Assert-Actual
    Invoke-Ads @('rm','-f')
    Write-Host 'PASS stopped only ads lab containers; fixture rows/keys individually cleaned; volumes/logs retained; no down-v/reset'
  }
}finally{[Environment]::SetEnvironmentVariable('WED_ADS_LAB_SHA',$savedSha,'Process')}


