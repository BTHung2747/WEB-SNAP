param([ValidateSet('Start','Matrix','Generate','Typecheck','Logs','Stop')][string]$Phase)
$ErrorActionPreference='Stop'
$p26Root=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
if((Get-Location).Path -ne $p26Root -or $p26Root -ne 'D:\WED SNAP'){throw 'Wrong workspace'}
$p26Project='wed-snap-contract-admin-lab';$p26Image='wed-snap-p3-test:local'
$p26Args=@('compose','-p',$p26Project,'--project-directory',$p26Root,'--env-file','infra/admin-contract-lab.env.example','-f','infra/compose.admin-contract-lab.yaml')
$p26Paths=@('apps/api/src/openapi.ts','apps/api/src/main.ts','apps/api/src/controllers/session.controller.ts','apps/api/src/controllers/jobs.controller.ts','apps/api/src/controllers/downloads.controller.ts','apps/api/src/controllers/admin.controller.ts','apps/api/src/controllers/ads.controller.ts')
$p26Fingerprint=($p26Paths|ForEach-Object{$_+':'+(Get-FileHash -LiteralPath $_).Hash.ToLowerInvariant()}) -join '|'
$p26Hasher=[Security.Cryptography.SHA256]::Create();$p26Sha=([BitConverter]::ToString($p26Hasher.ComputeHash([Text.Encoding]::UTF8.GetBytes($p26Fingerprint)))).Replace('-','').ToLowerInvariant();$p26Hasher.Dispose()
$p26Saved=[Environment]::GetEnvironmentVariable('WED_ADMIN_CONTRACT_SHA','Process')
$p26Binds=@(@('apps/api','/app/apps/api'),@('packages/shared','/app/packages/shared'),@('prisma','/app/prisma'),@('tests/p26','/app/tests/p26'),@('tsconfig.json','/app/tsconfig.json'),@('docs/openapi.json','/app/docs/openapi.json'))
$p26Env=@('P26_GUARD=wed-snap-contract-admin-lab',('P26_SOURCE_SHA='+$p26Sha),'DATABASE_URL=postgresql://p26@127.0.0.1:9/wed_snap_admin_contract_unused','REDIS_URL=redis://127.0.0.1:9/13','MEDIA_ROOT=/media','APP_ORIGIN=http://p26.invalid','ADMIN_SESSION_SECRET=p26-docs-public-fixture-not-production-secret','VERIFIED_PLATFORMS=youtube','NODE_OPTIONS=--max-old-space-size=384')
function Invoke-P26([string[]]$Extra){Write-Host ('COMMAND docker '+($p26Args+$Extra -join ' '));& docker @p26Args @Extra;if($LASTEXITCODE -ne 0){throw 'P26 lab command failed; raw retained'}}
function Protect-P26 {
  $baseline=Get-Content docs/evidence/p26-20261003-protected-before.json -Raw|ConvertFrom-Json
  foreach($p in $baseline.protected){if((Get-FileHash -LiteralPath $p.path).Hash.ToLowerInvariant() -ne $p.sha){throw ('Protected source changed '+$p.path)}}
  Write-Host ('PASS protected '+$baseline.protected.Count+' hashes unchanged; lifecycle/cleanup/R9/auth/validation/services/worker/schema/UI/ads/infra')
}
function Actual-P26 {
  $ids=@(& docker @p26Args ps -a -q);if($LASTEXITCODE -ne 0 -or $ids.Count -ne 1){throw 'Require exactly one own lab container'}
  $c=@(((& docker inspect $ids[0])-join "`n"|ConvertFrom-Json))[0]
  if($c.Config.Labels.'com.docker.compose.project' -ne $p26Project -or $c.Config.Labels.'com.docker.compose.service' -ne 'lab' -or $c.Image -ne $p26ImageId -or $c.Config.Image -ne $p26Image -or $c.Config.User -ne 'node' -or $c.Config.WorkingDir -ne '/app' -or ($c.Config.Cmd -join ' ') -ne 'node -e setInterval(() => {}, 60000)'){throw 'Actual identity/image/cmd FAIL'}
  if($c.HostConfig.NetworkMode -ne 'none' -or @($c.NetworkSettings.Networks.PSObject.Properties.Name|Where-Object{$_ -ne 'none'}).Count -or $c.HostConfig.PidMode -ne '' -or @($c.HostConfig.PortBindings.PSObject.Properties|Where-Object{$_.Name}).Count -or $c.HostConfig.Privileged -or -not $c.HostConfig.ReadonlyRootfs -or @($c.HostConfig.VolumesFrom|Where-Object{$_}).Count){throw 'Actual network/privatePID/ports/rootfs FAIL'}
  if($c.HostConfig.Memory -ne 536870912 -or $c.HostConfig.NanoCpus -ne 750000000 -or $c.HostConfig.PidsLimit -ne 64 -or $c.HostConfig.CapDrop -notcontains 'ALL' -or $c.HostConfig.SecurityOpt -notcontains 'no-new-privileges:true'){throw 'Actual resources/privileges FAIL'}
  foreach($e in $p26Env){if($c.Config.Env -notcontains $e){throw 'Actual env/datastore sentinels FAIL'}}
  if(@($c.Config.Env|Where-Object{$_ -match '^(HTTP_PROXY|HTTPS_PROXY|ALL_PROXY|POSTGRES_PASSWORD|ADMIN_SECRET)='}).Count){throw 'Foreign env'}
  if(@($c.Mounts|Where-Object Type -eq bind).Count -ne 6 -or @($c.Mounts|Where-Object{$_.Type -notin @('bind','tmpfs')}).Count -or @($c.HostConfig.Tmpfs.PSObject.Properties).Count -ne 3){throw 'Foreign mounts/volumes'}
  foreach($pair in $p26Binds){$expected=(Resolve-Path -LiteralPath $pair[0]).Path.Replace('\','/');$desktop='/run/desktop/mnt/host/d/'+$expected.Substring(3);$mount=@($c.Mounts|Where-Object Destination -eq $pair[1]);if($mount.Count -ne 1 -or $mount[0].RW -or @($expected,$desktop) -notcontains $mount[0].Source.Replace('\','/')){throw 'Actual sourceRO FAIL'}}
  foreach($target in @('/tmp','/media','/app/node_modules/.prisma')){if($c.HostConfig.Tmpfs.$target -notmatch 'uid=1000' -or $c.HostConfig.Tmpfs.$target -notmatch 'gid=1000' -or $c.HostConfig.Tmpfs.$target -notmatch 'nosuid'){throw 'Private tmpfs FAIL'}}
  if($c.HostConfig.Tmpfs.'/app/node_modules/.prisma' -notmatch '\bexec\b'){throw 'Client tmpfs requires cached engine exec'}
  Write-Host ('PASS actual '+(@{project=$p26Project;containerId=$c.Id;imageId=$c.Image;sourceSha=$p26Sha;cmd=$c.Config.Cmd;state=$c.State.Status;network='none';pid='private';ports=0;datastoreServices=0;volumes=0;datastoreSentinels='own unused DB / loopback9 Redis13; constructors denied before load';sourceRO=$true;mainData=$false}|ConvertTo-Json -Compress));return $c
}
Write-Host ('P26 '+$Phase+' UTC '+[DateTime]::UtcNow.ToString('o')+' VN '+[DateTimeOffset]::Now.ToString('o')+' PowerShell '+$PSVersionTable.PSVersion)
try {
  [Environment]::SetEnvironmentVariable('WED_ADMIN_CONTRACT_SHA',$p26Sha,'Process');Protect-P26
  $cfg=((& docker @p26Args config --format json)-join "`n")|ConvertFrom-Json;if($LASTEXITCODE -ne 0){throw 'Resolve FAIL'}
  $s=$cfg.services.lab
  if($cfg.name -ne $p26Project -or @($cfg.services.PSObject.Properties).Count -ne 1 -or @($cfg.volumes.PSObject.Properties|Where-Object{$_.Name}).Count -or $s.image -ne $p26Image -or $s.pull_policy -ne 'never' -or $s.network_mode -ne 'none' -or $s.user -ne 'node' -or -not $s.read_only -or @($s.ports|Where-Object{$_}).Count -or @($s.depends_on.PSObject.Properties|Where-Object{$_.Name}).Count -or ($s.command -join ' ') -ne 'node -e setInterval(() => {}, 60000)' -or @($s.volumes).Count -ne 6 -or @($s.tmpfs).Count -ne 3){throw 'Resolved isolation FAIL'}
  if($s.mem_limit -ne '536870912' -or [double]$s.cpus -ne .75 -or $s.pids_limit -ne 64 -or $s.cap_drop -notcontains 'ALL' -or $s.security_opt -notcontains 'no-new-privileges:true'){throw 'Resolved bounds FAIL'}
  foreach($e in $p26Env){$name,$value=$e -split '=',2;if($s.environment.$name -ne $value){throw 'Resolved env FAIL'}}
  foreach($pair in $p26Binds){$m=@($s.volumes|Where-Object target -eq $pair[1]);if($m.Count -ne 1 -or $m[0].type -ne 'bind' -or -not $m[0].read_only -or $m[0].source.Replace('\','/') -ne (Resolve-Path -LiteralPath $pair[0]).Path.Replace('\','/')){throw 'Resolved sourceRO FAIL'}}
  $image=@(((& docker image inspect $p26Image)-join "`n"|ConvertFrom-Json))[0];if($LASTEXITCODE -ne 0 -or $image.Id -ne 'sha256:f2a71e620a0c6a99261a184ad39352e4bbf26954e34ccb1cddcb25ffefa115f1' -or $image.Os -ne 'linux' -or @($image.Config.Volumes.PSObject.Properties|Where-Object{$_.Name}).Count){throw 'Wrong/absent cached image; no build/pull fallback'};$p26ImageId=$image.Id
  Write-Host ('PASS resolved/cache/sourceRO/networknone/noports/noDataServices '+$p26Sha)
  if($Phase -eq 'Start'){
    if(& docker @p26Args ps -a -q){throw 'Existing lab; guarded Stop first'}
    Invoke-P26 @('create','--no-build');$c=Actual-P26;if($c.State.Status -ne 'created'){throw 'Must be freshly created'}
    Invoke-P26 @('start');$c=Actual-P26
    Invoke-P26 @('exec','-T','lab','node_modules/.bin/prisma','generate','--schema','prisma/schema.prisma')
  }elseif($Phase -eq 'Matrix'){$c=Actual-P26;Invoke-P26 @('exec','-T','lab','node_modules/.bin/tsx','--tsconfig','tests/p26/tsconfig.json','tests/p26/matrix.ts')
  }elseif($Phase -eq 'Generate'){
    $c=Actual-P26;Invoke-P26 @('exec','-T','lab','node_modules/.bin/tsx','--tsconfig','tests/p26/tsconfig.json','tests/p26/generate.ts')
    $c=Actual-P26;Protect-P26
    Write-Host 'COMMAND docker compose exec -T lab cat /tmp/p26.generated.json -> verified D:\WED SNAP\docs\openapi.json'
    $json=@(& docker @p26Args exec -T lab cat /tmp/p26.generated.json);if($LASTEXITCODE -ne 0){throw 'Read generated file FAIL'}
    $parsed=($json -join "`n")|ConvertFrom-Json;if($parsed.openapi -ne '3.0.0' -or @($parsed.paths.PSObject.Properties).Count -ne 19){throw 'Generated snapshot guard FAIL'}
    if((Resolve-Path -LiteralPath docs/openapi.json).Path -ne (Join-Path $p26Root 'docs\openapi.json')){throw 'Snapshot target outside workspace'}
    [IO.File]::WriteAllText((Join-Path $p26Root 'docs\openapi.json'),($json -join "`n")+"`n",[Text.UTF8Encoding]::new($false));Write-Host ('PASS generated snapshot SHA '+(Get-FileHash docs/openapi.json).Hash.ToLowerInvariant())
  }elseif($Phase -eq 'Typecheck'){$c=Actual-P26;Invoke-P26 @('exec','-T','lab','node_modules/.bin/tsc','-p','tests/p26/tsconfig.json')
  }elseif($Phase -eq 'Logs'){$c=Actual-P26;Invoke-P26 @('logs','--timestamps','--no-color')
  }elseif($Phase -eq 'Stop'){$c=Actual-P26;Invoke-P26 @('stop');$c=Actual-P26;Invoke-P26 @('rm','-f');if(& docker @p26Args ps -a -q){throw 'Teardown incomplete'};Write-Host 'PASS stopped/removed only offline OpenAPI lab; no data services/volumes/rows/charged used; historical lab/main untouched'}
  Protect-P26
}finally{[Environment]::SetEnvironmentVariable('WED_ADMIN_CONTRACT_SHA',$p26Saved,'Process')}


