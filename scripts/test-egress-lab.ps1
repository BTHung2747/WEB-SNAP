param([ValidateSet('All','Matrix','Regression','Syntax')][string] $Phase = 'All')
$ErrorActionPreference = 'Stop'
$labRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
if ((Get-Location).Path -ne $labRoot) { throw 'Run from the verified repository root first' }
$labProject = 'wed-snap-egress-lab'
$labImage = 'wed-snap-p3-egress:local'
$labArgs = @('compose','-p',$labProject,'--project-directory',$labRoot,'--env-file','infra/egress-lab.env.example','-f','infra/compose.egress-lab.yaml')
$labSha = (Get-FileHash -LiteralPath 'apps/egress/src/egress.py' -Algorithm SHA256).Hash.ToLowerInvariant()
$savedShaEnv = [Environment]::GetEnvironmentVariable('WED_EGRESS_LAB_SHA','Process')
$savedPhaseEnv = [Environment]::GetEnvironmentVariable('WED_EGRESS_LAB_PHASE','Process')
$labImageId = $null
$created = $false
function Invoke-Lab([string[]] $DockerArgs) {
    Write-Output ('COMMAND docker ' + ($labArgs + $DockerArgs -join ' '))
    & docker @labArgs @DockerArgs
    if ($LASTEXITCODE -ne 0) { throw 'Egress lab Docker command failed' }
}
function Read-LabContainer {
    $id = & docker @labArgs ps -a -q lab
    if ($LASTEXITCODE -ne 0 -or @($id | Where-Object { $_ }).Count -ne 1) { throw 'Missing/ambiguous lab container' }
    $raw = & docker inspect $id
    if ($LASTEXITCODE -ne 0) { throw 'Lab inspect failed' }
    return @((($raw -join "`n") | ConvertFrom-Json))[0]
}
function Assert-LabActual {
    $c = Read-LabContainer
    if ($c.Config.Labels.'com.docker.compose.project' -ne $labProject -or $c.Config.Labels.'com.docker.compose.service' -ne 'lab' -or $c.Config.Image -ne $labImage -or $c.Image -ne $labImageId -or $c.Config.User -ne '65534:65534' -or ($c.Config.Cmd -join ' ') -ne 'python /lab/tests/p18_egress_lab.py') { throw 'Refuse unverified lab identity/image/command' }
    if ($c.HostConfig.NetworkMode -ne 'none' -or @($c.NetworkSettings.Networks.PSObject.Properties.Name | Where-Object { $_ -and $_ -ne 'none' }).Count -or $c.HostConfig.PidMode -ne '' -or @($c.HostConfig.PortBindings.PSObject.Properties | Where-Object { $_ }).Count -or -not $c.HostConfig.ReadonlyRootfs -or $c.HostConfig.Privileged -or @($c.HostConfig.VolumesFrom | Where-Object { $_ }).Count) { throw 'Refuse unsafe lab network/PID/ports/rootfs' }
    if ($c.HostConfig.Memory -ne 134217728 -or $c.HostConfig.PidsLimit -ne 32 -or $c.HostConfig.CapDrop -notcontains 'ALL' -or $c.HostConfig.SecurityOpt -notcontains 'no-new-privileges:true') { throw 'Refuse unsafe lab resource/privilege bounds' }
    if ($c.Config.Env -notcontains 'EGRESS_LAB_GUARD=wed-snap-egress-lab' -or $c.Config.Env -notcontains ('EGRESS_LAB_SHA=' + $labSha) -or $c.Config.Env -notcontains ('EGRESS_LAB_PHASE=' + $Phase) -or @($c.Config.Env | Where-Object { $_ -match '^(DATABASE_URL|REDIS_URL|ADMIN_SECRET|POSTGRES_PASSWORD|EGRESS_DOMAINS)=' }).Count) { throw 'Refuse lab with data/secret/policy overrides' }
    $bindings = @($c.Mounts | Where-Object { $_.Type -eq 'bind' })
    if ($bindings.Count -ne 2 -or @($c.Mounts | Where-Object { $_.Type -notin @('bind','tmpfs') }).Count) { throw 'Refuse lab data/foreign volumes' }
    foreach ($check in @(@('apps/egress/src/egress.py','/lab/production/egress.py'),@('tests','/lab/tests'))) {
        $expected = (Resolve-Path -LiteralPath $check[0]).Path.Replace('\','/')
        $desktop = '/run/desktop/mnt/host/' + $expected.Substring(0,1).ToLowerInvariant() + '/' + $expected.Substring(3)
        $mount = @($bindings | Where-Object { $_.Destination -eq $check[1] })
        if ($mount.Count -ne 1 -or $mount[0].RW -or @($expected,$desktop) -notcontains $mount[0].Source.Replace('\','/')) { throw 'Refuse lab source mount mismatch' }
    }
    Write-Host ('PASS actual lab ' + (@{project=$labProject; imageId=$c.Image; containerId=$c.Id; network='none'; pidMode='private'; ports=0; dataVolumes=0; rootfsRO=$true; mounts=@($bindings | Select-Object Source,Destination,RW); sha=$labSha; state=$c.State.Status} | ConvertTo-Json -Depth 5 -Compress))
    return $c
}
Write-Output ('Egress lab ' + $Phase + ' / UTC ' + [DateTime]::UtcNow.ToString('o') + ' / Asia/Saigon ' + [DateTimeOffset]::UtcNow.ToOffset([TimeSpan]::FromHours(7)).ToString('o'))
try {
    [Environment]::SetEnvironmentVariable('WED_EGRESS_LAB_SHA',$labSha,'Process')
    [Environment]::SetEnvironmentVariable('WED_EGRESS_LAB_PHASE',$Phase,'Process')
    $raw = & docker @labArgs config --format json
    if ($LASTEXITCODE -ne 0) { throw 'Lab config failed' }
    $cfg = ($raw -join "`n") | ConvertFrom-Json
    $s = $cfg.services.lab
    if ($cfg.name -ne $labProject -or @($cfg.services.PSObject.Properties).Count -ne 1 -or $s.image -ne $labImage -or $s.pull_policy -ne 'never' -or $s.network_mode -ne 'none' -or $s.user -ne '65534:65534' -or -not $s.read_only -or @($s.ports | Where-Object { $_ }).Count -or @($s.depends_on.PSObject.Properties | Where-Object { $_ }).Count -or @($s.volumes | Where-Object { $_.type -ne 'bind' -or -not $_.read_only }).Count -or @($s.volumes).Count -ne 2) { throw 'Unsafe resolved standalone lab' }
    if (@($s.tmpfs).Count -ne 1 -or $s.tmpfs[0] -ne '/tmp:size=4m,noexec,nosuid') { throw 'Unsafe lab tmpfs config' }
    Write-Output 'PASS resolved standalone lab: one service/no dependencies/network none/no ports/no data volumes/source RO/explicit non-secret env-file'
    $imageRaw = & docker image inspect $labImage
    if ($LASTEXITCODE -ne 0) { throw 'Required cached image absent; no pull/build/install allowed' }
    $image = @((($imageRaw -join "`n") | ConvertFrom-Json))[0]
    if ($image.Os -ne 'linux' -or $image.Config.User -ne '65534:65534' -or @($image.Config.Volumes.PSObject.Properties | Where-Object { $_ }).Count) { throw 'Cached image is not suitable for this lab' }
    $labImageId = $image.Id
    Write-Output ('PASS cached image ' + $labImage + ' / ' + $labImageId + ' / ' + $image.Os + '/' + $image.Architecture)
    Invoke-Lab @('create','--no-build','lab')
    $created = $true
    $c = Assert-LabActual
    if ($c.State.Status -ne 'created') { throw 'Lab must be freshly created, not a reused running/stopped container' }
    Invoke-Lab @('start','lab')
    $c = Assert-LabActual
    $deadline = [DateTime]::UtcNow.AddSeconds(90)
    while ($c.State.Running) {
        if ([DateTime]::UtcNow -gt $deadline) { throw 'Lab exceeded finite90s bound' }
        Start-Sleep -Milliseconds 200
        $c = Read-LabContainer
    }
    Invoke-Lab @('logs','--timestamps','--no-color','lab')
    $c = Assert-LabActual
    if ($c.State.ExitCode -ne 0) { throw ('Lab tests FAIL, container exit ' + $c.State.ExitCode) }
    if ((Get-FileHash -LiteralPath 'apps/egress/src/egress.py' -Algorithm SHA256).Hash.ToLowerInvariant() -ne $labSha) { throw 'Production source changed during lab' }
    Write-Output ('PASS lab ' + $Phase + ' / source unchanged ' + $labSha)
} finally {
    try {
        if ($created) {
            $c = Assert-LabActual
            if ($c.State.Running) {
                Write-Output 'CLEANUP after lab FAIL/timeout only; not runtime PASS'
                Invoke-Lab @('logs','--timestamps','--no-color','lab')
                Invoke-Lab @('stop','lab')
            }
            $c = Assert-LabActual
            if ($c.State.Running) { throw 'Refuse removing a running lab container' }
            Invoke-Lab @('rm','-f','lab')
            $left = & docker @labArgs ps -a -q lab
            if ($LASTEXITCODE -ne 0 -or $left) { throw 'Lab container teardown incomplete' }
            Write-Output 'PASS lab container removed; no data volumes mounted or removed'
        }
    } finally {
        [Environment]::SetEnvironmentVariable('WED_EGRESS_LAB_SHA',$savedShaEnv,'Process')
        [Environment]::SetEnvironmentVariable('WED_EGRESS_LAB_PHASE',$savedPhaseEnv,'Process')
    }
}
