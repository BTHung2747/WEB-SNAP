param([int]$Attempt=1)
$ErrorActionPreference='Stop';Set-Location 'D:\WED SNAP'
$root='docs/evidence/tiktok-connect-poc-20261010';$out="$root/offline-$Attempt"
if(Test-Path $out){throw 'Refuse existing evidence'}
New-Item -ItemType Directory $out|Out-Null
$image='sha256:31742091e95df2cc62669a6c6a9e0892dc09a34341eaeefc16959dcd4dfa417e'
$run=[Guid]::NewGuid().ToString('N');$id=$null;$rc=1
function SHA($p){(Get-FileHash -LiteralPath $p).Hash.ToLower()}
$files=@(rg --files labs/tiktok/connect-poc labs/tiktok/photo-trace labs/tiktok/photo labs/tiktok/setup-trace apps/media/src/tiktok apps/media/requirements.lock apps/egress/src/egress.py)
$hashes=@(foreach($f in $files){[pscustomobject]@{path=$f.Replace('\','/');sha256=SHA $f}})|Sort-Object path
ConvertTo-Json -InputObject $hashes -Depth 4|Set-Content "$out/source-before.json"
function Native($step,[string[]]$argv,[switch]$AllowFailure){
 $start=[DateTime]::UtcNow;$text=& docker @argv 2>&1|Out-String;$exit=$LASTEXITCODE
 @{step=$step;actualExit=$exit;utcStart=$start.ToString('o');utcEnd=[DateTime]::UtcNow.ToString('o');stdout=$text}|ConvertTo-Json -Compress|Add-Content "$out/native.jsonl"
 if($exit -and -not $AllowFailure){throw "Docker $step failed"};return @{text=$text.Trim();exit=$exit}
}
try{
 $main=(Native 'main-before' @('image','inspect','wed-snap-app:local','--format','{{.Id}}')).text
 $main|Set-Content "$out/main-before.txt"
 if((Native 'image' @('image','inspect',$image,'--format','{{.Id}}')).text -cne $image){throw 'Image pin'}
 $id=(Native 'create' @('create','--label','com.wed-snap.lab=tiktok-connect-poc','--label',"com.wed-snap.run=$run",
  '--network','none','--read-only','--user','1000:1000','--cap-drop','ALL','--security-opt','no-new-privileges:true',
  '--memory','512m','--memory-swap','512m','--cpus','0.75','--pids-limit','96','--ipc','private',
  '--tmpfs','/tmp:size=32m,uid=1000,gid=1000,noexec,nosuid',
  '--mount',"type=bind,source=$((Resolve-Path labs/tiktok/connect-poc).Path),target=/poc,readonly",
  '--mount',"type=bind,source=$((Resolve-Path labs/tiktok/photo-trace).Path),target=/integration,readonly",
  '--mount',"type=bind,source=$((Resolve-Path labs/tiktok/photo).Path),target=/app/apps/media/src/tiktok/photo_lab,readonly",
  '--mount',"type=bind,source=$((Resolve-Path labs/tiktok/setup-trace).Path),target=/trace_lab,readonly",
  '--mount',"type=bind,source=$((Resolve-Path apps/egress/src).Path),target=/stock,readonly",
  '--mount',"type=bind,source=$((Resolve-Path $out).Path),target=/out",
  '-e','PYTHONDONTWRITEBYTECODE=1','-e','PYTHONWARNINGS=ignore','-e','PYTHONPATH=/poc/vendor',
  $image,'/usr/bin/timeout','--signal=KILL','180s','python3','/poc/supervise.py')).text
 $g=@((Native 'guard' @('inspect',$id)).text|ConvertFrom-Json)[0]
 if($g.Image -cne $image -or $g.Config.User -cne '1000:1000' -or $g.Config.Labels.'com.wed-snap.run' -cne $run -or $g.HostConfig.NetworkMode -cne 'none' -or $g.HostConfig.Memory -ne 512MB -or $g.HostConfig.MemorySwap -ne 512MB -or $g.HostConfig.NanoCpus -ne 750000000 -or $g.HostConfig.PidsLimit -ne 96 -or $g.HostConfig.IpcMode -cne 'private' -or -not $g.HostConfig.ReadonlyRootfs -or $g.HostConfig.Privileged -or $g.HostConfig.CapAdd -or $g.HostConfig.CapDrop -notcontains 'ALL' -or $g.HostConfig.SecurityOpt -notcontains 'no-new-privileges:true'){throw 'Runtime guard'}
 $g|ConvertTo-Json -Depth 30|Set-Content "$out/guard.json"
 $r=Native 'test' @('start','-a',$id) -AllowFailure;$rc=$r.exit;Write-Output $r.text
 $state=@((Native 'state' @('inspect',$id)).text|ConvertFrom-Json)[0].State
 $state|ConvertTo-Json|Set-Content "$out/state.json"
 if($state.Running -or $state.OOMKilled -or $state.ExitCode -ne $rc){throw 'State disagrees'}
 if(Test-Path "$out/core-runtime.json"){
  if(@(Get-Content "$out/core-runtime.json" -Raw|ConvertFrom-Json).Count -ne 23){throw 'Cached core coverage'}
  foreach($f in @(Get-Content "$out/core-runtime.json" -Raw|ConvertFrom-Json)){if((SHA ("apps/media/src/tiktok/"+$f.path)) -cne $f.sha256){throw 'Cached core runtime mismatch'}}
 }
}finally{
 if($id){
  $owner=@((Native 'cleanup-owner' @('inspect',$id)).text|ConvertFrom-Json)[0]
  if($owner.Config.Labels.'com.wed-snap.run' -cne $run){throw 'Wrong cleanup owner'}
  Native 'remove' @('rm','-f',$id)|Out-Null
 }
 $remaining=(Native 'remaining' @('ps','-aq','--filter',"label=com.wed-snap.run=$run")).text
 if($remaining){throw 'Cleanup incomplete'}
 $mainAfter=(Native 'main-after' @('image','inspect','wed-snap-app:local','--format','{{.Id}}')).text
 if($mainAfter -cne $main){throw 'Main changed'}
 foreach($f in $hashes){if((SHA $f.path) -cne $f.sha256){throw 'Source changed'}}
 ConvertTo-Json -InputObject $hashes -Depth 4|Set-Content "$out/source-after.json"
 @{actualExit=$rc;image=$image;sourceCalls=0;ownResourcesLeft=0;mainImage=$mainAfter;utc=[DateTime]::UtcNow.ToString('o');vn=[DateTimeOffset]::UtcNow.ToOffset([TimeSpan]::FromHours(7)).ToString('o')}|ConvertTo-Json|Set-Content "$out/completion.json"
}
exit $rc
