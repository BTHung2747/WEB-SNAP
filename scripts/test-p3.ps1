param([ValidateSet('Check','Setup','Start','LimitsStart','AdapterLimits','ByteLimits','SocketFaults','WorkerRestart','Typecheck','R15Reproduce','AdapterTimeout','ConcurrentPrepare','PrepareRegression','ActiveTransfer','LeaseRegression','Release','Crash','Regression','Stop')][string] $Phase = 'Check')
$ErrorActionPreference = 'Stop'
$p3Project = 'wed-snap-p3-test'
$p3Compose = @('compose','-p',$p3Project,'-f','compose.yaml','-f','compose.test.yaml','-f','infra/compose.p3-test.yaml')
function Invoke-P3([string[]] $DockerArgs) {
    Write-Output ('COMMAND docker ' + ($p3Compose + $DockerArgs -join ' '))
    & docker @p3Compose @DockerArgs
    if ($LASTEXITCODE -ne 0) { throw 'P3 Docker command failed; stopped without touching other projects' }
}
function Assert-P3Config {
    $raw = & docker @p3Compose config --format json
    if ($LASTEXITCODE -ne 0) { throw 'P3 compose config failed' }
    $cfg = ($raw -join "`n") | ConvertFrom-Json
    if ($cfg.name -ne $p3Project) { throw 'P3 project mismatch' }
    if ($cfg.services.egress.image -ne 'wed-snap-p3-egress:local') { throw 'P3 egress image mismatch' }
    if ($cfg.services.postgres.environment.POSTGRES_DB -ne 'wed_snap_p3_test') { throw 'P3 DB mismatch' }
    foreach ($svc in @('api','worker')) {
        $service = $cfg.services.$svc
        if ($service.image -ne 'wed-snap-p3-test:local' -or $service.environment.DATABASE_URL -notmatch '/wed_snap_p3_test$' -or $service.environment.REDIS_URL -ne 'redis://redis:6379/14' -or $service.environment.P3_TEST_GUARD -ne $p3Project -or $service.environment.APP_ORIGIN -ne 'http://localhost:5174') { throw 'P3 runtime isolation mismatch' }
    }
    foreach ($check in @(@('postgres','/var/lib/postgresql/data','test_postgres'),@('redis','/data','test_redis'),@('api','/media','test_media'),@('worker','/media','test_media'),@('worker','/control','p3_control'))) {
        $mount = @($cfg.services.($check[0]).volumes | Where-Object { $_.target -eq $check[1] })
        if ($mount.Count -ne 1 -or $mount[0].type -ne 'volume' -or $mount[0].source -ne $check[2]) { throw 'P3 volume isolation mismatch' }
    }
    $fixture = @($cfg.services.worker.volumes | Where-Object { $_.target -eq '/app/infra/media_adapter.py' })
    if ($fixture.Count -ne 1 -or $fixture[0].source.Replace('\','/') -notmatch '/tests/p3_fixture_adapter.py$' -or -not $fixture[0].read_only) { throw 'P3 fixture mount mismatch' }
    $production = @($cfg.services.worker.volumes | Where-Object { $_.target -eq '/app/production' })
    if ($production.Count -ne 1 -or $production[0].type -ne 'bind' -or $production[0].source.Replace('\','/') -notmatch '/apps/media/src$' -or -not $production[0].read_only) { throw 'P3 production source mount mismatch' }
    Write-Output 'PASS resolved P3 config: project/image/DB/Redis/media/control/fixture isolation'
}
function Assert-P3Container([string] $Service, [bool] $IncludeStopped = $false) {
    $psArgs = @('ps'); if ($IncludeStopped) { $psArgs += '-a' }; $psArgs += @('-q',$Service)
    $id = & docker @p3Compose @psArgs
    if ($LASTEXITCODE -ne 0 -or -not $id) { throw 'No running P3 container to inspect' }
    $raw = & docker inspect $id
    if ($LASTEXITCODE -ne 0) { throw 'P3 inspect failed' }
    $container = @((($raw -join "`n") | ConvertFrom-Json))[0]
    if ($container.Config.Labels.'com.docker.compose.project' -ne $p3Project -or $container.Config.Labels.'com.docker.compose.service' -ne $Service -or $container.Config.Image -ne 'wed-snap-p3-test:local') { throw 'Refuse operation on unverified container' }
    if ($container.HostConfig.PidMode -ne '') { throw 'Refuse runtime sharing a foreign/host PID namespace' }
    if ($container.Config.Env -notcontains 'P3_TEST_GUARD=wed-snap-p3-test' -or $container.Config.Env -notcontains 'REDIS_URL=redis://redis:6379/14' -or -not @($container.Config.Env | Where-Object { $_ -match '^DATABASE_URL=.+/wed_snap_p3_test$' }).Count) { throw 'Refuse unverified runtime DB/Redis environment' }
    $media = @($container.Mounts | Where-Object { $_.Destination -eq '/media' })
    if ($media.Count -ne 1 -or $media[0].Name -ne ($p3Project + '_test_media')) { throw 'Refuse non-P3 media volume' }
    foreach ($mount in $container.Mounts) { if ($mount.Type -eq 'volume' -and -not $mount.Name.StartsWith($p3Project + '_')) { throw 'Refuse foreign volume' } }
    if ($Service -eq 'worker') {
        $control = @($container.Mounts | Where-Object { $_.Destination -eq '/control' })
        if ($control.Count -ne 1 -or $control[0].Name -ne ($p3Project + '_p3_control')) { throw 'Refuse non-P3 control volume' }
        $fixture = @($container.Mounts | Where-Object { $_.Destination -eq '/app/infra/media_adapter.py' })
        if ($fixture.Count -ne 1 -or $fixture[0].RW -or $fixture[0].Source.Replace('\','/') -notmatch '/tests/p3_fixture_adapter.py$') { throw 'Refuse unverified actual fixture mount' }
    }
    foreach ($network in $container.NetworkSettings.Networks.PSObject.Properties.Name) { if (-not $network.StartsWith($p3Project + '_')) { throw 'Refuse foreign network' } }
    Write-Output ('PASS actual runtime ' + (@{service=$Service; project=$p3Project; image=$container.Config.Image; imageId=$container.Image; media=$media[0].Name; database='wed_snap_p3_test'; redisDb=14; fixtureReadOnly=($Service -eq 'worker')} | ConvertTo-Json -Compress))
}
function Assert-P3DataContainers([bool] $IncludeStopped = $false) {
    foreach ($service in @('postgres','redis')) {
        $psArgs = @('ps'); if ($IncludeStopped) { $psArgs += '-a' }; $psArgs += @('-q',$service)
        $id = & docker @p3Compose @psArgs
        if ($LASTEXITCODE -ne 0 -or -not $id) { throw 'Test data container not running' }
        $raw = & docker inspect $id
        if ($LASTEXITCODE -ne 0) { throw 'Test data inspect failed' }
        $container = @((($raw -join "`n") | ConvertFrom-Json))[0]
        if ($container.Config.Labels.'com.docker.compose.project' -ne $p3Project -or $container.Config.Labels.'com.docker.compose.service' -ne $service) { throw 'Refuse foreign data container' }
        $expectedVolume = $p3Project + '_test_' + $service
        $volumes = @($container.Mounts | Where-Object { $_.Type -eq 'volume' })
        if ($volumes.Count -ne 1 -or $volumes[0].Name -ne $expectedVolume) { throw 'Refuse foreign data volume' }
        if ($service -eq 'postgres' -and $container.Config.Env -notcontains 'POSTGRES_DB=wed_snap_p3_test') { throw 'Refuse foreign DB' }
        Write-Output ('PASS actual data ' + (@{service=$service; project=$p3Project; image=$container.Config.Image; imageId=$container.Image; volume=$expectedVolume} | ConvertTo-Json -Compress))
    }
}
function Assert-P3ProductionSource {
    $id = & docker @p3Compose ps -q worker
    if ($LASTEXITCODE -ne 0 -or -not $id) { throw 'No running P3 worker' }
    $raw = & docker inspect $id
    if ($LASTEXITCODE -ne 0) { throw 'Production source inspect failed' }
    $container = @((($raw -join "`n") | ConvertFrom-Json))[0]
    $production = @($container.Mounts | Where-Object { $_.Destination -eq '/app/production' })
    $expectedSource = (Resolve-Path -LiteralPath 'apps/media/src').Path.Replace('\','/')
    $desktopSource = '/run/desktop/mnt/host/' + $expectedSource.Substring(0,1).ToLowerInvariant() + '/' + $expectedSource.Substring(3)
    Write-Output ('P3 production source guard ' + (@{expected=$expectedSource; actual=@($production | Select-Object Type,Source,Destination,RW)} | ConvertTo-Json -Compress))
    if ($production.Count -ne 1 -or $production[0].Type -ne 'bind' -or $production[0].RW -or @($expectedSource,$desktopSource) -notcontains $production[0].Source.Replace('\','/')) { throw 'Actual production source bind mismatch; run LimitsStart only' }
    $expectedHash = (Get-FileHash -LiteralPath 'apps/media/src/media_adapter.py' -Algorithm SHA256).Hash.ToLowerInvariant()
    $actualHash = & docker @p3Compose exec -T worker sha256sum /app/production/media_adapter.py
    if ($LASTEXITCODE -ne 0 -or ($actualHash -split '\s+')[0] -ne $expectedHash) { throw 'Production Python source checksum mismatch' }
    Write-Output ('PASS production Python SHA256 ' + $expectedHash)
    Write-Output 'PASS actual P3 production source: apps/media/src mounted read-only, fixture remains separate'
}
function Run-P3Test([string[]] $TestArgs) { Invoke-P3 (@('exec','-T','worker','node_modules/.bin/tsx') + $TestArgs) }
function Assert-P3Socket([bool] $Actual = $false) {
    $raw = & docker @p3Compose config --format json
    if ($LASTEXITCODE -ne 0) { throw 'Socket config failed' }
    $cfg = ($raw -join "`n") | ConvertFrom-Json
    $s = $cfg.services.'socket-test'
    if ($s.image -ne 'wed-snap-p3-test:local' -or $s.environment.P3_TEST_GUARD -ne $p3Project -or @($s.ports | Where-Object { $_ }).Count -gt 0 -or @($s.networks.PSObject.Properties.Name).Count -ne 1 -or -not $cfg.networks.private.internal -or -not $s.read_only) { throw 'Refuse unsafe resolved socket server' }
    if (@($s.volumes | Where-Object { $_.target -eq '/control' -and $_.type -eq 'volume' -and $_.source -eq 'p3_control' }).Count -ne 1 -or @($s.volumes | Where-Object { $_.target -eq '/app/tests' -and $_.type -eq 'bind' -and $_.read_only }).Count -ne 1) { throw 'Socket mount config mismatch' }
    if (-not $Actual) { Write-Output 'PASS resolved socket server: test image/control, internal network only, no ports, source RO'; return }
    $id = & docker @p3Compose ps -a -q socket-test
    if ($LASTEXITCODE -ne 0 -or -not $id) { throw 'Missing socket test container' }
    $raw = & docker inspect $id
    if ($LASTEXITCODE -ne 0) { throw 'Socket inspect failed' }
    $c = @((($raw -join "`n") | ConvertFrom-Json))[0]
    $workerId = & docker @p3Compose ps -a -q worker
    $wRaw = & docker inspect $workerId
    if ($LASTEXITCODE -ne 0) { throw 'Worker image inspect failed' }
    $w = @((($wRaw -join "`n") | ConvertFrom-Json))[0]
    $expectedSource = (Resolve-Path -LiteralPath 'tests').Path.Replace('\','/')
    $desktopSource = '/run/desktop/mnt/host/' + $expectedSource.Substring(0,1).ToLowerInvariant() + '/' + $expectedSource.Substring(3)
    $source = @($c.Mounts | Where-Object { $_.Destination -eq '/app/tests' })
    $control = @($c.Mounts | Where-Object { $_.Destination -eq '/control' })
    if ($c.Config.Labels.'com.docker.compose.project' -ne $p3Project -or $c.Config.Labels.'com.docker.compose.service' -ne 'socket-test' -or $c.Image -ne $w.Image -or $c.Config.Image -ne 'wed-snap-p3-test:local' -or $c.Config.Env -notcontains 'P3_TEST_GUARD=wed-snap-p3-test' -or -not $c.HostConfig.ReadonlyRootfs -or @($c.HostConfig.PortBindings.PSObject.Properties).Count -gt 0 -or $c.HostConfig.PidMode -ne '' -or ($c.Config.Cmd -join ' ') -ne 'python3 /app/tests/p3_socket_server.py') { throw 'Refuse unsafe actual socket server' }
    if ($control.Count -ne 1 -or $control[0].Name -ne ($p3Project + '_p3_control') -or $source.Count -ne 1 -or $source[0].RW -or @($expectedSource,$desktopSource) -notcontains $source[0].Source.Replace('\','/')) { throw 'Actual socket mounts mismatch' }
    $nets = @($c.NetworkSettings.Networks.PSObject.Properties.Name)
    if ($nets.Count -ne 1 -or $nets[0] -ne ($p3Project + '_private')) { throw 'Refuse socket server outside private test network' }
    $networkRaw = & docker network inspect $nets[0]
    if ($LASTEXITCODE -ne 0 -or -not @((($networkRaw -join "`n") | ConvertFrom-Json))[0].Internal) { throw 'Socket network is not internal' }
    Write-Output ('PASS actual socket guard ' + (@{project=$p3Project; imageId=$c.Image; control=$control[0].Name; sourceRO=$source[0].Source; network=$nets[0]; ports=0; pidMode='private'} | ConvertTo-Json -Compress))
}
function Assert-P3Killed([string] $Service) {
    $id = & docker @p3Compose ps -a -q $Service
    $raw = & docker inspect $id
    if ($LASTEXITCODE -ne 0) { throw 'Cannot verify killed container' }
    $container = @((($raw -join "`n") | ConvertFrom-Json))[0]
    if ($container.Config.Labels.'com.docker.compose.project' -ne $p3Project -or $container.Config.Labels.'com.docker.compose.service' -ne $Service -or $container.State.Running -or $container.State.ExitCode -ne 137) { throw 'SIGKILL exit state not verified' }
    Write-Output ('PASS test SIGKILL confirmed exit 137: ' + $Service)
}

Write-Output ('P3 phase ' + $Phase + ' / UTC ' + [DateTime]::UtcNow.ToString('o'))
Write-Output ('Environment Windows PowerShell / Asia/Saigon ' + [DateTimeOffset]::UtcNow.ToOffset([TimeSpan]::FromHours(7)).ToString('o'))
Assert-P3Config  # Before build/start/migrate/chown/write/kill, without printing secrets.
switch ($Phase) {
    'SocketFaults' {
        Assert-P3Container 'worker'; Assert-P3Container 'api'; Assert-P3DataContainers; Assert-P3ProductionSource; Assert-P3Socket
        Invoke-P3 @('exec','-T','worker','node_modules/.bin/tsx','tests/p3-runtime-check.ts','--idle')
        # Create (no process started), inspect actual identity before server writes/start.
        Invoke-P3 @('create','--no-build','socket-test')
        Assert-P3Socket $true
        try {
            Invoke-P3 @('start','socket-test')
            Assert-P3Socket $true
            Run-P3Test @('tests/p3-socket-faults.integration.ts')
        } finally {
            Assert-P3Socket $true
            Invoke-P3 @('logs','--timestamps','--since','5m','--no-color','socket-test','worker')
            Invoke-P3 @('stop','socket-test')
        }
    }
    'Check' { }
    'Start' {
        # Reuse the existing dedicated P3 image and volumes, no build or reset.
        Invoke-P3 @('up','-d','--no-build','--no-recreate','api','worker')
        Assert-P3Container 'worker'; Assert-P3Container 'api'
        Assert-P3DataContainers
        Invoke-P3 @('run','--rm','--no-deps','worker','node_modules/.bin/tsx','tests/p3-runtime-check.ts')
    }
    'Typecheck' {
        Assert-P3Container 'worker'; Assert-P3Container 'api'
        # The enlarged test graph exceeds 256MiB heap. Only this one-off checker
        # gets 384MiB within worker's existing 768MiB container limit.
        Invoke-P3 @('run','--rm','--no-deps','-e','NODE_OPTIONS=--max-old-space-size=384','worker','node_modules/.bin/tsc','-p','tsconfig.tests.json')
    }
    'LimitsStart' {
        # Inspect existing dedicated containers/volumes BEFORE starting them.
        Assert-P3Container 'worker' $true; Assert-P3Container 'api' $true; Assert-P3DataContainers $true
        Invoke-P3 @('up','-d','--no-build','--no-recreate','egress','api')
        Invoke-P3 @('run','--rm','--no-deps','worker','node_modules/.bin/tsx','tests/p3-runtime-check.ts','--idle')
        # Only test worker needs recreation to add production Python's RO bind.
        $workerId = & docker @p3Compose ps -a -q worker
        $rawWorker = & docker inspect $workerId
        if ($LASTEXITCODE -ne 0) { throw 'Cannot inspect existing P3 worker source mounts' }
        $existing = @((($rawWorker -join "`n") | ConvertFrom-Json))[0]
        if (@($existing.Mounts | Where-Object { $_.Destination -eq '/app/production' }).Count -eq 1) {
            Invoke-P3 @('up','-d','--no-build','--no-deps','--no-recreate','worker')
        } else {
            Invoke-P3 @('up','-d','--no-build','--no-deps','--force-recreate','worker')
        }
        Assert-P3Container 'worker'; Assert-P3Container 'api'; Assert-P3DataContainers; Assert-P3ProductionSource
        Invoke-P3 @('run','--rm','--no-deps','worker','node_modules/.bin/tsx','tests/p3-runtime-check.ts')
    }
    'AdapterLimits' {
        Assert-P3Container 'worker'; Assert-P3Container 'api'; Assert-P3DataContainers; Assert-P3ProductionSource
        Invoke-P3 @('run','--rm','--no-deps','worker','python3','tests/p2_adapter_limits.py')
    }
    'ByteLimits' {
        Assert-P3Container 'worker'; Assert-P3Container 'api'; Assert-P3DataContainers; Assert-P3ProductionSource
        Run-P3Test @('tests/p2-byte-limits.integration.ts')
    }
    'ActiveTransfer' {
        Assert-P3Container 'worker'; Assert-P3Container 'api'
        Invoke-P3 @('run','--rm','--no-deps','worker','node_modules/.bin/tsx','tests/p3-active-transfer.integration.ts')
    }
    'ConcurrentPrepare' {
        Assert-P3Container 'worker'; Assert-P3Container 'api'
        Assert-P3DataContainers
        Invoke-P3 @('run','--rm','--no-deps','worker','node_modules/.bin/tsx','tests/p3-concurrent-prepare.integration.ts')
    }
    'AdapterTimeout' {
        Assert-P3Container 'worker'; Assert-P3Container 'api'
        Assert-P3DataContainers
        # Same PID namespace is required to observe adapter/group identity.
        $suiteSince = [DateTime]::UtcNow.ToString('o')
        Run-P3Test @('tests/p3-adapter-timeout.integration.ts')
        $runtimeLines = & docker @p3Compose logs --no-color --since $suiteSince worker
        if ($LASTEXITCODE -ne 0) { throw 'Could not verify actual worker registry logs' }
        $records = @($runtimeLines | ForEach-Object { if ($_ -match '(\{"event":"adapter_(parent_closed|group_stopped)".*\})') { $Matches[1] | ConvertFrom-Json } })
        $protectedParent = @($records | Where-Object { $_.event -eq 'adapter_parent_closed' -and $_.groupLive -gt 0 -and $_.registryProtected })
        if ($protectedParent.Count -ne 1) { throw 'Missing actual registry protection at DEVNULL parent close' }
        $groupEnd = @($records | Where-Object { $_.event -eq 'adapter_group_stopped' -and $_.id -eq $protectedParent[0].id -and $_.phase -eq $protectedParent[0].phase -and $_.groupLive -eq 0 -and -not $_.registryProtected })
        if ($groupEnd.Count -ne 1) { throw 'Registry not released after actual group stop' }
        Write-Output ('PASS actual worker registry retained at parent-close and released at group-stop: ' + $protectedParent[0].id)
        $records | ForEach-Object { $_ | ConvertTo-Json -Compress }
    }
    'WorkerRestart' {
        Assert-P3Container 'worker'; Assert-P3Container 'api'; Assert-P3DataContainers
        Invoke-P3 @('restart','worker')
        Assert-P3Container 'worker'
    }
    'R15Reproduce' {
        Assert-P3Container 'worker'; Assert-P3Container 'api'
        Assert-P3DataContainers
        Run-P3Test @('tests/p3-adapter-timeout.integration.ts','--r15-only')
    }
    'PrepareRegression' {
        Assert-P3Container 'worker'; Assert-P3Container 'api'
        Assert-P3DataContainers
        Invoke-P3 @('run','--rm','--no-deps','worker','node_modules/.bin/tsx','tests/p3-range.integration.ts')
    }
    'LeaseRegression' {
        Assert-P3Container 'worker'; Assert-P3Container 'api'
        Invoke-P3 @('run','--rm','--no-deps','worker','node_modules/.bin/tsx','tests/p3-range.integration.ts')
        Invoke-P3 @('stop','worker')
        try {
            Invoke-P3 @('run','--rm','--no-deps','worker','node_modules/.bin/tsx','tests/p3-run-regression.ts','lifecycle')
            Invoke-P3 @('run','--rm','--no-deps','worker','node_modules/.bin/tsx','tests/p3-run-regression.ts','deadline')
        } finally { Invoke-P3 @('up','-d','--no-build','--no-recreate','worker') }
        Assert-P3Container 'worker'
    }
    'Setup' {
        Invoke-P3 @('build','api')
        Invoke-P3 @('build','egress')
        Invoke-P3 @('up','-d','postgres','redis')
        Invoke-P3 @('run','--rm','--no-deps','api','npm','run','migrate')
        Invoke-P3 @('run','--rm','--no-deps','--user','0','--cap-add','CHOWN','worker','node_modules/.bin/tsx','tests/p3-control-init.ts')
        Invoke-P3 @('up','-d','--no-build','api','worker')
        Assert-P3Container 'worker'; Assert-P3Container 'api'
        Invoke-P3 @('run','--rm','--no-deps','-e','NODE_OPTIONS=--max-old-space-size=384','worker','node_modules/.bin/tsc','-p','tsconfig.tests.json')
    }
    'Release' {
        Assert-P3Container 'worker'; Assert-P3Container 'api'
        Run-P3Test @('tests/p3-release.integration.ts')
    }
    'Crash' {
        Assert-P3Container 'worker'; Assert-P3Container 'api'
        Run-P3Test @('tests/p3-crash.integration.ts','start')
        Run-P3Test @('tests/p3-crash.integration.ts','pre-kill')
        Assert-P3Container 'worker'
        Invoke-P3 @('kill','-s','SIGKILL','worker')
        Assert-P3Killed 'worker'
        Invoke-P3 @('run','--rm','--no-deps','worker','node_modules/.bin/tsx','tests/p3-crash.integration.ts','killed')
        Invoke-P3 @('up','-d','--no-build','worker')
        Assert-P3Container 'worker'
        Run-P3Test @('tests/p3-crash.integration.ts','check')
    }
    'Regression' {
        Assert-P3Container 'worker'; Assert-P3Container 'api'
        # FFmpeg and a Prisma test runner together hit the worker's 80 PID limit.
        # Range needs no PID namespace observation; keep its runner separate.
        Invoke-P3 @('run','--rm','--no-deps','worker','node_modules/.bin/tsx','tests/p3-range.integration.ts')
        # Stop background sweeper for local liveProcesses tests, then run one by one.
        Invoke-P3 @('stop','worker')
        Invoke-P3 @('run','--rm','--no-deps','worker','node_modules/.bin/tsx','tests/p3-run-regression.ts','lifecycle')
        Invoke-P3 @('run','--rm','--no-deps','worker','node_modules/.bin/tsx','tests/p3-run-regression.ts','deadline')
        Invoke-P3 @('up','-d','--no-build','worker')
        Assert-P3Container 'worker'
        Run-P3Test @('tests/p3-run-regression.ts','crash','api-start')
        $holdName = 'wed-snap-p3-test-crash-client'
        Invoke-P3 @('run','-d','--name',$holdName,'--no-deps','worker','node_modules/.bin/tsx','tests/p3-run-regression.ts','crash','api-hold')
        try {
            $held = $false
            for ($i=0; $i -lt 20; $i++) {
                $logs = & docker logs $holdName 2>&1
                if ($logs -match 'TRANSFER_HELD') { $held = $true; break }
                Start-Sleep -Milliseconds 500
            }
            if (-not $held) { throw 'No active transfer; refuse API kill' }
            Run-P3Test @('tests/p3-api-transfer-check.ts')
            Assert-P3Container 'api'
            Invoke-P3 @('kill','-s','SIGKILL','api')
            Assert-P3Killed 'api'
            Invoke-P3 @('up','-d','--no-build','api')
            Run-P3Test @('tests/p3-run-regression.ts','crash','api-check')
        } finally {
            $heldContainer = & docker inspect $holdName 2>$null
            if ($LASTEXITCODE -eq 0) {
                $info = @((($heldContainer -join "`n") | ConvertFrom-Json))[0]
                if ($info.Config.Labels.'com.docker.compose.project' -eq $p3Project -and $info.Config.Image -eq 'wed-snap-p3-test:local') { & docker rm -f $holdName | Out-Null }
            }
        }
    }
    'Stop' {
        Assert-P3Container 'worker' $true; Assert-P3Container 'api' $true; Assert-P3DataContainers $true
        $socketId = & docker @p3Compose ps -a -q socket-test
        if ($socketId) { Assert-P3Socket $true }
        Invoke-P3 @('stop')
    }
}
Write-Output ('PASS P3 phase ' + $Phase + ' / UTC ' + [DateTime]::UtcNow.ToString('o'))
