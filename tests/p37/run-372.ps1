# P37.2 runner. Actual guards run before containers are started.
# Stages:  offline  -> offline fixtures + capability check (--network none, no Internet)
#          ab       -> 2 analyze attempts (A default / B impersonate target) via own egress (needs -Target)
# Usage (from D:\WED SNAP):  powershell -NoProfile -File tests\p37\run-372.ps1 -Stage offline
param(
    [Parameter(Mandatory = $true)][ValidateSet('offline', 'ab')][string]$Stage,
    [string]$Target = '',
    [string]$EvidenceDir = ''
)
Set-StrictMode -Version 2
$ErrorActionPreference = 'Stop'
$ROOT = 'D:\WED SNAP'
Set-Location $ROOT
$RUN_ID = [Guid]::NewGuid().ToString('N')
$RUN_LABEL = "com.wed-snap.run=$RUN_ID"
if (-not $EvidenceDir) { $EvidenceDir = "docs\evidence\p37-2-$RUN_ID" }
$outputPath = [IO.Path]::GetFullPath((Join-Path $ROOT $EvidenceDir))
$evidenceRoot = [IO.Path]::GetFullPath("$ROOT\docs\evidence\")
if (-not $outputPath.StartsWith($evidenceRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'Output must be inside docs/evidence' }
if (Test-Path -LiteralPath $outputPath) { throw 'Refuse to reuse an evidence directory' }
$EV = $outputPath.Substring($ROOT.Length + 1)
New-Item -ItemType Directory -Path $outputPath | Out-Null
$LOG = Join-Path (Join-Path $ROOT $EV) "runner-$Stage.jsonl"
$LABEL = 'com.wed-snap.lab=tiktok-372'
$PIN = @{
    'wed-snap-egress:local' = 'sha256:8bc0a567955111ea3cfbab2dd3b14f40a602f2d10ac987e78eb465f9d48d7f10';
    'wed-snap-media:2026.08.19' = 'sha256:ecb3e7477d301d766046b92c586604a5650e22a0bac8e675b45699784f65737b'
}
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
    Check ($c.Config.User -eq $user) "$name user $($c.Config.User) != expected $user"
    Check ($c.HostConfig.ReadonlyRootfs -eq $true) "$name rootfs not read-only"
    Check (-not $c.HostConfig.Privileged) "$name privileged"
    Check (@($c.HostConfig.CapDrop) -contains 'ALL' -and -not $c.HostConfig.CapAdd) "$name caps invalid"
    Check (@($c.HostConfig.SecurityOpt) -contains 'no-new-privileges:true') "$name missing no-new-privileges"
    Check ([long]$c.HostConfig.Memory -eq $mem -and ([long]$c.HostConfig.MemorySwap -eq $mem -or [long]$c.HostConfig.MemorySwap -eq (2 * $mem) -or [long]$c.HostConfig.MemorySwap -le 0)) "$name memory $($c.HostConfig.Memory)"
    Check ([long]$c.HostConfig.PidsLimit -eq 64) "$name pids $($c.HostConfig.PidsLimit) != 64"
    Check (-not $c.HostConfig.PidMode -or $c.HostConfig.PidMode -eq 'private') "$name pid mode $($c.HostConfig.PidMode) is not private"
    Check (@($c.HostConfig.PortBindings.PSObject.Properties).Count -eq 0) "$name has published ports"
    Check ($c.HostConfig.NetworkMode -eq $netmode) "$name network mode $($c.HostConfig.NetworkMode) != expected $netmode"
    $have = @($c.NetworkSettings.Networks.PSObject.Properties.Name | Sort-Object) -join ','
    Check ($have -eq (($nets | Sort-Object) -join ',')) "$name networks '$have' != '$($nets -join ',')'"
    Check ($c.Config.Labels.'com.wed-snap.lab' -eq 'tiktok-372') "$name ownership label missing"
    
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
                if ($actualId.StartsWith($cid) -and $actualLabel -eq 'tiktok-372' -and $lblObj.'com.wed-snap.run' -eq $RUN_ID) {
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
                if ($actualId.StartsWith($nid) -and $actualLabel -eq 'tiktok-372' -and $lblObj.'com.wed-snap.run' -eq $RUN_ID) {
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
foreach ($key in @('LAB372_RUN_ID', 'LAB372_OUTPUT_DIR')) { $origLabEnv[$key] = [Environment]::GetEnvironmentVariable($key, 'Process') }
$exitCode = 0
$allowedEnvBase = @('PATH', 'NODE_VERSION', 'YARN_VERSION', 'HOME', 'PYTHONDONTWRITEBYTECODE', 'PYTHONUNBUFFERED', 'MEDIA_CACHE_DIR', 'MEDIA_PROXY', 'AB_TARGET', 'LANG', 'LC_ALL')

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
                '-e', 'HOME=/tmp', '-e', 'PYTHONDONTWRITEBYTECODE=1', '--pull', 'never', 'wed-snap-media:2026.08.19') + $cmd
            try { $cr = Native "create-$name" $a }
            finally { Track-RunResources }
            $cid = $cr.out.Trim()
            if ($cid -match '^[0-9a-fA-F]{12,64}$') {
                if (-not $global:createdContainerIds.Contains($cid)) { $global:createdContainerIds.Add($cid) }
            } else {
                $inspId = ((Native "get-id-$name" @('inspect', $name, '--format', '{{.Id}}')).out).Trim()
                $global:createdContainerIds.Add($inspId)
            }
            Guard $name 'wed-snap-media:2026.08.19' '1000:1000' $memBytes 'none' @('none') $ro $allowedEnvBase $cmd @('/usr/bin/tini', '-g', '--') | Out-Null
            return (Native "run-$name" @('start', '-a', $name) -TimeoutSec 120 -AllowFail)
        }

        # Guard self-test: a wrong expectation MUST throw (fail-closed proof)
        $st = Run-Offline 'wed-snap-tiktok-372-fixture' @('python3', '/p37/test_372_offline.py') '256m' 268435456
        $threw = $false
        try { Guard 'wed-snap-tiktok-372-fixture' 'wed-snap-media:2026.08.19' '0:0' 268435456 'none' @('none') $ro $allowedEnvBase @('python3', '/p37/test_372_offline.py') @('/usr/bin/tini', '-g', '--') | Out-Null } catch { $threw = $true }
        Add-Content $LOG ((@{ step = 'guard-selftest-wrong-user'; threw = $threw } | ConvertTo-Json -Compress)) -Encoding utf8
        Check $threw 'guard did not fail on wrong expectation'
        Check ($st.code -eq 0) "offline fixtures exit=$($st.code)"
        
        $cap = Run-Offline 'wed-snap-tiktok-372-cap' @('python3', '/p37/cap_check.py') '256m' 268435456
        Check ($cap.code -eq 0) "capability check exit=$($cap.code)"
    }
    else {
        Check ($Target -match '^[A-Za-z0-9._:-]{0,40}$') 'bad -Target'
        $cf = "$ROOT\infra\compose.tiktok-lab-372.yaml"
        $emptyEnv = Join-Path $outputPath 'compose.empty.env'
        [IO.File]::WriteAllText($emptyEnv, '')
        $dc = @('compose', '--env-file', $emptyEnv, '--project-directory', $ROOT, '-f', $cf)
        $env:AB_TARGET = $Target
        $env:LAB372_RUN_ID = $RUN_ID
        $env:LAB372_OUTPUT_DIR = $outputPath
        (Native 'compose-config' ($dc + @('config'))).out | Set-Content (Join-Path (Join-Path $ROOT $EV) 'compose-372-resolved.yaml') -Encoding utf8
        Create-ComposeResources $dc
        $e = Guard 'wed-snap-tiktok-372-egress' 'wed-snap-egress:local' '65534:65534' 100663296 'wed-snap-tiktok-lab-372_outbound' @('wed-snap-tiktok-lab-372_outbound', 'wed-snap-tiktok-lab-372_private') @() $allowedEnvBase
        $p = Guard 'wed-snap-tiktok-372-probe' 'wed-snap-media:2026.08.19' '1000:1000' 402653184 'wed-snap-tiktok-lab-372_private' @('wed-snap-tiktok-lab-372_private') @("$ROOT\tests\p37|/p37|False", "$ROOT\$EV|/out|True") $allowedEnvBase
        Check (([long]$e.HostConfig.Memory + [long]$p.HostConfig.Memory) -le 1536MB) 'lab memory > 1536MiB'
        
        $nw = (Native 'net-inspect' @('network', 'inspect', 'wed-snap-tiktok-lab-372_private', 'wed-snap-tiktok-lab-372_outbound', '--format', '{{.Name}} internal={{.Internal}}')).out
        Check ($nw -match 'wed-snap-tiktok-lab-372_private internal=true' -and $nw -match 'wed-snap-tiktok-lab-372_outbound internal=false') 'network internal flags wrong'
        
        Native 'start-egress' @('start', 'wed-snap-tiktok-372-egress') | Out-Null
        Start-Sleep 2
        Check ((Inspect1 'wed-snap-tiktok-372-egress').State.Running -eq $true) 'egress not running'
        
        $r = Native 'ab-probe' @('start', '-a', 'wed-snap-tiktok-372-probe') -TimeoutSec 170 -AllowFail
        if ($r.code -ne 0) { $exitCode = 20 }
        Native 'egress-logs' @('logs', 'wed-snap-tiktok-372-egress', '--tail', '30') -AllowFail | Out-Null
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
