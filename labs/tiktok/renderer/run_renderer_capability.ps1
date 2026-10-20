param([ValidateRange(1,2)][int]$Attempt=1)
# Own offline container only. Stop on capability failure; no downgrade of sandbox or guard.
$ErrorActionPreference='Stop';Set-Location 'D:\WED SNAP'
$root='D:\WED SNAP';$ev="docs/evidence/p37-renderer-launch-20261007/attempt-$Attempt"
if(Test-Path -LiteralPath $ev){throw 'Refuse reused capability evidence'}
New-Item -ItemType Directory -Path $ev | Out-Null
$outPath=(Resolve-Path $ev).Path
$pin=Get-Content docs/evidence/p37-renderer-20261007/image-pin.json -Raw | ConvertFrom-Json
$id=$pin.actualImageID;$run=[Guid]::NewGuid().ToString('N');$cid=$null;$code=30
$name="wed-snap-renderer37-launch-$Attempt";$lab='renderer37-launch';$log="$ev/native.jsonl"
function Sanitize([string]$value){
    $value=[regex]::Replace($value,'\x1b\[[0-9;]*m','')
    $value=[regex]::Replace($value,'(?i)https?://[^\s''"<>]+',{param($m) $u=($m.Value -split '[?#]')[0];$u=[regex]::Replace($u,'^(https?://)[^/]*@','$1');$u+$(if($m.Value -match '[?#]'){'[query-redacted]'}else{''})})
    $value=[regex]::Replace($value,'(?im)\b(authorization|proxy-authorization|cookie|set-cookie)\s*:[^\r\n]*','$1: [redacted]')
    return [regex]::Replace($value,'(?i)\b(mstoken|token|signature|_signature|x-bogus|sessionid|password|secret|bearer)=[^\s&''";]+','$1=[redacted]')
}
function LogText([string]$value){
    $bytes=[Text.Encoding]::UTF8.GetByteCount($value);$safe=Sanitize $value;$truncated=$false
    if($safe.Length -gt 1048576){$truncated=$true;$safe=$safe.Substring(0,524288)+"`n[LOG MIDDLE OMITTED]`n"+$safe.Substring($safe.Length-524288)}
    return @{bytesReceived=$bytes;truncated=$truncated;retention=$(if($truncated){'head+tail'}else{'full'});text=$safe}
}
function Native([string]$step,[string[]]$argsDocker,[switch]$AllowFail,[int]$DeadlineSec=15){
    $start=[DateTime]::UtcNow
    $info=[Diagnostics.ProcessStartInfo]::new();$info.FileName=(Get-Command docker.exe -CommandType Application | Select-Object -First 1).Source
    $info.UseShellExecute=$false;$info.RedirectStandardOutput=$true;$info.RedirectStandardError=$true
    foreach($arg in $argsDocker){$info.ArgumentList.Add($arg)}
    $process=[Diagnostics.Process]::Start($info)
    $stdout=$process.StandardOutput.ReadToEndAsync();$stderr=$process.StandardError.ReadToEndAsync()
    $timedOut=-not $process.WaitForExit($DeadlineSec*1000)
    if($timedOut){$process.Kill($true);$process.WaitForExit()}
    $out=$stdout.GetAwaiter().GetResult();$err=$stderr.GetAwaiter().GetResult();$exit=$process.ExitCode;$process.Dispose()
    @{step=$step;args=$argsDocker;startUTC=$start.ToString('o');endUTC=[DateTime]::UtcNow.ToString('o');endVN=[DateTime]::UtcNow.AddHours(7).ToString('yyyy-MM-dd HH:mm:ss.fff');actualExit=$exit;timedOut=$timedOut;deadlineSec=$DeadlineSec;stdout=(LogText $out);stderr=(LogText $err)} | ConvertTo-Json -Depth 8 -Compress | Add-Content $log -Encoding utf8
    Write-Output "[$step] nativeexit=$exit" | Write-Host
    if($timedOut){throw "Native $step exceeded $DeadlineSec seconds"}
    if($exit -ne 0 -and -not $AllowFail){throw "Native $step exit=$exit"}
    return @{out=$out.Trim();err=$err;code=$exit}
}
function Check($ok,[string]$why){if(-not $ok){throw "GUARD: $why"}}
try{
    Check (-not (Native 'preexisting' @('ps','-a','--filter',"label=com.wed-snap.lab=$lab",'--format','{{.ID}}')).out) 'preexisting container; preserve'
    Check ((Native 'image-pin' @('image','inspect',$id,'--format','{{.Id}}')).out -ceq $id) 'image ID'
    $cmd=@('/usr/bin/timeout','--signal=KILL','30s','node','/lab/renderer_capability.js')
    $sec=(Resolve-Path infra/renderer-seccomp-1.63.json).Path
    $argsDocker=@('create','--name',$name,'--label',"com.wed-snap.lab=$lab",'--label',"com.wed-snap.run=$run",'--network','none','--read-only','--user','1000:1000','--cap-drop','ALL','--security-opt','no-new-privileges:true','--security-opt',"seccomp=$sec",'--memory','928m','--memory-swap','928m','--cpus','1.0','--pids-limit','256','--shm-size','128m','--tmpfs','/tmp:size=128m,noexec,nosuid','--mount',"type=bind,source=$root\labs\tiktok\renderer,target=/lab,readonly",'--mount',"type=bind,source=$outPath,target=/out",'-e','HOME=/tmp','-e','DEBUG=pw:browser','-e','DEBUG_COLORS=0','--pull','never',$id)+$cmd
    $cid=(Native 'create' $argsDocker).out
    Check ($cid -match '^[a-f0-9]{64}$') 'container ID'
    $c=@((Native 'inspect-before-start' @('inspect',$cid)).out | ConvertFrom-Json)[0]
    $c | ConvertTo-Json -Depth 40 | Set-Content "$ev/actual-guard.json" -Encoding utf8
    Check ($c.Id -ceq $cid -and $c.Image -ceq $id -and $c.Config.User -ceq '1000:1000') 'identity/image/user'
    Check ($c.Config.Labels.'com.wed-snap.lab' -ceq $lab -and $c.Config.Labels.'com.wed-snap.run' -ceq $run) 'ownership'
    Check ($c.HostConfig.ReadonlyRootfs -and -not $c.HostConfig.Privileged -and -not $c.HostConfig.CapAdd -and $c.HostConfig.CapDrop -contains 'ALL') 'rootfs/caps'
    $actualSec=@($c.HostConfig.SecurityOpt | Where-Object {$_ -like 'seccomp=*'})[0].Substring(8)
    Check ((($actualSec | ConvertFrom-Json | ConvertTo-Json -Depth 60 -Compress) -ceq (Get-Content $sec -Raw | ConvertFrom-Json | ConvertTo-Json -Depth 60 -Compress))) 'actual pinned seccomp payload'
    Check ($c.HostConfig.SecurityOpt -contains 'no-new-privileges:true' -and @($c.HostConfig.SecurityOpt | Where-Object {$_ -like 'seccomp=*'}).Count -eq 1) 'security profile'
    Check ($c.HostConfig.NetworkMode -ceq 'none' -and -not $c.HostConfig.PidMode -and $c.HostConfig.IpcMode -ceq 'private' -and @($c.HostConfig.PortBindings.PSObject.Properties).Count -eq 0) 'network/PID/IPC/ports'
    Check ($c.HostConfig.Memory -eq 928MB -and $c.HostConfig.MemorySwap -eq 928MB -and $c.HostConfig.NanoCpus -eq 1000000000 -and $c.HostConfig.PidsLimit -eq 256 -and $c.HostConfig.ShmSize -eq 128MB) 'resources'
    Check ($c.Mounts.Count -eq 2 -and @($c.Mounts | Where-Object {$_.Destination -eq '/lab' -and -not $_.RW -and $_.Source.Replace('/','\') -ieq "$root\labs\tiktok\renderer"}).Count -eq 1 -and @($c.Mounts | Where-Object {$_.Destination -eq '/out' -and $_.RW -and $_.Source.Replace('/','\') -ieq $outPath}).Count -eq 1) 'exact mounts'
    Check ((@($c.Config.Cmd)-join '|') -ceq ($cmd-join '|') -and (@($c.Config.Entrypoint)-join '|') -ceq '/usr/bin/tini|-g|--') 'command/entrypoint'
    $r=Native 'offline-launch' @('start','-a',$cid) -AllowFail -DeadlineSec 35
    $state=(Native 'state' @('inspect',$cid,'--format','{{json .State}}')).out | ConvertFrom-Json
    Check (-not $state.Running -and -not $state.OOMKilled -and $state.ExitCode -eq $r.code) 'native/container state'
    $code=$r.code
}catch{
    @{step='ABORT';utc=[DateTime]::UtcNow.ToString('o');error=$_.Exception.Message} | ConvertTo-Json -Compress | Add-Content $log -Encoding utf8
    Write-Output $_.Exception.Message;$code=30
}finally{
    if(-not $cid){
        $recovered=(Native 'recover-own-run-id' @('ps','-a','--no-trunc','--filter',"label=com.wed-snap.lab=$lab",'--filter',"label=com.wed-snap.run=$run",'--format','{{.ID}}')).out
        if($recovered){Check ($recovered -match '^[a-f0-9]{64}$') 'ambiguous own ID';$cid=$recovered}
    }
    if($cid -match '^[a-f0-9]{64}$'){
        $c=@((Native 'identity-before-remove' @('inspect',$cid)).out | ConvertFrom-Json)[0]
        Check ($c.Id -ceq $cid -and $c.Config.Labels.'com.wed-snap.run' -ceq $run -and $c.Config.Labels.'com.wed-snap.lab' -ceq $lab) 'cleanup identity'
        Native 'remove-own-container' @('rm','-f',$cid) | Out-Null
    }
    $left=(Native 'own-left' @('ps','-a','--filter',"label=com.wed-snap.lab=$lab",'--format','{{.ID}}')).out
    Check (-not $left) 'cleanup unknown/nonempty'
    @{step='end';utc=[DateTime]::UtcNow.ToString('o');vn=[DateTime]::UtcNow.AddHours(7).ToString('yyyy-MM-dd HH:mm:ss.fff');actualExit=$code;ownResourcesLeft=0;sourceNavigations=0} | ConvertTo-Json -Compress | Add-Content $log -Encoding utf8
}
exit $code
