param([ValidateSet('Start','Typecheck','Logs','Stop')][string] $Phase)
$ErrorActionPreference = 'Stop'
$uiRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
if ((Get-Location).Path -ne $uiRoot) { throw 'Run from verified repository root' }
$uiProject = 'wed-snap-admin-ui-lab'
$uiImage = 'wed-snap-p3-test:local'
$uiArgs = @('compose','-p',$uiProject,'--project-directory',$uiRoot,'--env-file','infra/admin-ui-lab.env.example','-f','infra/compose.admin-ui-lab.yaml')
$uiSavedSha = [Environment]::GetEnvironmentVariable('WED_ADMIN_UI_SHA','Process')
$uiFiles = @('pages/Admin.tsx','lib/api.ts','styles/admin.css','style.css','styles/responsive.css','styles/layout.css','types.ts','lib/platforms.ts')
$uiSha = ($uiFiles | ForEach-Object { (Get-FileHash -LiteralPath (Join-Path 'apps/web/src' $_)).Hash.ToLowerInvariant() }) -join '|'
function Assert-Protected {
  $protected = Get-Content -Raw docs/evidence/p28-20261003-protected-before.json | ConvertFrom-Json
  foreach ($entry in $protected.protected) { if ((Get-FileHash -LiteralPath $entry.path).Hash.ToLowerInvariant() -ne $entry.sha) { throw ('Protected source changed: ' + $entry.path) } }
  Write-Host ('PASS protected historical/source hashes ' + $protected.protected.Count)
}
Assert-Protected
function Invoke-Ui([string[]] $DockerArgs) {
  Write-Host ('COMMAND docker ' + ($uiArgs + $DockerArgs -join ' '))
  & docker @uiArgs @DockerArgs
  if ($LASTEXITCODE -ne 0) { throw 'UI lab Docker command failed' }
}
function Assert-UiActual {
  $id = & docker @uiArgs ps -a -q lab
  if ($LASTEXITCODE -ne 0 -or @($id | Where-Object { $_ }).Count -ne 1) { throw 'Missing/ambiguous UI lab' }
  $raw = & docker inspect $id
  if ($LASTEXITCODE -ne 0) { throw 'UI inspect failed' }
  $c = @((($raw -join "`n") | ConvertFrom-Json))[0]
  if ($c.Config.Labels.'com.docker.compose.project' -ne $uiProject -or $c.Config.Labels.'com.docker.compose.service' -ne 'lab' -or $c.Image -ne $uiImageId -or $c.Config.Image -ne $uiImage -or $c.Config.User -ne 'node' -or ($c.Config.Cmd -join ' ') -ne 'node_modules/.bin/vite --config tests/p28/vite.config.ts --configLoader runner') { throw 'Refuse unverified lab identity' }
  if ($c.HostConfig.PidMode -ne '' -or $c.HostConfig.Privileged -or -not $c.HostConfig.ReadonlyRootfs -or $c.HostConfig.Memory -ne 536870912 -or $c.HostConfig.NanoCpus -ne 750000000 -or $c.HostConfig.PidsLimit -ne 64 -or $c.HostConfig.CapDrop -notcontains 'ALL' -or $c.HostConfig.SecurityOpt -notcontains 'no-new-privileges:true') { throw 'Refuse lab privileges/resources/PID' }
  if ($c.HostConfig.Tmpfs.'/tmp' -ne 'noexec,nosuid,size=32m' -and $c.HostConfig.Tmpfs.'/tmp' -ne 'size=32m,noexec,nosuid') { throw 'Refuse unbounded tmpfs' }
  if ($c.Config.Env -notcontains 'P28_GUARD=wed-snap-admin-ui-lab' -or $c.Config.Env -notcontains ('P28_SOURCE_SHA=' + $uiSha) -or @($c.Config.Env | Where-Object { $_ -match '^(DATABASE_URL|REDIS_URL|ADMIN_SESSION_SECRET|POSTGRES_PASSWORD|MEDIA_ROOT)=' }).Count) { throw 'Refuse data/secret environment or stale source' }
  $nets = @($c.NetworkSettings.Networks.PSObject.Properties.Name)
  if ($nets.Count -ne 1 -or $nets[0] -ne 'wed-snap-admin-ui-lab_lab') { throw 'Refuse foreign networks' }
  $netRaw = & docker network inspect $nets[0]
  if ($LASTEXITCODE -ne 0) { throw 'Lab network inspect failed' }
  $net = @((($netRaw -join "`n") | ConvertFrom-Json))[0]
  if ($net.Internal -or $net.Driver -ne 'bridge' -or $net.Labels.'com.docker.compose.project' -ne $uiProject) { throw 'Refuse foreign/frontend network mismatch' }
  if (@($net.Containers.PSObject.Properties | Where-Object { $_.Name -ne $c.Id }).Count) { throw 'Refuse foreign network member' }
  $ports = @($c.HostConfig.PortBindings.PSObject.Properties)
  if ($ports.Count -ne 1 -or $ports[0].Name -ne '5177/tcp' -or @($ports[0].Value).Count -ne 1 -or $ports[0].Value[0].HostIp -ne '127.0.0.1' -or $ports[0].Value[0].HostPort -ne '5177') { throw 'Refuse non-lab ports' }
  $binds = @($c.Mounts | Where-Object Type -eq bind)
  if ($binds.Count -ne 3 -or @($c.Mounts | Where-Object { $_.Type -notin @('bind','tmpfs') }).Count -or @($c.HostConfig.VolumesFrom | Where-Object { $_ }).Count) { throw 'Refuse data volumes' }
  foreach ($check in @(@('apps/web','/app/apps/web'),@('tests/p28','/app/tests/p28'),@('docs/openapi.json','/app/docs/openapi.json'))) {
    $path = (Resolve-Path -LiteralPath $check[0]).Path.Replace('\','/')
    $desktop = '/run/desktop/mnt/host/' + $path.Substring(0,1).ToLowerInvariant() + '/' + $path.Substring(3)
    $m = @($binds | Where-Object Destination -eq $check[1])
    if ($m.Count -ne 1 -or $m[0].RW -or @($path,$desktop) -notcontains $m[0].Source.Replace('\','/')) { throw 'Refuse source mount' }
  }
  Write-Host ('PASS actual UI lab ' + (@{project=$uiProject;image=$c.Image;container=$c.Id;state=$c.State.Status;dedicatedFrontendBridge=$true;pidPrivate=$true;ports='127.0.0.1:5177';dataVolumes=0;sourceRO=$true;homeSha=$uiSha} | ConvertTo-Json -Compress))
  return $c
}
Write-Host ('UI lab ' + $Phase + ' / UTC ' + [DateTime]::UtcNow.ToString('o') + ' / Asia/Saigon ' + [DateTimeOffset]::UtcNow.ToOffset([TimeSpan]::FromHours(7)).ToString('o'))
try {
  [Environment]::SetEnvironmentVariable('WED_ADMIN_UI_SHA',$uiSha,'Process')
  $cfgRaw = & docker @uiArgs config --format json
  if ($LASTEXITCODE -ne 0) { throw 'Lab resolved config failed' }
  $cfg = ($cfgRaw -join "`n") | ConvertFrom-Json
  $s = $cfg.services.lab
  if (($s.command -join ' ') -ne 'node_modules/.bin/vite --config tests/p28/vite.config.ts --configLoader runner' -or $s.mem_limit -ne '536870912' -or [double]$s.cpus -ne 0.75 -or $s.pids_limit -ne 64 -or $s.environment.P28_GUARD -ne $uiProject -or $s.environment.P28_SOURCE_SHA -ne $uiSha -or @($s.environment.PSObject.Properties).Count -ne 3) { throw 'Unsafe resolved cmd/resources/environment' }
  if ($cfg.name -ne $uiProject -or @($cfg.services.PSObject.Properties).Count -ne 1 -or $s.image -ne $uiImage -or $s.pull_policy -ne 'never' -or $s.user -ne 'node' -or -not $s.read_only -or @($s.depends_on.PSObject.Properties | Where-Object { $_ }).Count -or @($s.volumes).Count -ne 3 -or @($s.volumes | Where-Object { $_.type -ne 'bind' -or -not $_.read_only }).Count -or $cfg.networks.lab.internal -or $cfg.networks.lab.name -ne 'wed-snap-admin-ui-lab_lab' -or @($s.networks.PSObject.Properties).Count -ne 1) { throw 'Unsafe resolved UI lab' }
  if (@($s.ports).Count -ne 1 -or $s.ports[0].host_ip -ne '127.0.0.1' -or $s.ports[0].published -ne '5177' -or $s.ports[0].target -ne 5177) { throw 'Unsafe resolved lab port' }
  Write-Host 'PASS resolved standalone UI lab; no data services/volumes/.env; dedicated frontend bridge and loopback5177'
  $imageRaw = & docker image inspect $uiImage
  if ($LASTEXITCODE -ne 0) { throw 'Required cached test image absent; no pull/build allowed' }
  $image = @((($imageRaw -join "`n") | ConvertFrom-Json))[0]
  if ($image.Os -ne 'linux' -or $image.Config.User -ne 'node' -or @($image.Config.Volumes.PSObject.Properties | Where-Object { $_ }).Count) { throw 'Unsuitable cached test image' }
  $uiImageId = $image.Id
  if ($uiImageId -ne 'sha256:f2a71e620a0c6a99261a184ad39352e4bbf26954e34ccb1cddcb25ffefa115f1') { throw 'Cached image identity changed' }
  Write-Host ('PASS cached image ' + $uiImageId)
  if ($Phase -eq 'Start') {
    if (& docker @uiArgs ps -a -q lab) { throw 'UI lab already exists; inspect/stop guarded lab first' }
    if (Get-NetTCPConnection -LocalPort 5177 -State Listen -ErrorAction SilentlyContinue) { throw 'Port5177 occupied; no fallback' }
    Invoke-Ui @('create','--no-build','lab')
    $c = Assert-UiActual
    if ($c.State.Status -ne 'created') { throw 'Require fresh created lab before start' }
    Invoke-Ui @('start','lab')
    $c = Assert-UiActual
    Write-Host 'Open http://localhost:5177 in test browser; run matrix; Logs preserves raw, Stop only this lab'
  } elseif ($Phase -eq 'Typecheck') {
    $c = Assert-UiActual
    Invoke-Ui @('exec','-T','lab','node_modules/.bin/tsc','-p','apps/web/tsconfig.json')
    Invoke-Ui @('exec','-T','lab','node_modules/.bin/tsc','-p','tests/p28/tsconfig.json')

    Write-Host 'PASS web + React UI lab TypeScript checks sequential'
  } elseif ($Phase -eq 'Logs') {
    $c = Assert-UiActual
    Invoke-Ui @('logs','--timestamps','--no-color','lab')
  } elseif ($Phase -eq 'Stop') {
    $c = Assert-UiActual
    Invoke-Ui @('stop','lab')
    $c = Assert-UiActual
    if ($c.State.Running) { throw 'Refuse removing running lab' }
    Invoke-Ui @('rm','-f','lab')
    if (& docker @uiArgs ps -a -q lab) { throw 'Lab container remains' }
    $netRaw = & docker network inspect wed-snap-admin-ui-lab_lab
    if ($LASTEXITCODE -ne 0) { throw 'Lab network inspect failed' }
    $net = @((($netRaw -join "`n") | ConvertFrom-Json))[0]
    if ($net.Name -ne 'wed-snap-admin-ui-lab_lab' -or $net.Labels.'com.docker.compose.project' -ne $uiProject -or @($net.Containers.PSObject.Properties).Count) { throw 'Refuse removing foreign/nonempty network' }
    & docker network rm wed-snap-admin-ui-lab_lab
    if ($LASTEXITCODE -ne 0) { throw 'Lab network cleanup failed' }
    Write-Host 'PASS UI lab stopped/removed/network removed; no volumes removed; other stacks untouched'
  }
} finally { [Environment]::SetEnvironmentVariable('WED_ADMIN_UI_SHA',$uiSavedSha,'Process'); Assert-Protected }


