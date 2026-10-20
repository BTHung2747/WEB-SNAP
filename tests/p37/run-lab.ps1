# P37.1 runner: guards -> probe (max 2 passes) -> cleanup. Evidence in docs\evidence\p37-1-20261005.
# Usage (from D:\WED SNAP): powershell -File tests\p37\run-lab.ps1
$ErrorActionPreference = 'Continue'
Set-Location 'D:\WED SNAP'
$ev = 'docs\evidence\p37-1-20261005'
New-Item -ItemType Directory -Force $ev | Out-Null
$compose = @('compose', '--project-directory', '.', '-f', 'infra/compose.tiktok-lab.yaml')
$log = Join-Path $ev 'runner-log.jsonl'
$vn = [TimeZoneInfo]::FindSystemTimeZoneById('SE Asia Standard Time')
function Stamp { $u = [DateTime]::UtcNow; '{0:o}|VN {1:yyyy-MM-dd HH:mm:ss.fff}' -f $u, [TimeZoneInfo]::ConvertTimeFromUtc($u, $vn) }
function Step($name, [scriptblock]$b) {
    $s = Stamp
    $out = & $b 2>&1 | Out-String
    $code = $LASTEXITCODE
    $e = Stamp
    $out = [regex]::Replace($out, '(?i)https?://[^\s''"<>]+', { param($m) ($m.Value -split '[?#]')[0] })
    (@{ step = $name; start = $s; end = $e; exit = $code; output = $out.Trim() } | ConvertTo-Json -Compress) | Add-Content $log -Encoding utf8
    Write-Host "[$name] exit=$code"
    return @{ exit = $code; out = $out }
}
function Own($kind) {
    # ownership by compose project label only
    if ($kind -eq 'c') { docker ps -a --filter 'label=com.docker.compose.project=wed-snap-tiktok-lab' --format '{{.Names}}' }
    else { docker network ls --filter 'label=com.docker.compose.project=wed-snap-tiktok-lab' --format '{{.Name}}' }
}

# G0: lab must not pre-exist
$pre = Step 'guard-preexisting' { 'containers=' + ((Own 'c') -join ','); 'networks=' + ((Own 'n') -join ',') }
if ($pre.out -match 'containers=\S' -or $pre.out -match 'networks=\S') { Write-Host 'ABORT: lab already exists'; exit 10 }

# G1: images present + pinned ids
Step 'images' { docker image inspect wed-snap-egress:local wed-snap-media:2026.08.19 --format '{{.RepoTags}} {{.Id}} {{.Size}}' } | Out-Null
Step 'resolved-config' { docker @compose config } | ForEach-Object { $_.out | Set-Content (Join-Path $ev 'compose-resolved.yaml') -Encoding utf8 } | Out-Null
Step 'yt-dlp-version' { docker run --rm --pull never --network none --entrypoint /opt/media/bin/python wed-snap-media:2026.08.19 -c 'import yt_dlp;print(yt_dlp.version.__version__)' } | Out-Null

# Create (not start) both, then inspect actual config BEFORE any request
Step 'create' { docker @compose up --no-start --pull never } | Out-Null
$ins = Step 'inspect-actual' {
    docker inspect wed-snap-tiktok-lab-egress wed-snap-tiktok-lab-probe --format '{{.Name}} user={{.Config.User}} ro={{.HostConfig.ReadonlyRootfs}} capdrop={{.HostConfig.CapDrop}} secopt={{.HostConfig.SecurityOpt}} mem={{.HostConfig.Memory}} pids={{.HostConfig.PidsLimit}} ports={{.HostConfig.PortBindings}} netmode={{.HostConfig.NetworkMode}} nets={{range $k,$v := .NetworkSettings.Networks}}{{$k}};{{end}} mounts={{range .Mounts}}{{.Source}}->{{.Destination}}({{.RW}});{{end}}'
    docker network inspect wed-snap-tiktok-lab_private wed-snap-tiktok-lab_outbound --format '{{.Name}} internal={{.Internal}}'
}
$ins.out | Set-Content (Join-Path $ev 'inspect-actual.txt') -Encoding utf8
if ($ins.out -notmatch 'wed-snap-tiktok-lab_private internal=true') { Write-Host 'ABORT: private network not internal'; docker @compose down --remove-orphans; exit 11 }
Step 'start-egress' { docker start wed-snap-tiktok-lab-egress; Start-Sleep 2; docker inspect wed-snap-tiktok-lab-egress --format '{{.State.Status}}' } | Out-Null

$passes = 0
foreach ($i in 1..2) {
    if ($i -eq 2) { Start-Sleep 60 }
    $r = Step "probe-pass$i" { docker start -a wed-snap-tiktok-lab-probe }
    $passes++
    if ($r.out -match 'refused') { break }
}

# Cleanup by own labels only; no -v, no prune
Step 'egress-logs' { docker logs wed-snap-tiktok-lab-egress --tail 40 } | Out-Null
Step 'down' { docker @compose down --remove-orphans } | Out-Null
$post = Step 'verify-cleanup' { 'containers=' + ((Own 'c') -join ','); 'networks=' + ((Own 'n') -join ',') }
Write-Host ($post.out)
