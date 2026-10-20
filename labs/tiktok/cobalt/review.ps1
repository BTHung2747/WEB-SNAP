$ErrorActionPreference='Stop';Set-Location 'D:\WED SNAP'
$review='docs/evidence/tiktok-cobalt-candidate-live-20261008/review-2'
if(Test-Path $review){throw 'Refuse repeated review evidence'}
New-Item -ItemType Directory $review|Out-Null
$inputDir=(Resolve-Path docs/evidence/tiktok-cobalt-candidate-live-20261008/sample-1).Path
$outDir=(Resolve-Path $review).Path;$scriptPath=(Resolve-Path labs/tiktok/cobalt/review_media.py).Path
$run=[Guid]::NewGuid().ToString('N');$id=$null;$log="$review/native.jsonl"
function Native($step,[string[]]$commandArgs){
 $utc=[DateTime]::UtcNow;$text=& docker.exe @commandArgs 2>&1|Out-String;$code=$LASTEXITCODE
 @{step=$step;argv=$commandArgs;actualExit=$code;startUTC=$utc.ToString('o');endUTC=[DateTime]::UtcNow.ToString('o');endVN=[DateTime]::UtcNow.AddHours(7).ToString('yyyy-MM-dd HH:mm:ss.fff');output=$text}|ConvertTo-Json -Depth 4 -Compress|Add-Content $log -Encoding utf8
 if($code -ne 0){throw "Review $step failed"};return $text.Trim()
}
try{
 $id=Native 'create' @('create','--label','com.wed-snap.lab=cobalt-tiktok','--label',"com.wed-snap.run=$run",'--network','none','--user','1000:1000','--read-only','--cap-drop','ALL','--security-opt','no-new-privileges:true','--memory','256m','--memory-swap','256m','--cpus','0.5','--pids-limit','96','--tmpfs','/tmp:size=32m,noexec,nosuid','--mount',"type=bind,source=$inputDir,target=/input,readonly",'--mount',"type=bind,source=$outDir,target=/out",'--mount',"type=bind,source=$scriptPath,target=/review.py,readonly",'--pull','never','sha256:5fcc01bb22ca5a264327f4bce4140b07c70d22b0a861ef41ff982d7d0fb3f3a6','/usr/bin/timeout','--signal=KILL','120s','python3','/review.py')
 $c=@((Native 'inspect' @('inspect',$id))|ConvertFrom-Json)[0]
 $expected=@("$($inputDir.Replace('/','\').ToLowerInvariant())|/input|False","$($outDir.Replace('/','\').ToLowerInvariant())|/out|True","$($scriptPath.Replace('/','\').ToLowerInvariant())|/review.py|False")|Sort-Object
 $actual=@($c.Mounts|ForEach-Object {"$($_.Source.Replace('/','\').ToLowerInvariant())|$($_.Destination)|$($_.RW)"})|Sort-Object
 if(($expected-join ';') -cne ($actual-join ';') -or ($c.Config.Cmd-join '|') -cne '/usr/bin/timeout|--signal=KILL|120s|python3|/review.py' -or ($c.Config.Entrypoint-join '|') -cne '/usr/bin/tini|-g|--'){throw 'Review mounts/command guard'}
 if($c.Id -cne $id -or $c.Config.Labels.'com.wed-snap.run' -cne $run -or $c.Image -cne 'sha256:5fcc01bb22ca5a264327f4bce4140b07c70d22b0a861ef41ff982d7d0fb3f3a6' -or
    $c.Config.User -cne '1000:1000' -or -not $c.HostConfig.ReadonlyRootfs -or $c.HostConfig.NetworkMode -cne 'none' -or $c.HostConfig.Memory -ne 256MB -or $c.HostConfig.MemorySwap -ne 256MB -or $c.HostConfig.NanoCpus -ne 500000000 -or $c.HostConfig.PidsLimit -ne 96 -or
    $c.HostConfig.Privileged -or $c.HostConfig.CapAdd -or $c.HostConfig.CapDrop -notcontains 'ALL' -or $c.HostConfig.SecurityOpt -notcontains 'no-new-privileges:true' -or $c.HostConfig.IpcMode -cne 'private' -or $c.HostConfig.PidMode -or
    @($c.HostConfig.SecurityOpt|Where-Object {$_ -like 'seccomp=*'}).Count -or @($c.HostConfig.PortBindings.PSObject.Properties).Count){throw 'Review guard'}
 $c|ConvertTo-Json -Depth 30|Set-Content "$review/guard.json" -Encoding utf8
 Native 'review-media' @('start','-a',$id)|Out-Null
 $done=@((Native 'state' @('inspect',$id))|ConvertFrom-Json)[0]
 if($done.State.Running -or $done.State.OOMKilled -or $done.State.ExitCode -ne 0){throw 'Review outcome'}
}finally{
 if($id){
  $c=@((Native 'ownership' @('inspect',$id))|ConvertFrom-Json)[0]
  if($c.Id -cne $id -or $c.Config.Labels.'com.wed-snap.run' -cne $run){throw 'Review cleanup ownership'}
  Native 'cleanup' @('rm','-f',$id)|Out-Null
 }
 $left=Native 'own-left' @('ps','-a','--filter',"label=com.wed-snap.run=$run",'--format','{{.ID}}')
 if($left){throw 'Review leftovers'}
 @{actualExit=0;ownResourcesLeft=0;removedContainers=1;sourceRequests=0}|ConvertTo-Json|Set-Content "$review/completion.json" -Encoding utf8
}
