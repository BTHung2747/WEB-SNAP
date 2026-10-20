# Guard/Native/cleanup reused from frozen run-373; label only is374.
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
    Add-Content $LOG ((@{ step = $name; argv = $dargs; start = $s; end = (Stamp); exit = $code; output = $out.Trim() } | ConvertTo-Json -Compress)) -Encoding utf8
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
    Check ($c.Config.Labels.'com.wed-snap.lab' -eq 'tiktok-374') "$name ownership label missing"
    
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
                if ($actualId.StartsWith($cid) -and $actualLabel -eq 'tiktok-374' -and $lblObj.'com.wed-snap.run' -eq $RUN_ID) {
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
                if ($actualId.StartsWith($nid) -and $actualLabel -eq 'tiktok-374' -and $lblObj.'com.wed-snap.run' -eq $RUN_ID) {
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

