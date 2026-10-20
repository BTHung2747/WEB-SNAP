param([ValidateSet('Start','Typecheck','Logs','Stop')][string] $Phase)
$ErrorActionPreference = 'Stop'
$uiRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
if ((Get-Location).Path -ne $uiRoot) { throw 'Run from verified repository root' }
$uiProject = 'wed-snap-ui-lab'
$uiImage = 'wed-snap-p3-test:local'
$uiArgs = @('compose','-p',$uiProject,'--project-directory',$uiRoot,'--env-file','infra/ui-lab.env.example','-f','infra/compose.ui-lab.yaml')
$uiSavedSha = [Environment]::GetEnvironmentVariable('WED_UI_LAB_SHA','Process')
$uiSha = (Get-FileHash -LiteralPath apps/web/src/pages/Home.tsx -Algorithm SHA256).Hash.ToLowerInvariant()
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
  if ($c.Config.Labels.'com.docker.compose.project' -ne $uiProject -or $c.Config.Labels.'com.docker.compose.service' -ne 'lab' -or $c.Image -ne $uiImageId -or $c.Config.Image -ne $uiImage -or $c.Config.User -ne 'node' -or ($c.Config.Cmd -join ' ') -ne 'node_modules/.bin/vite --config tests/p19/vite.config.ts --configLoader runner') { throw 'Refuse unverified lab identity' }
  if ($c.HostConfig.PidMode -ne '' -or $c.HostConfig.Privileged -or -not $c.HostConfig.ReadonlyRootfs -or $c.HostConfig.Memory -ne 402653184 -or $c.HostConfig.PidsLimit -ne 64 -or $c.HostConfig.CapDrop -notcontains 'ALL' -or $c.HostConfig.SecurityOpt -notcontains 'no-new-privileges:true') { throw 'Refuse lab privileges/resources/PID' }
  if ($c.Config.Env -notcontains 'P19_UI_GUARD=wed-snap-ui-lab' -or $c.Config.Env -notcontains ('P19_SOURCE_SHA=' + $uiSha) -or @($c.Config.Env | Where-Object { $_ -match '^(DATABASE_URL|REDIS_URL|ADMIN_SESSION_SECRET|POSTGRES_PASSWORD|MEDIA_ROOT)=' }).Count) { throw 'Refuse data/secret environment or stale source' }
  $nets = @($c.NetworkSettings.Networks.PSObject.Properties.Name)
  if ($nets.Count -ne 1 -or $nets[0] -ne 'wed-snap-ui-lab_lab') { throw 'Refuse foreign networks' }
  $netRaw = & docker network inspect $nets[0]
  if ($LASTEXITCODE -ne 0) { throw 'Lab network inspect failed' }
  $net = @((($netRaw -join "`n") | ConvertFrom-Json))[0]
  if ($net.Internal -or $net.Driver -ne 'bridge' -or $net.Labels.'com.docker.compose.project' -ne $uiProject) { throw 'Refuse foreign/frontend network mismatch' }
  $ports = @($c.HostConfig.PortBindings.PSObject.Properties)
  if ($ports.Count -ne 1 -or $ports[0].Name -ne '5175/tcp' -or @($ports[0].Value).Count -ne 1 -or $ports[0].Value[0].HostIp -ne '127.0.0.1' -or $ports[0].Value[0].HostPort -ne '5175') { throw 'Refuse non-lab ports' }
  $binds = @($c.Mounts | Where-Object Type -eq bind)
  if ($binds.Count -ne 3 -or @($c.Mounts | Where-Object { $_.Type -notin @('bind','tmpfs') }).Count -or @($c.HostConfig.VolumesFrom | Where-Object { $_ }).Count) { throw 'Refuse data volumes' }
  foreach ($check in @(@('apps/web','/app/apps/web'),@('tests/p19','/app/tests/p19'),@('tests/p20','/app/tests/p20'))) {
    $path = (Resolve-Path -LiteralPath $check[0]).Path.Replace('\','/')
    $desktop = '/run/desktop/mnt/host/' + $path.Substring(0,1).ToLowerInvariant() + '/' + $path.Substring(3)
    $m = @($binds | Where-Object Destination -eq $check[1])
    if ($m.Count -ne 1 -or $m[0].RW -or @($path,$desktop) -notcontains $m[0].Source.Replace('\','/')) { throw 'Refuse source mount' }
  }
  Write-Host ('PASS actual UI lab ' + (@{project=$uiProject;image=$c.Image;container=$c.Id;state=$c.State.Status;dedicatedFrontendBridge=$true;pidPrivate=$true;ports='127.0.0.1:5175';dataVolumes=0;sourceRO=$true;homeSha=$uiSha} | ConvertTo-Json -Compress))
  return $c
}
Write-Host ('UI lab ' + $Phase + ' / UTC ' + [DateTime]::UtcNow.ToString('o') + ' / Asia/Saigon ' + [DateTimeOffset]::UtcNow.ToOffset([TimeSpan]::FromHours(7)).ToString('o'))
try {
  [Environment]::SetEnvironmentVariable('WED_UI_LAB_SHA',$uiSha,'Process')
  $cfgRaw = & docker @uiArgs config --format json
  if ($LASTEXITCODE -ne 0) { throw 'Lab resolved config failed' }
  $cfg = ($cfgRaw -join "`n") | ConvertFrom-Json
  $s = $cfg.services.lab
  if ($cfg.name -ne $uiProject -or @($cfg.services.PSObject.Properties).Count -ne 1 -or $s.image -ne $uiImage -or $s.pull_policy -ne 'never' -or $s.user -ne 'node' -or -not $s.read_only -or @($s.depends_on.PSObject.Properties | Where-Object { $_ }).Count -or @($s.volumes).Count -ne 3 -or @($s.volumes | Where-Object { $_.type -ne 'bind' -or -not $_.read_only }).Count -or $cfg.networks.lab.internal -or $cfg.networks.lab.name -ne 'wed-snap-ui-lab_lab' -or @($s.networks.PSObject.Properties).Count -ne 1) { throw 'Unsafe resolved UI lab' }
  if (@($s.ports).Count -ne 1 -or $s.ports[0].host_ip -ne '127.0.0.1' -or $s.ports[0].published -ne '5175' -or $s.ports[0].target -ne 5175) { throw 'Unsafe resolved lab port' }
  Write-Host 'PASS resolved standalone UI lab; no data services/volumes/.env; dedicated frontend bridge and loopback5175'
  $imageRaw = & docker image inspect $uiImage
  if ($LASTEXITCODE -ne 0) { throw 'Required cached test image absent; no pull/build allowed' }
  $image = @((($imageRaw -join "`n") | ConvertFrom-Json))[0]
  if ($image.Os -ne 'linux' -or $image.Config.User -ne 'node' -or @($image.Config.Volumes.PSObject.Properties | Where-Object { $_ }).Count) { throw 'Unsuitable cached test image' }
  $uiImageId = $image.Id
  Write-Host ('PASS cached image ' + $uiImageId)
  if ($Phase -eq 'Start') {
    if (& docker @uiArgs ps -a -q lab) { throw 'UI lab already exists; inspect/stop guarded lab first' }
    Invoke-Ui @('create','--no-build','lab')
    $c = Assert-UiActual
    if ($c.State.Status -ne 'created') { throw 'Require fresh created lab before start' }
    Invoke-Ui @('start','lab')
    $c = Assert-UiActual
    Write-Host 'Open http://localhost:5175 in test browser; run matrix; Logs preserves raw, Stop only this lab'
  } elseif ($Phase -eq 'Typecheck') {
    $c = Assert-UiActual
    Invoke-Ui @('exec','-T','lab','node_modules/.bin/tsc','-p','apps/web/tsconfig.json')
    Invoke-Ui @('exec','-T','lab','node_modules/.bin/tsc','-p','tests/p19/tsconfig.json')
    Invoke-Ui @('exec','-T','lab','node_modules/.bin/tsc','-p','tests/p20/tsconfig.ui.json')
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
    $netRaw = & docker network inspect wed-snap-ui-lab_lab
    if ($LASTEXITCODE -ne 0) { throw 'Lab network inspect failed' }
    $net = @((($netRaw -join "`n") | ConvertFrom-Json))[0]
    if ($net.Name -ne 'wed-snap-ui-lab_lab' -or $net.Labels.'com.docker.compose.project' -ne $uiProject -or @($net.Containers.PSObject.Properties).Count) { throw 'Refuse removing foreign/nonempty network' }
    & docker network rm wed-snap-ui-lab_lab
    if ($LASTEXITCODE -ne 0) { throw 'Lab network cleanup failed' }
    Write-Host 'PASS UI lab stopped/removed/network removed; no volumes removed; other stacks untouched'
  }
} finally { [Environment]::SetEnvironmentVariable('WED_UI_LAB_SHA',$uiSavedSha,'Process') }

