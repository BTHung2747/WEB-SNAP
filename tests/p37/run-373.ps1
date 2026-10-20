# P37.3 runner. Actual guards run before containers are started.
# Stages:  offline  -> offline fixtures + capability check (--network none, no Internet)
#          ab       -> 2 attempts (A base / B supplemental image + actual supported target)
# Usage: run-373.ps1 -Stage offline; AB also requires -ImageTag/-ImageId/-Target.
param(
    [Parameter(Mandatory = $true)][ValidateSet('offline', 'ab')][string]$Stage,
    [string]$Target = '',
    [string]$EvidenceDir = '',
    [switch]$InstrumentationOnly,
    [string]$ImageTag = 'wed-snap-media:2026.08.19',
    [string]$ImageId = 'sha256:ecb3e7477d301d766046b92c586604a5650e22a0bac8e675b45699784f65737b'
)
Set-StrictMode -Version 2
$ErrorActionPreference = 'Stop'
$ROOT = 'D:\WED SNAP'
Set-Location $ROOT
$RUN_ID = [Guid]::NewGuid().ToString('N')
$RUN_LABEL = "com.wed-snap.run=$RUN_ID"
if (-not $EvidenceDir) { $EvidenceDir = "docs\evidence\p37-3-$RUN_ID" }
$outputPath = [IO.Path]::GetFullPath((Join-Path $ROOT $EvidenceDir))
$evidenceRoot = [IO.Path]::GetFullPath("$ROOT\docs\evidence\")
if (-not $outputPath.StartsWith($evidenceRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'Output must be inside docs/evidence' }
if (Test-Path -LiteralPath $outputPath) { throw 'Refuse to reuse an evidence directory' }
$EV = $outputPath.Substring($ROOT.Length + 1)
New-Item -ItemType Directory -Path $outputPath | Out-Null
$LOG = Join-Path (Join-Path $ROOT $EV) "runner-$Stage.jsonl"
$LABEL = 'com.wed-snap.lab=tiktok-373'
$PIN = @{
    'wed-snap-egress:local' = 'sha256:8bc0a567955111ea3cfbab2dd3b14f40a602f2d10ac987e78eb465f9d48d7f10';
    'wed-snap-media:2026.08.19' = 'sha256:ecb3e7477d301d766046b92c586604a5650e22a0bac8e675b45699784f65737b'
}
$PIN[$ImageTag] = $ImageId
$VN = [TimeZoneInfo]::FindSystemTimeZoneById('SE Asia Standard Time')
function Stamp { $u = [DateTime]::UtcNow; '{0:o}|VN {1:yyyy-MM-dd HH:mm:ss.fff}' -f $u, [TimeZoneInfo]::ConvertTimeFromUtc($u, $VN) }

function Clean([string]$t) {
    if (-not $t) { return '' }
    $t = [regex]::Replace($t, '(?i)https?://[^\s''"<>]+', {
        param($m)
        $url = ($m.Value -split '[?#]')[0]
        $url = [regex]::Replace($url, '^(https?://)[^/]*@', '$1', 'IgnoreCase')
        $url + $(if ($m.Value -match '[?#]') { '[q-redacted]' } else { '' })
    })
    $t = [regex]::Replace($t, '(?i)\b(mstoken|x-bogus|_signature|signature|token|cookie|sessionid|auth|key|sign|password|secret|bearer)=[^\s&''"]+', '$1=[redacted]')
    $t = [regex]::Replace($t, '(?im)\b(authorization|proxy-authorization|cookie|set-cookie)\s*:[^\r\n]*', '$1: [redacted]')
    return $t
}

# Runs `docker <args>` in a job: bounded by a timeout, exit code checked, sanitized log record written.
function Native([string]$name, [string[]]$dargs, [switch]$AllowFail, [int]$TimeoutSec = 120) {
    $s = Stamp
    $job = Start-Job -ScriptBlock { param($a) $o = & docker @a 2>&1 | Out-String; [pscustomobject]@{ out = $o; code = $LASTEXITCODE } } -ArgumentList (, $dargs)
    if (-not (Wait-Job $job -Timeout $TimeoutSec)) {
        Stop-Job $job; Remove-Job $job -Force
        Add-Content $LOG ((@{ step = $name; start = $s; end = (Stamp); exit = 'TIMEOUT'; timeoutSec = $TimeoutSec } | ConvertTo-Json -Compress)) -Encoding utf8
        throw "TIMEOUT in step $name"
    }
    $r = Receive-Job $job; Remove-Job $job -Force
    $code = [int]$r.code
    $out = Clean ([string]$r.out)
    if ($out.Length -gt 8000) { $out = $out.Substring(0, 8000) + '...[truncated]' }
    Add-Content $LOG ((@{ step = $name; start = $s; end = (Stamp); exit = $code; output = $out.Trim() } | ConvertTo-Json -Compress)) -Encoding utf8
    Write-Host "[$name] exit=$code"
    if ($code -ne 0 -and -not $AllowFail) { throw "FAIL step $name exit=$code" }
    return [pscustomobject]@{ out = [string]$r.out; code = $code }
}

function Check($cond, [string]$msg) { if (-not $cond) { throw "GUARD FAIL: $msg" } }
function Inspect1([string]$name) { $j = (Native "inspect-$name" @('inspect', $name)).out | ConvertFrom-Json; return @($j)[0] }
function Norm([string]$p) { return ($p -replace '/', '\').TrimEnd('\').ToLowerInvariant() }

# Full actual guard for one container.
function Guard($name, [string]$image, $user, [long]$mem, [string]$netmode, [string[]]$nets, [string[]]$mounts, [string[]]$allowedEnv = @(), [string[]]$expectedCmd = @(), [string[]]$expectedEntrypoint = @()) {
    $c = Inspect1 $name
    Check ($c.Image -eq $PIN[$image]) "$name image ID $($c.Image) != pinned $($PIN[$image])"
    Check ($c.Config.Labels.'com.wed-snap.run' -eq $RUN_ID) "$name run ownership"
    Check ($c.Config.User -eq $user) "$name user $($c.Config.User) != expected $user"
    Check ($c.HostConfig.ReadonlyRootfs -eq $true) "$name rootfs not read-only"
    Check (-not $c.HostConfig.Privileged) "$name privileged"
    Check (@($c.HostConfig.CapDrop) -contains 'ALL' -and -not $c.HostConfig.CapAdd) "$name caps invalid"
    Check (@($c.HostConfig.SecurityOpt) -contains 'no-new-privileges:true') "$name missing no-new-privileges"
    Check ([long]$c.HostConfig.Memory -eq $mem -and [long]$c.HostConfig.MemorySwap -eq $mem) "$name memory $($c.HostConfig.Memory)"
    $cpu = if ($netmode -eq 'none') { 500000000 } elseif ($user -eq '65534:65534') { 250000000 } else { 750000000 }
    Check ($c.HostConfig.NanoCpus -eq $cpu) "$name CPU limit"
    Check ([long]$c.HostConfig.PidsLimit -eq 64) "$name pids $($c.HostConfig.PidsLimit) != 64"
    Check (-not $c.HostConfig.PidMode -or $c.HostConfig.PidMode -eq 'private') "$name pid mode $($c.HostConfig.PidMode) is not private"
    Check (@($c.HostConfig.PortBindings.PSObject.Properties).Count -eq 0) "$name has published ports"
    Check ($c.HostConfig.NetworkMode -eq $netmode) "$name network mode $($c.HostConfig.NetworkMode) != expected $netmode"
    $have = @($c.NetworkSettings.Networks.PSObject.Properties.Name | Sort-Object) -join ','
    Check ($have -eq (($nets | Sort-Object) -join ',')) "$name networks '$have' != '$($nets -join ',')'"
    Check ($c.Config.Labels.'com.wed-snap.lab' -eq 'tiktok-373') "$name ownership label missing"
    
    # Check mounts
    $hm = @($c.Mounts | ForEach-Object { '{0}|{1}|{2}' -f (Norm $_.Source), $_.Destination, $_.RW } | Sort-Object) -join ';'
    $wm = @($mounts | ForEach-Object { $p = $_ -split '\|'; '{0}|{1}|{2}' -f (Norm $p[0]), $p[1], $p[2] } | Sort-Object) -join ';'
    Check ($hm -eq $wm) "$name mounts '$hm' != '$wm'"

    # Allowed Env check
    if ($allowedEnv.Count -gt 0) {
        $actualEnvNames = @($c.Config.Env | ForEach-Object { ($_ -split '=')[0] })
        foreach ($envKey in $actualEnvNames) {
            Check ($allowedEnv -contains $envKey) "$name env '$envKey' not in allowed whitelist"
        }
    }

    # Expected Cmd check
    if ($expectedCmd.Count -gt 0) {
        $actualCmd = @($c.Config.Cmd) -join ' '
        $expectedCmdStr = $expectedCmd -join ' '
        Check ($actualCmd -eq $expectedCmdStr) "$name Cmd '$actualCmd' != '$expectedCmdStr'"
    }

    # Expected Entrypoint check
    if ($expectedEntrypoint.Count -gt 0) {
        $actualEntrypoint = @($c.Config.Entrypoint) -join ' '
        $expectedEntrypointStr = $expectedEntrypoint -join ' '
        Check ($actualEntrypoint -eq $expectedEntrypointStr) "$name Entrypoint '$actualEntrypoint' != '$expectedEntrypointStr'"
    }

    $actualPath = Join-Path $outputPath ("guard-" + $name + '-' + [Guid]::NewGuid().ToString('N') + '.json')
    Clean ($c | ConvertTo-Json -Depth 40) | Set-Content $actualPath -Encoding utf8
    return $c
}

# Resource enumeration functions: FAIL-CLOSED. Never swallow errors with -AllowFail!
function Own-Containers {
    $res = Native 'own-containers' @('ps', '-a', '--filter', "label=$LABEL", '--format', '{{.ID}}|{{.Names}}')
    if ($res.code -ne 0) { throw "FAIL-CLOSED: own-containers enumeration failed with exit $($res.code)" }
    $res.out -split "`r?`n" | Where-Object { $_ }
}

function Own-Networks {
    $res = Native 'own-networks' @('network', 'ls', '--filter', "label=$LABEL", '--format', '{{.ID}}|{{.Name}}')
    if ($res.code -ne 0) { throw "FAIL-CLOSED: own-networks enumeration failed with exit $($res.code)" }
    $res.out -split "`r?`n" | Where-Object { $_ }
}

# Per-run labels allow recovery even when compose up creates only some resources.
function Track-RunResources {
    $cids = (Native 'run-containers' @('ps', '-a', '--no-trunc', '--filter', "label=$LABEL", '--filter', "label=$RUN_LABEL", '--format', '{{.ID}}')).out -split "`r?`n"
    foreach ($id in $cids) {
        if ($id -and -not $global:createdContainerIds.Contains($id)) { $global:createdContainerIds.Add($id) }
    }
    $nids = (Native 'run-networks' @('network', 'ls', '--no-trunc', '--filter', "label=$LABEL", '--filter', "label=$RUN_LABEL", '--format', '{{.ID}}')).out -split "`r?`n"
    foreach ($id in $nids) {
        if ($id -and -not $global:createdNetworkIds.Contains($id)) { $global:createdNetworkIds.Add($id) }
    }
}
function Create-ComposeResources([string[]]$dc) {
    try { Native 'compose-create' ($dc + @('up', '--no-start', '--pull', 'never')) | Out-Null }
    finally { Track-RunResources }
}

# Tracking exact own-created IDs in this specific execution run
$global:createdContainerIds = [System.Collections.Generic.List[string]]::new()
$global:createdNetworkIds = [System.Collections.Generic.List[string]]::new()
$global:preflightFailedPreExisting = $false

function Cleanup {
    if ($global:preflightFailedPreExisting) {
        Write-Host "[cleanup] Skipped cleanup because preflight found pre-existing resources. Preserving external state."
        Add-Content $LOG ((@{ step = 'cleanup-skipped'; reason = 'preflight-preserved-preexisting'; end = (Stamp) } | ConvertTo-Json -Compress)) -Encoding utf8
        return 0
    }
    $cleanedContainers = 0
    foreach ($cid in @($global:createdContainerIds)) {
        if ($cid) {
            # Identity guard before deletion: verify ID and ownership label
            $inspIdRes = Native "inspect-before-rm-id-$cid" @('inspect', $cid, '--format', '{{.Id}}') -AllowFail
            $inspLblRes = Native "inspect-before-rm-lbl-$cid" @('inspect', $cid, '--format', '{{json .Config.Labels}}') -AllowFail
            if ($inspIdRes.code -eq 0 -and $inspLblRes.code -eq 0) {
                $actualId = $inspIdRes.out.Trim()
                $lblObj = try { $inspLblRes.out.Trim() | ConvertFrom-Json } catch { $null }
                $actualLabel = if ($null -ne $lblObj) { $lblObj.'com.wed-snap.lab' } else { '' }
                if ($actualId.StartsWith($cid) -and $actualLabel -eq 'tiktok-373' -and $lblObj.'com.wed-snap.run' -eq $RUN_ID) {
                    Native "rm-$cid" @('rm', '-f', $cid) | Out-Null
                    $cleanedContainers++
                } else {
                    Write-Host "[cleanup] Identity mismatch on container $($cid) - actualId=$actualId label=$actualLabel. Skipped!"
                }
            }
        }
    }
    $cleanedNetworks = 0
    foreach ($nid in @($global:createdNetworkIds)) {
        if ($nid) {
            $inspIdRes = Native "inspect-before-rm-netid-$nid" @('network', 'inspect', $nid, '--format', '{{.Id}}') -AllowFail
            $inspLblRes = Native "inspect-before-rm-netlbl-$nid" @('network', 'inspect', $nid, '--format', '{{json .Labels}}') -AllowFail
            if ($inspIdRes.code -eq 0 -and $inspLblRes.code -eq 0) {
                $actualId = $inspIdRes.out.Trim()
                $lblObj = try { $inspLblRes.out.Trim() | ConvertFrom-Json } catch { $null }
                $actualLabel = if ($null -ne $lblObj) { $lblObj.'com.wed-snap.lab' } else { '' }
                if ($actualId.StartsWith($nid) -and $actualLabel -eq 'tiktok-373' -and $lblObj.'com.wed-snap.run' -eq $RUN_ID) {
                    Native "netrm-$nid" @('network', 'rm', $nid) | Out-Null
                    $cleanedNetworks++
                }
            }
        }
    }
    $left = @(Own-Containers).Count + @(Own-Networks).Count
    Add-Content $LOG ((@{ step = 'cleanup-verified'; end = (Stamp); ownCreatedCleaned = $cleanedContainers; ownResourcesLeft = $left } | ConvertTo-Json -Compress)) -Encoding utf8
    Write-Host "[cleanup] own resources left=$left"
    return $left
}

$origAbTarget = if (Test-Path env:AB_TARGET) { $env:AB_TARGET } else { $null }
$origLabEnv = @{}
foreach ($key in @('LAB373_RUN_ID', 'LAB373_OUTPUT_DIR', 'LAB373_IMAGE', 'AB_ARM')) { $origLabEnv[$key] = [Environment]::GetEnvironmentVariable($key, 'Process') }
$exitCode = 0
$allowedEnvBase = @('PATH', 'NODE_VERSION', 'YARN_VERSION', 'HOME', 'PYTHONDONTWRITEBYTECODE', 'PYTHONUNBUFFERED', 'MEDIA_CACHE_DIR', 'MEDIA_PROXY', 'AB_ARM', 'AB_TARGET', 'LANG', 'LC_ALL')

try {
    Add-Content $LOG ((@{ step = 'begin'; stage = $Stage; start = (Stamp); target = $Target; ps = $PSVersionTable.PSVersion.ToString() } | ConvertTo-Json -Compress)) -Encoding utf8
    
    # Preflight enumeration check: fail-closed and pre-existing resource guard
    $preContainers = @(Own-Containers)
    $preNetworks = @(Own-Networks)
    if ($preContainers.Count -gt 0 -or $preNetworks.Count -gt 0) {
        $global:preflightFailedPreExisting = $true
        throw "PREFLIGHT FAIL: own resources already exist before run (containers: $($preContainers.Count), networks: $($preNetworks.Count)). Halting and preserving resources."
    }

    foreach ($img in $PIN.Keys) {
        $id = ((Native "image-$img" @('image', 'inspect', $img, '--format', '{{.Id}}')).out).Trim()
        Check ($id -eq $PIN[$img]) "image $img id $id != pin $($PIN[$img])"
    }

    $ro = @("$ROOT\tests\p37|/p37|False", "$ROOT\$EV|/out|True")

    if ($Stage -eq 'offline') {
        function Run-Offline([string]$name, [string[]]$cmd, [string]$mem, [long]$memBytes) {
            $a = @('create', '--name', $name, '--label', $LABEL, '--label', $RUN_LABEL, '--network', 'none', '--read-only', '--user', '1000:1000', '--cap-drop', 'ALL', '--security-opt', 'no-new-privileges:true',
                '--memory', $mem, '--memory-swap', $mem, '--pids-limit', '64', '--cpus', '0.5', '--tmpfs', '/tmp:size=64m,noexec,nosuid', '-v', "$ROOT\tests\p37:/p37:ro", '-v', "$ROOT\$EV`:/out",
                '-e', 'HOME=/tmp', '-e', 'PYTHONDONTWRITEBYTECODE=1', '--pull', 'never', $ImageTag) + $cmd
            try { $cr = Native "create-$name" $a }
            finally { Track-RunResources }
            $cid = $cr.out.Trim()
            if ($cid -match '^[0-9a-fA-F]{12,64}$') {
                if (-not $global:createdContainerIds.Contains($cid)) { $global:createdContainerIds.Add($cid) }
            } else {
                $inspId = ((Native "get-id-$name" @('inspect', $name, '--format', '{{.Id}}')).out).Trim()
                $global:createdContainerIds.Add($inspId)
            }
            Guard $name $ImageTag '1000:1000' $memBytes 'none' @('none') $ro $allowedEnvBase $cmd @('/usr/bin/tini', '-g', '--') | Out-Null
            return (Native "run-$name" @('start', '-a', $name) -TimeoutSec 120 -AllowFail)
        }

        $fixtureCmd = @('python3', '-c', "import subprocess,sys; sys.exit(max(subprocess.call([sys.executable,'/p37/'+f]) for f in ['test_372_offline.py','review_helpers.py','test_373_offline.py']))")
        if ($InstrumentationOnly) { $fixtureCmd = @('python3','/p37/test_373_offline.py') }
        # Guard self-test: a wrong expectation MUST throw (fail-closed proof)
        $st = Run-Offline 'wed-snap-tiktok-373-fixture' $fixtureCmd '256m' 268435456
        $threw = $false
        try { Guard 'wed-snap-tiktok-373-fixture' $ImageTag '0:0' 268435456 'none' @('none') $ro $allowedEnvBase $fixtureCmd @('/usr/bin/tini', '-g', '--') | Out-Null } catch { $threw = $true }
        Add-Content $LOG ((@{ step = 'guard-selftest-wrong-user'; threw = $threw } | ConvertTo-Json -Compress)) -Encoding utf8
        Check $threw 'guard did not fail on wrong expectation'
        Check ($st.code -eq 0) "offline fixtures exit=$($st.code)"
        
        $cap = Run-Offline 'wed-snap-tiktok-373-cap' @('python3', '/p37/cap_373.py') '256m' 268435456
        Check ($cap.code -eq 0) "capability check exit=$($cap.code)"
    }
    else {
        Check ($Target -match '^[A-Za-z0-9._:-]{1,40}$') 'bad -Target'
        Check ($ImageTag -ne 'wed-snap-media:2026.08.19' -and $ImageId -ne $PIN['wed-snap-media:2026.08.19']) 'AB requires supplemental image'
        $cf = "$ROOT\infra\compose.tiktok-lab-373.yaml"
        $emptyEnv = Join-Path $outputPath 'compose.empty.env'
        [IO.File]::WriteAllText($emptyEnv, '')
        $dc = @('compose', '--env-file', $emptyEnv, '--project-directory', $ROOT, '-f', $cf)
        $env:LAB373_RUN_ID = $RUN_ID
        $env:LAB373_OUTPUT_DIR = $outputPath
        $summary = @{}
        foreach ($arm in @('A','B')) {
            $chosen = if($arm -eq 'A') { 'wed-snap-media:2026.08.19' } else { $ImageTag }
            $env:LAB373_IMAGE = $chosen
            $env:AB_ARM = $arm
            $env:AB_TARGET = if($arm -eq 'B') { $Target } else { '' }
            (Native "compose-config-$arm" ($dc + @('config'))).out | Set-Content (Join-Path $outputPath "compose-$arm-resolved.yaml") -Encoding utf8
            Create-ComposeResources $dc
            $e = Guard 'wed-snap-tiktok-373-egress' 'wed-snap-egress:local' '65534:65534' 100663296 'wed-snap-tiktok-lab-373_outbound' @('wed-snap-tiktok-lab-373_outbound', 'wed-snap-tiktok-lab-373_private') @() @('PATH','LANG','PYTHON_VERSION','PYTHON_SHA256','GPG_KEY') @('python','egress.py')
            $p = Guard 'wed-snap-tiktok-373-probe' $chosen '1000:1000' 402653184 'wed-snap-tiktok-lab-373_private' @('wed-snap-tiktok-lab-373_private') $ro $allowedEnvBase @('python3','/p37/probe_373.py') @('/usr/bin/tini','-g','--')
            Check (-not $e.Config.Entrypoint) 'egress unexpected entrypoint'
            Check ($p.Id -in $global:createdContainerIds -and $e.Id -in $global:createdContainerIds) 'untracked ID'
            Check (([long]$e.HostConfig.Memory + [long]$p.HostConfig.Memory) -le 480MB) 'lab memory > 480MiB'
            Check (@($p.Config.Env) -contains 'MEDIA_PROXY=http://egress:8888') 'proxy value wrong'
            Check (@($p.Config.Env) -contains "AB_ARM=$arm" -and @($p.Config.Env) -contains "AB_TARGET=$($env:AB_TARGET)") 'arm/target values wrong'
            $nw = (Native "net-inspect-$arm" @('network', 'inspect', 'wed-snap-tiktok-lab-373_private', 'wed-snap-tiktok-lab-373_outbound')).out | ConvertFrom-Json
            foreach($n in $nw) { Check ($n.Id -in $global:createdNetworkIds -and $n.Labels.'com.wed-snap.run' -eq $RUN_ID -and $n.Labels.'com.wed-snap.lab' -eq 'tiktok-373') 'network ownership'; Check ($n.Driver -eq 'bridge') 'network driver' }
            Check (@($nw | Where-Object {$_.Name -eq 'wed-snap-tiktok-lab-373_private' -and $_.Internal}).Count -eq 1) 'probe private network not internal'
            Check (@($nw | Where-Object {$_.Name -eq 'wed-snap-tiktok-lab-373_outbound' -and -not $_.Internal}).Count -eq 1) 'egress outbound flags'
            if($arm -eq 'A') {
                Native 'start-egress' @('start', $e.Id) | Out-Null
                Start-Sleep 2
            }
            Check ((Inspect1 $e.Id).State.Running -eq $true) 'egress not running'
            $r = Native "analyze-$arm" @('start','-a',$p.Id) -TimeoutSec 45 -AllowFail
            $state=(Inspect1 $p.Id).State
            Check (-not $state.Running -and -not $state.OOMKilled -and $state.ExitCode -eq $r.code) 'native/container exit mismatch or OOM'
            Check ($r.code -in @(0,20)) 'unexpected harness failure'
            $report=Get-Content (Join-Path $outputPath "ab-attempt-$arm.json") -Raw | ConvertFrom-Json
            Check ($report.harness_status -eq 'COMPLETED' -and $report.arm -eq $arm) 'incomplete report'
            Check (($r.code -eq 0 -and $report.metadata_status -eq 'PASS') -or ($r.code -eq 20 -and $report.metadata_status -eq 'FAIL')) 'metadata/exit inconsistency'
            $summary[$arm]=@{metadata_status=$report.metadata_status;harness_status=$report.harness_status;native_exit=$r.code;image_id=$p.Image;seconds=$report.seconds}
            Native "egress-stats-$arm" @('stats','--no-stream','--format','{{json .}}',$e.Id) | Out-Null
            # Exact own ID/run-label inspected again immediately before removing A to make room for B.
            $own=Inspect1 $p.Id
            Check ($own.Id -eq $p.Id -and $own.Config.Labels.'com.wed-snap.run' -eq $RUN_ID -and $own.Config.Labels.'com.wed-snap.lab' -eq 'tiktok-373') 'arm cleanup ownership'
            Native "rm-arm-$arm" @('rm',$p.Id) | Out-Null
            $global:createdContainerIds.Remove($p.Id) | Out-Null
        }
        $summary['harness_status']='COMPLETED'
        $summary['metadata_status']=if($summary.A.metadata_status -eq 'PASS' -or $summary.B.metadata_status -eq 'PASS') {'HAS_METADATA'} else {'BOTH_FAIL'}
        $summary | ConvertTo-Json -Depth 10 | Set-Content (Join-Path $outputPath 'ab-summary.json') -Encoding utf8
        if($summary.metadata_status -eq 'BOTH_FAIL') {$exitCode=20}
        Native 'egress-logs' @('logs','wed-snap-tiktok-373-egress','--tail','30') | Out-Null
    }
}
catch {
    Add-Content $LOG ((@{ step = 'ABORT'; end = (Stamp); error = (Clean $_.Exception.Message) } | ConvertTo-Json -Compress)) -Encoding utf8
    Write-Host ('ABORT: ' + (Clean $_.Exception.Message))
    $exitCode = 30
}
finally {
    foreach ($key in $origLabEnv.Keys) { [Environment]::SetEnvironmentVariable($key, $origLabEnv[$key], 'Process') }
    if ($null -ne $origAbTarget) {
        $env:AB_TARGET = $origAbTarget
    } else {
        Remove-Item env:AB_TARGET -ErrorAction SilentlyContinue
    }
    $left = Cleanup
    if ($left -ne 0 -and $exitCode -eq 0) { $exitCode = 31 }
    Add-Content $LOG ((@{ step = 'end'; end = (Stamp); exit = $exitCode } | ConvertTo-Json -Compress)) -Encoding utf8
}
exit $exitCode


