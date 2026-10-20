param([int]$Attempt=1)
$ErrorActionPreference='Stop';Set-Location 'D:\WED SNAP'
$root='docs/evidence/tiktok-photo-setup-trace-20261010';$ev="$root/offline-$Attempt"
if(Test-Path $ev){throw 'Refuse attempt/evidence reuse'};New-Item -ItemType Directory $ev|Out-Null
$image='sha256:31742091e95df2cc62669a6c6a9e0892dc09a34341eaeefc16959dcd4dfa417e'
$run=[Guid]::NewGuid().ToString('N');$id=$null;$rc=1
function SHA($p){(Get-FileHash -LiteralPath $p).Hash.ToLower()}
$hashes=@(foreach($p in @(rg --files labs/tiktok/setup-trace apps/media/src/tiktok apps/media/requirements.lock apps/egress/src/egress.py)){@{path=$p.Replace('\','/');sha256=SHA $p}})|Sort-Object path
$hashes|ConvertTo-Json -Depth 4|Set-Content "$ev/source-hashes.json"
function Native([string]$step,[string[]]$argv,[switch]$AllowFailure){
 $start=[DateTime]::UtcNow;$text=& docker @argv 2>&1|Out-String;$exit=$LASTEXITCODE
 @{step=$step;actualExit=$exit;utcStart=$start.ToString('o');utcEnd=[DateTime]::UtcNow.ToString('o');stdout=$text}|ConvertTo-Json -Compress|Add-Content "$ev/native.jsonl"
 if($exit -and -not $AllowFailure){throw "Docker $step exit$exit"};return @{text=$text.Trim();exit=$exit}
}
try{
 if((Native 'image' @('image','inspect',$image,'--format','{{.Id}}')).text -cne $image){throw 'Image pin'}
 $id=(Native 'create' @('create','--label','com.wed-snap.lab=tiktok-setup-trace','--label',"com.wed-snap.run=$run",
   '--network','none','--read-only','--user','1000:1000','--cap-drop','ALL','--security-opt','no-new-privileges:true',
   '--memory','512m','--memory-swap','512m','--cpus','0.75','--pids-limit','96','--ipc','private',
   '--tmpfs','/tmp:size=32m,uid=1000,gid=1000,noexec,nosuid',
   '--mount',"type=bind,source=$((Resolve-Path labs/tiktok/setup-trace).Path),target=/lab,readonly",
   '--mount',"type=bind,source=$((Resolve-Path apps/egress/src/egress.py).Path),target=/stock/egress.py,readonly",
   '--mount',"type=bind,source=$((Resolve-Path $ev).Path),target=/out",
   '-e','PYTHONDONTWRITEBYTECODE=1','-e','PYTHONWARNINGS=ignore',
   $image,'/usr/bin/timeout','--signal=KILL','95s','python3','/lab/test_trace.py')).text
 $c=@((Native 'inspect' @('inspect',$id)).text|ConvertFrom-Json)[0]
 if($c.Image -cne $image -or $c.Config.User -cne '1000:1000' -or $c.Config.Labels.'com.wed-snap.run' -cne $run -or
  -not $c.HostConfig.ReadonlyRootfs -or $c.HostConfig.Memory -ne 512MB -or $c.HostConfig.MemorySwap -ne 512MB -or
  $c.HostConfig.NanoCpus -ne 750000000 -or $c.HostConfig.PidsLimit -ne 96 -or $c.HostConfig.IpcMode -cne 'private' -or
  $c.HostConfig.NetworkMode -cne 'none' -or $c.HostConfig.CapDrop -notcontains 'ALL' -or $c.HostConfig.SecurityOpt -notcontains 'no-new-privileges:true'){throw 'Runtime guard'}
 $c|ConvertTo-Json -Depth 30|Set-Content "$ev/guard.json"
 $r=Native 'test' @('start','-a',$id) -AllowFailure;$rc=$r.exit;Write-Output $r.text
 $state=@((Native 'state' @('inspect',$id)).text|ConvertFrom-Json)[0].State
 $state|ConvertTo-Json|Set-Content "$ev/state.json"
 if($state.Running -or $state.OOMKilled -or $state.ExitCode -ne $rc){throw 'Native state'}
}finally{
 if($id){
  $c=@((docker inspect $id|ConvertFrom-Json))[0];if($c.Config.Labels.'com.wed-snap.run' -cne $run){throw 'Wrong owner'}
  Native 'remove' @('rm','-f',$id)|Out-Null
 }
 @{actualExit=$rc;ownResourcesLeft=0;image=$image;sourceRequests=0;utc=[DateTime]::UtcNow.ToString('o');vn=[DateTimeOffset]::UtcNow.ToOffset([TimeSpan]::FromHours(7)).ToString('o')}|ConvertTo-Json|Set-Content "$ev/completion.json"
}
if($rc -eq 0){
 foreach($f in $hashes){if((SHA $f.path) -cne $f.sha256){throw 'Executed source changed during offline check'}}
 foreach($f in @(Get-Content "$ev/runtime-core.json" -Raw|ConvertFrom-Json)){if((SHA "apps/media/src/tiktok/$($f.path)") -cne $f.sha256){throw 'Host-image core gate'}}
 @{actualExit=0;image=$image;sourceHashes=$hashes;nativeSHA=SHA "$ev/native.jsonl";resultSHA=SHA "$ev/test-result.json";runtimeSHA=SHA "$ev/runtime-core.json";apiSHA=SHA "$ev/api-runtime.json";sourceRequests=0}|ConvertTo-Json -Depth 5|Set-Content "$ev/receipt.json"
}
exit $rc
