param([ValidateRange(1,10)][int]$Attempt=1)
$ErrorActionPreference='Stop'
Set-Location 'D:\WED SNAP'
$ev="docs/evidence/tiktok-photo-core-step1-20261015/offline-$Attempt"
if(Test-Path -LiteralPath $ev){throw 'Refuse evidence reuse'}
New-Item -ItemType Directory -Path $ev | Out-Null
$image='sha256:31742091e95df2cc62669a6c6a9e0892dc09a34341eaeefc16959dcd4dfa417e'
$run=[Guid]::NewGuid().ToString('N')
$containerID=$null
function Native([string]$step,[string[]]$arguments){
    $begin=[DateTimeOffset]::UtcNow
    $output=& docker @arguments 2>&1 | Out-String
    $actual=$LASTEXITCODE
    @{step=$step;arguments=$arguments;actualExit=$actual;utcStart=$begin.ToString('o');utcEnd=[DateTimeOffset]::UtcNow.ToString('o');output=$output} |
      ConvertTo-Json -Compress -Depth 8 | Add-Content -LiteralPath "$ev/native.jsonl" -Encoding utf8NoBOM
    if($actual -ne 0){throw "Docker $step exit $actual"}
    return $output.Trim()
}
$sourceFiles=@(Get-ChildItem -LiteralPath apps/media/src/tiktok -Recurse -File | Where-Object {$_.FullName -notmatch '[\\/](node_modules|__pycache__)[\\/]'})
$hashes=@($sourceFiles | Sort-Object FullName | ForEach-Object {@{path=[IO.Path]::GetRelativePath((Resolve-Path apps/media/src/tiktok).Path,$_.FullName).Replace('\','/');sha256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()}})
$hashes | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath "$ev/expected-source.json" -Encoding utf8NoBOM
$testHashes=@(Get-ChildItem -LiteralPath labs/tiktok/photo-core-step1 -File | Sort-Object Name | ForEach-Object {@{path=$_.Name;sha256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()}})
$testHashes | ConvertTo-Json | Set-Content -LiteralPath "$ev/test-source.json" -Encoding utf8NoBOM
try {
    $mounts=@(foreach($file in $sourceFiles){
        $relative=[IO.Path]::GetRelativePath((Resolve-Path apps/media/src/tiktok).Path,$file.FullName).Replace('\','/')
        '--mount';"type=bind,source=$($file.FullName),target=/app/apps/media/src/tiktok/$relative,readonly"
    })
    $containerID=Native 'create' (@('create','--pull=never','--label','com.wed-snap.lab=tiktok-photo-core-step1',
      '--label',"com.wed-snap.run=$run",'--network','none','--ipc','private','--read-only','--user','1000:1000',
      '--cap-drop','ALL','--security-opt','no-new-privileges:true','--memory','512m','--memory-swap','512m',
      '--cpus','0.75','--pids-limit','96','--tmpfs','/tmp:size=48m,uid=1000,gid=1000,noexec,nosuid',
      '--tmpfs','/media:size=96m,uid=1000,gid=1000,noexec,nosuid',
      '-e','MEDIA_ROOT=/media','-e','PYTHONDONTWRITEBYTECODE=1','-e','NODE_OPTIONS=--max-old-space-size=128',
      '-e','PYTHONPATH=/app/apps/media/src:/fixture',
      '--mount',"type=bind,source=$((Resolve-Path labs/tiktok/photo-core-step1).Path),target=/fixture,readonly",
      '--mount',"type=bind,source=$((Resolve-Path $ev).Path),target=/out")+$mounts+@(
      $image,'/usr/bin/timeout','--signal=KILL','300s','python3','/fixture/gate.py'))
    $guard=@((Native 'guard' @('inspect',$containerID) | ConvertFrom-Json))[0]
    if($guard.Image -cne $image -or $guard.Config.User -cne '1000:1000' -or !$guard.HostConfig.ReadonlyRootfs -or
      $guard.HostConfig.Memory -ne 512MB -or $guard.HostConfig.MemorySwap -ne 512MB -or
      $guard.HostConfig.NanoCpus -ne 750000000 -or $guard.HostConfig.NetworkMode -cne 'none' -or
      $guard.HostConfig.IpcMode -cne 'private' -or $guard.HostConfig.PidsLimit -ne 96 -or
      $guard.HostConfig.CapDrop -notcontains 'ALL' -or $guard.HostConfig.SecurityOpt -notcontains 'no-new-privileges:true'){
        throw 'Offline guard mismatch'
    }
    $guard | ConvertTo-Json -Depth 40 | Set-Content -LiteralPath "$ev/guard.json" -Encoding utf8NoBOM
    Native 'test' @('start','-a',$containerID) | Out-Null
    $finished=@((Native 'state' @('inspect',$containerID)|ConvertFrom-Json))[0]
    if($finished.State.ExitCode -ne 0 -or $finished.State.OOMKilled){throw 'Native state failed'}
    foreach($row in $hashes){
        if((Get-FileHash -LiteralPath "apps/media/src/tiktok/$($row.path)" -Algorithm SHA256).Hash.ToLowerInvariant() -cne $row.sha256){throw 'Host source changed during gate'}
    }
    $result=Get-Content -LiteralPath "$ev/results.json" -Raw|ConvertFrom-Json
    if($result.status -cne 'PASS_OFFLINE_PHOTO_CORE_NOT_WIRED'){throw 'Result missing'}
    @{status='PASS_OFFLINE_ONLY';image=$image;actualExit=$finished.State.ExitCode;OOMKilled=$finished.State.OOMKilled;sourceCalls=0;checks=$result.tests;utc=[DateTimeOffset]::UtcNow.ToString('o');vn=[TimeZoneInfo]::ConvertTimeBySystemTimeZoneId([DateTimeOffset]::UtcNow,'SE Asia Standard Time').ToString('o')} |
      ConvertTo-Json | Set-Content -LiteralPath "$ev/completion.json" -Encoding utf8NoBOM
} finally {
    if($containerID){
        $owned=@((Native 'cleanup-ownership' @('inspect',$containerID)|ConvertFrom-Json))[0]
        if($owned.Config.Labels.'com.wed-snap.run' -cne $run){throw 'Wrong cleanup owner'}
        Native 'remove-own' @('rm','-f',$containerID)|Out-Null
        $remaining=Native 'verify-own-absent' @('ps','-aq','--filter',"label=com.wed-snap.run=$run")
        if($remaining){throw 'Owned resource remains'}
        @{run=$run;containerID=$containerID;ownResourcesLeft=0;networksCreated=0;volumesCreated=0;utc=[DateTimeOffset]::UtcNow.ToString('o')} |
          ConvertTo-Json | Set-Content -LiteralPath "$ev/cleanup.json" -Encoding utf8NoBOM
    }
}
