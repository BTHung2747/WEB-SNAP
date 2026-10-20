param([ValidateSet('cli','runtime','typecheck')][string]$Mode='cli',[ValidateRange(1,20)][int]$Attempt=6)
$ErrorActionPreference='Stop';Set-Location 'D:\WED SNAP'
$ev=if($Mode -eq 'cli'){"docs/evidence/tiktok-app-integration-20261009/cli-$Attempt"}else{"docs/evidence/tiktok-app-integration-20261009/$Mode-$Attempt"}
if(Test-Path $ev){throw 'Refuse evidence reuse'};New-Item -ItemType Directory -Path $ev|Out-Null
$run=[Guid]::NewGuid().ToString('N');$id=$null;$image=(docker image inspect wed-snap-tiktok-app-integration:20261009 --format '{{.Id}}')
if($LASTEXITCODE){throw 'No cached integration lab image'}
function Native([string]$step,[string[]]$argv){
 $start=[DateTime]::UtcNow;$text=& docker @argv 2>&1|Out-String;$exit=$LASTEXITCODE
 @{step=$step;actualExit=$exit;utcStart=$start.ToString('o');utcEnd=[DateTime]::UtcNow.ToString('o');stdout=$text}|ConvertTo-Json -Compress|Add-Content "$ev/native.jsonl"
 if($exit){throw "Native $step exit$exit"};return $text.Trim()
}
try{
 $command=if($Mode -eq 'cli'){@('/usr/bin/timeout','--signal=KILL','170s','python3','/fixture/test_cli.py')}elseif($Mode -eq 'runtime'){@('/usr/bin/timeout','--signal=KILL','30s','python3','/fixture/runtime_check.py')}else{@('/usr/bin/timeout','--signal=KILL','60s','bash','-c','node_modules/.bin/prisma generate --schema prisma/schema.prisma > /out/prisma-generate.log 2>&1 && node_modules/.bin/tsc -p tsconfig.json --noEmit')}
 $id=Native 'create' (@('create','--label','com.wed-snap.lab=tiktok-app-integration','--label',"com.wed-snap.run=$run",
 '--network','none','--read-only','--user','1000:1000','--cap-drop','ALL','--security-opt','no-new-privileges:true',
 '--memory','512m','--memory-swap','512m','--cpus','0.75','--pids-limit','96','--tmpfs','/tmp:size=32m,uid=1000,gid=1000,noexec,nosuid',
 '--mount',"type=bind,source=$((Resolve-Path labs/tiktok/app-integration).Path),target=/fixture,readonly",
 '--mount',"type=bind,source=$((Resolve-Path apps/media/src/media_adapter.py).Path),target=/app/infra/media_adapter.py,readonly",
 '--mount',"type=bind,source=$((Resolve-Path apps/worker/src).Path),target=/app/apps/worker/src,readonly",
 '--mount',"type=bind,source=$((Resolve-Path apps/api/src).Path),target=/app/apps/api/src,readonly",
 '--mount',"type=bind,source=$((Resolve-Path packages/shared/src).Path),target=/app/packages/shared/src,readonly",
 '--mount',"type=bind,source=$((Resolve-Path prisma).Path),target=/app/prisma,readonly",
 '--tmpfs','/app/node_modules/.prisma:size=64m,uid=1000,gid=1000,nosuid,exec',
 '-e','DATABASE_URL=postgresql://offline@127.0.0.1:9/tiktok_typecheck_unused',
 '--mount',"type=bind,source=$((Resolve-Path $ev).Path),target=/out",'-e','PYTHONDONTWRITEBYTECODE=1',
 $image)+$command)
 $c=@((Native 'inspect' @('inspect',$id)|ConvertFrom-Json))[0]
 if($c.Image -cne $image -or $c.Config.User -cne '1000:1000' -or -not $c.HostConfig.ReadonlyRootfs -or $c.HostConfig.Memory -ne 512MB -or $c.HostConfig.NanoCpus -ne 750000000 -or $c.HostConfig.NetworkMode -cne 'none' -or $c.HostConfig.CapDrop -notcontains 'ALL' -or $c.HostConfig.SecurityOpt -notcontains 'no-new-privileges:true'){throw 'Guard failed'}
 $c|ConvertTo-Json -Depth 30|Set-Content "$ev/guard.json"
 Native 'test' @('start','-a',$id)|Out-Null
}finally{
 if($id){$c=@((docker inspect $id|ConvertFrom-Json))[0];if($c.Config.Labels.'com.wed-snap.run' -cne $run){throw 'Wrong owner'};Native 'remove' @('rm','-f',$id)|Out-Null}
}
@{actualExit=0;ownResourcesLeft=0;image=$image;sourceCalls=0;utc=[DateTime]::UtcNow.ToString('o')}|ConvertTo-Json|Set-Content "$ev/completion.json"
