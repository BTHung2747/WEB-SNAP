param([Parameter(Mandatory=$true)][ValidateSet('before','after')][string]$Phase, [int]$Attempt=1)
$ErrorActionPreference='Stop'
$root=(Resolve-Path "$PSScriptRoot/../..").Path
$ev=Join-Path $root 'docs/evidence/p37-2-review-20261005'
$log=Join-Path $ev "python-$Phase-$Attempt.jsonl"
if(Test-Path $log){throw 'Refuse to overwrite evidence'}
$pin='sha256:ecb3e7477d301d766046b92c586604a5650e22a0bac8e675b45699784f65737b'
$label='com.wed-snap.review=372-offline'
$name="wed-snap-372-review-$Phase"
$cid=$null; $exitCode=1
function D([string[]]$a) {
    $utc=[DateTime]::UtcNow.ToString('o')
    $savedPreference=$ErrorActionPreference
    try { $ErrorActionPreference='Continue'; $output=(& docker @a 2>&1 | Out-String); $code=$LASTEXITCODE }
    finally { $ErrorActionPreference=$savedPreference }
    @{utc=$utc;args=$a;exit=$code;output=[string]$output} | ConvertTo-Json -Depth 8 -Compress | Add-Content $log -Encoding UTF8
    if($code -ne 0){throw "Docker command failed ($code): $($a[0])"}
    return $output.Trim()
}
function Require($ok,$why){if(-not $ok){throw "GUARD: $why"}}
try {
    Require ((D @('ps','-a','--filter',"label=$label",'--format','{{.ID}}')) -eq '') 'preexisting review container'
    Require ((D @('image','inspect',$pin,'--format','{{.Id}}')) -eq $pin) 'cached pin'
    $code="import subprocess,sys; codes=[subprocess.call([sys.executable,'/p37/'+f]) for f in ['review_helpers.py','test_372_offline.py']]; sys.exit(max(codes))"
    $cid=D @('create','--name',$name,'--label',$label,'--network','none','--read-only','--user','1000:1000','--cap-drop','ALL','--security-opt','no-new-privileges:true','--memory','128m','--memory-swap','128m','--cpus','0.5','--pids-limit','32','--tmpfs','/tmp:size=16m,noexec,nosuid','--mount',"type=bind,source=$root\tests\p37,target=/p37,readonly",'--env','PYTHONDONTWRITEBYTECODE=1','--env','PYTHONPATH=/p37','--pull','never',$pin,'python3','-c',$code)
    Require ($cid -match '^[a-f0-9]{64}$') 'container ID'
    $c=@((D @('inspect',$cid) | ConvertFrom-Json))[0]
    Require ($c.Id -eq $cid -and $c.Image -eq $pin -and $c.Config.Labels.'com.wed-snap.review' -eq '372-offline') 'identity'
    Require ($c.Config.User -eq '1000:1000' -and $c.HostConfig.ReadonlyRootfs -and -not $c.HostConfig.Privileged) 'user/rootfs'
    Require ($c.HostConfig.NetworkMode -eq 'none' -and -not $c.HostConfig.PidMode -and @($c.HostConfig.PortBindings.PSObject.Properties).Count -eq 0) 'network/PID/ports'
    Require ($c.HostConfig.Memory -eq 128MB -and $c.HostConfig.MemorySwap -eq 128MB -and $c.HostConfig.NanoCpus -eq 500000000 -and $c.HostConfig.PidsLimit -eq 32) 'resources'
    Require (@($c.HostConfig.CapDrop) -contains 'ALL' -and -not $c.HostConfig.CapAdd -and @($c.HostConfig.SecurityOpt) -contains 'no-new-privileges:true') 'capabilities'
    Require ($c.Mounts.Count -eq 1 -and -not $c.Mounts[0].RW -and $c.Mounts[0].Destination -eq '/p37' -and $c.Mounts[0].Source.Replace('/','\').TrimEnd('\') -ieq "$root\tests\p37") 'source RO mount only'
    Require ((@($c.Config.Cmd) -join '|') -ceq (@('python3','-c',$code) -join '|')) 'command'
    Require ((@($c.Config.Entrypoint) -join '|') -eq '/usr/bin/tini|-g|--') 'entrypoint'
    try { D @('start','-a',$cid) | Write-Output } catch { Write-Output $_.Exception.Message }
    $state=(D @('inspect',$cid,'--format','{{json .State}}') | ConvertFrom-Json)
    Require (-not $state.Running -and -not $state.OOMKilled) 'completed without OOM'
    $exitCode=[int]$state.ExitCode
    Write-Output "ACTUAL container exit=$exitCode"
} finally {
    if($cid -match '^[a-f0-9]{64}$') {
        $identity=@((D @('inspect',$cid) | ConvertFrom-Json))[0]
        Require ($identity.Id -eq $cid -and $identity.Config.Labels.'com.wed-snap.review' -eq '372-offline') 'cleanup identity'
        D @('rm','-f',$cid) | Out-Null
    }
    Require ((D @('ps','-a','--filter',"label=$label",'--format','{{.ID}}')) -eq '') 'no review containers left'
}
exit $exitCode
