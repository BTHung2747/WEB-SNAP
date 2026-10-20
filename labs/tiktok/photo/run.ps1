param([ValidateSet('offline','live')][string]$Stage='offline',[int]$Attempt=1)
$ErrorActionPreference='Stop';Set-Location 'D:\WED SNAP'
$root='docs/evidence/tiktok-photo-lab-20261009'
$dir=if($Stage -eq 'offline'){"$root/offline-$Attempt"}else{"$root/sample-1"}
if(Test-Path $dir){throw 'Evidence/attempt already exists'}
function SHA($p){(Get-FileHash -LiteralPath $p).Hash.ToLower()}
function Snapshot{
 $rows=@(foreach($p in @(rg --files labs/tiktok/photo apps/media/src/tiktok apps/media/requirements.lock apps/egress/src/egress.py)){
  @{path=$p.Replace('\','/');sha256=SHA $p}
 });return @($rows|Sort-Object path)
}
$hashes=Snapshot
$image='sha256:31742091e95df2cc62669a6c6a9e0892dc09a34341eaeefc16959dcd4dfa417e'
if($Stage -eq 'live'){
 $receipt=Get-Content "$root/offline-$Attempt/receipt.json" -Raw|ConvertFrom-Json
 if($receipt.actualExit -ne 0 -or $receipt.image -cne $image -or $receipt.snapshotJSON -cne ($hashes|ConvertTo-Json -Depth 4 -Compress) -or
    (SHA "$root/offline-$Attempt/offline-result.json") -cne $receipt.resultSHA -or
    (SHA "$root/offline-$Attempt/native.jsonl") -cne $receipt.nativeSHA -or
    (SHA "$root/offline-$Attempt/runtime-inventory.json") -cne $receipt.runtimeSHA){throw 'Exact offline hash/exit gate'}
 $result=Get-Content "$root/offline-$Attempt/offline-result.json" -Raw|ConvertFrom-Json
 if($result.status -cne 'PASS' -or $result.sourceCalls -ne 0){throw 'Offline gate'}
}
New-Item -ItemType Directory $dir|Out-Null
$hashes|ConvertTo-Json -Depth 4|Set-Content "$dir/source-hashes.json"
$run=[Guid]::NewGuid().ToString('N');$ids=@();$nets=@();$rc=1
function Native([string]$step,[string[]]$argv){
 $start=[DateTime]::UtcNow;$text=& docker @argv 2>&1|Out-String;$exit=$LASTEXITCODE
 @{step=$step;actualExit=$exit;utcStart=$start.ToString('o');utcEnd=[DateTime]::UtcNow.ToString('o');stdout=$text}|ConvertTo-Json -Compress|Add-Content "$dir/native.jsonl"
 if($exit -and $step -ne 'test'){throw "Docker $step exit$exit"}
 return @{text=$text.Trim();exit=$exit}
}
function Guard($id,$expectedImage,$ram,$user,$networkCount){
 $c=@((Native 'inspect' @('inspect',$id)).text|ConvertFrom-Json)[0]
 if($c.Image -cne $expectedImage -or $c.Config.Labels.'com.wed-snap.run' -cne $run -or $c.Config.User -cne $user -or
  -not $c.HostConfig.ReadonlyRootfs -or $c.HostConfig.Memory -ne $ram -or $c.HostConfig.MemorySwap -ne $ram -or
  $c.HostConfig.CapDrop -notcontains 'ALL' -or $c.HostConfig.SecurityOpt -notcontains 'no-new-privileges:true' -or
  @($c.NetworkSettings.Networks.PSObject.Properties).Count -ne $networkCount){throw 'Runtime guard'}
 if($ram -eq 512MB -and ($c.HostConfig.NanoCpus -ne 750000000 -or $c.HostConfig.PidsLimit -ne 96 -or $c.HostConfig.IpcMode -cne 'private')){throw 'Photo resource guard'}
 $c|ConvertTo-Json -Depth 30|Set-Content "$dir/guard-$($c.Name.TrimStart('/')).json"
}
try{
 if((Native 'image' @('image','inspect',$image,'--format','{{.Id}}')).text -cne $image){throw 'Image pin'}
 if($Stage -eq 'offline'){
  $id=(Native 'create' @('create','--label','com.wed-snap.lab=tiktok-photo','--label',"com.wed-snap.run=$run",
   '--network','none','--read-only','--user','1000:1000','--cap-drop','ALL','--security-opt','no-new-privileges:true',
   '--memory','512m','--memory-swap','512m','--cpus','0.75','--pids-limit','96','--ipc','private',
   '--tmpfs','/tmp:size=32m,uid=1000,gid=1000,noexec,nosuid',
   '--mount',"type=bind,source=$((Resolve-Path labs/tiktok/photo).Path),target=/app/apps/media/src/tiktok/photo_lab,readonly",
   '--mount',"type=bind,source=$((Resolve-Path $dir).Path),target=/out",
   '-e','PYTHONDONTWRITEBYTECODE=1','-e','PYTHONWARNINGS=ignore',
   $image,'/usr/bin/timeout','--signal=KILL','150s','python3','/app/apps/media/src/tiktok/photo_lab/test_photo.py')).text
  $ids+= $id;Guard $id $image 512MB '1000:1000' 1
  $r=Native 'test' @('start','-a',$id);$rc=$r.exit;Write-Output $r.text
 }else{
  $env:PHOTO_RUN=$run;$env:PHOTO_SOURCE=(Resolve-Path labs/tiktok/photo).Path;$env:PHOTO_OUTPUT=(Resolve-Path $dir).Path
  $compose=@('compose','-p','wed-snap-tiktok-photo-lab','-f','labs/tiktok/photo/compose.yaml')
  Native 'create' ($compose+@('create'))|Out-Null
  $ids=@((Native 'ids' ($compose+@('ps','-aq'))).text -split '\r?\n')
  $nets=@((Native 'networks' @('network','ls','--filter',"label=com.wed-snap.run=$run",'-q')).text -split '\r?\n')
  if($ids.Count -ne 2 -or $nets.Count -ne 2){throw 'Own topology'}
  foreach($n in $nets){
   $net=@((Native 'network-inspect' @('network','inspect',$n)).text|ConvertFrom-Json)[0]
   if($net.Labels.'com.wed-snap.run' -cne $run -or ($net.Name.EndsWith('_private') -and -not $net.Internal)){throw 'Private network/owner'}
  }
  foreach($id in $ids){
   $c=@((docker inspect $id|ConvertFrom-Json))[0]
   if($c.Config.Labels.'com.docker.compose.service' -eq 'photo'){$photo=$id;Guard $id $image 512MB '1000:1000' 1}
   else{$egress=$id;Guard $id 'sha256:8bc0a567955111ea3cfbab2dd3b14f40a602f2d10ac987e78eb465f9d48d7f10' 96MB '65534:65534' 2}
  }
  Native 'start-egress' @('start',$egress)|Out-Null
  Native 'start-photo' @('start',$photo)|Out-Null
  $exit=(Native 'wait' @('wait',$photo)).text;$rc=[int]$exit
  $r=Native 'logs' @('logs',$photo);Write-Output $r.text
 }
 foreach($id in $ids){
  $c=@((Native 'state' @('inspect',$id)).text|ConvertFrom-Json)[0]
  $c.State|ConvertTo-Json|Set-Content "$dir/state-$($c.Name.TrimStart('/')).json"
 }
}finally{
 foreach($id in $ids){
  $c=@((docker inspect $id|ConvertFrom-Json))[0]
  if($c.Config.Labels.'com.wed-snap.run' -cne $run){throw 'Wrong container owner'}
  Native 'remove' @('rm','-f',$id)|Out-Null
 }
 foreach($n in $nets){
  $net=@((docker network inspect $n|ConvertFrom-Json))[0];if($net.Labels.'com.wed-snap.run' -cne $run){throw 'Wrong network owner'}
  Native 'network-remove' @('network','rm',$n)|Out-Null
 }
 @{actualExit=$rc;image=$image;ownResourcesLeft=0;sourceAnalyzeAttempts=$(if($Stage -eq 'live'){1}else{0});utc=[DateTime]::UtcNow.ToString('o');vn=[DateTimeOffset]::UtcNow.ToOffset([TimeSpan]::FromHours(7)).ToString('o')}|ConvertTo-Json|Set-Content "$dir/completion.json"
}
if($Stage -eq 'offline' -and $rc -eq 0){
 foreach($f in @(Get-Content "$dir/runtime-inventory.json" -Raw|ConvertFrom-Json)){if((SHA "apps/media/src/tiktok/$($f.path)") -cne $f.sha256){throw 'Host-image tested core gate'}}
 @{actualExit=0;image=$image;snapshotJSON=($hashes|ConvertTo-Json -Depth 4 -Compress);resultSHA=SHA "$dir/offline-result.json";nativeSHA=SHA "$dir/native.jsonl";runtimeSHA=SHA "$dir/runtime-inventory.json";utc=[DateTime]::UtcNow.ToString('o')}|ConvertTo-Json -Depth 5|Set-Content "$dir/receipt.json"
}
exit $rc
