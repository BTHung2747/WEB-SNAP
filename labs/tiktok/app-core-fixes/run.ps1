param([ValidateSet('fixes','regression','runtime')][string]$Mode='fixes',[int]$Attempt=1)
$ErrorActionPreference='Stop';Set-Location 'D:\WED SNAP'
$ev="docs/evidence/tiktok-app-core-fixes-20261009/$Mode-$Attempt"
if(Test-Path $ev){throw 'Evidence exists'};New-Item -ItemType Directory $ev|Out-Null
$run=[Guid]::NewGuid().ToString('N');$id=$null;$rc=1
$receipt=Get-Content docs/evidence/tiktok-app-core-fixes-20261009/build-2/receipt.json -Raw|ConvertFrom-Json
$image=docker image inspect wed-snap-tiktok-app-core-fixes:20261009 --format '{{.Id}}'
if($LASTEXITCODE -or $receipt.actualExit -ne 0 -or $image -cne $receipt.image){throw 'Image gate'}
function Native([string]$step,[string[]]$argv,[switch]$AllowFailure){
 $start=[DateTime]::UtcNow;$text=& docker @argv 2>&1|Out-String;$exit=$LASTEXITCODE
 @{step=$step;actualExit=$exit;utcStart=$start.ToString('o');utcEnd=[DateTime]::UtcNow.ToString('o');stdout=$text}|ConvertTo-Json -Compress|Add-Content "$ev/native.jsonl"
 if($exit -and -not $AllowFailure){throw "Native $step exit$exit"};return @{text=$text.Trim();exit=$exit}
}
try{
 $script=if($Mode -eq 'fixes'){'test_fixes.py'}elseif($Mode -eq 'regression'){'regression_cli.py'}else{'runtime_check.py'}
 $id=(Native 'create' @('create','--label','com.wed-snap.lab=tiktok-app-core-fixes','--label',"com.wed-snap.run=$run",
 '--network','none','--read-only','--user','1000:1000','--cap-drop','ALL','--security-opt','no-new-privileges:true',
 '--memory','512m','--memory-swap','512m','--cpus','0.75','--pids-limit','96','--ipc','private',
 '--tmpfs','/tmp:size=32m,uid=1000,gid=1000,noexec,nosuid',
 '--mount',"type=bind,source=$((Resolve-Path labs/tiktok/app-core-fixes).Path),target=/fixture,readonly",
 '--mount',"type=bind,source=$((Resolve-Path $ev).Path),target=/out",'-e','PYTHONDONTWRITEBYTECODE=1',
 $image,'/usr/bin/timeout','--signal=KILL','170s','python3',"/fixture/$script")).text
 $c=@((Native 'inspect' @('inspect',$id)).text|ConvertFrom-Json)[0]
 if($c.Image -cne $image -or $c.Config.User -cne '1000:1000' -or -not $c.HostConfig.ReadonlyRootfs -or $c.HostConfig.Memory -ne 512MB -or $c.HostConfig.MemorySwap -ne 512MB -or $c.HostConfig.NanoCpus -ne 750000000 -or $c.HostConfig.NetworkMode -cne 'none' -or $c.HostConfig.IpcMode -cne 'private' -or $c.HostConfig.PidsLimit -ne 96 -or $c.HostConfig.CapDrop -notcontains 'ALL' -or $c.HostConfig.SecurityOpt -notcontains 'no-new-privileges:true'){throw 'Guard failed'}
 $c|ConvertTo-Json -Depth 30|Set-Content "$ev/guard.json"
 $test=Native 'test' @('start','-a',$id) -AllowFailure;$rc=$test.exit;Write-Output $test.text
 $state=@((Native 'state' @('inspect',$id)).text|ConvertFrom-Json)[0].State
 if($state.Running -or $state.ExitCode -ne $rc -or $state.OOMKilled){throw 'Native state mismatch'}
 $state|ConvertTo-Json|Set-Content "$ev/state.json"
}finally{
 if($id){$c=@((docker inspect $id|ConvertFrom-Json))[0];if($c.Config.Labels.'com.wed-snap.run' -cne $run){throw 'Wrong owner'};Native 'remove' @('rm','-f',$id)|Out-Null}
 @{actualExit=$rc;ownResourcesLeft=0;image=$image;sourceCalls=0;utc=[DateTime]::UtcNow.ToString('o');vn=[DateTimeOffset]::UtcNow.ToOffset([TimeSpan]::FromHours(7)).ToString('o')}|ConvertTo-Json|Set-Content "$ev/completion.json"
}
exit $rc
