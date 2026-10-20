param([int]$Attempt=1)
$ErrorActionPreference='Stop';Set-Location 'D:\WED SNAP'
$ev='docs/evidence/tiktok-photo-source-preflight-20261011';$dir="$ev/preflight-$Attempt"
if(Test-Path $dir){throw 'Refuse evidence reuse'}
function SHA($p){(Get-FileHash -LiteralPath $p).Hash.ToLowerInvariant()}
function Save($p,$v){ConvertTo-Json -InputObject $v -Depth 30|Set-Content -LiteralPath $p}
$reviewed=@(Get-Content "$ev/reviewed-source.json" -Raw|ConvertFrom-Json)
if($reviewed.Count -ne 283 -or (SHA "$ev/reviewed-source.json") -cne '621509c15c3b9a6c842f12212c865d3c029c11afd3e2b392dfca55c761c693dc'){throw 'REVIEWED_PIN'}
foreach($f in $reviewed){if((SHA $f.path) -cne $f.sha256){throw 'REVIEWED_SOURCE_DRIFT'}}
New-Item -ItemType Directory "$dir/control"|Out-Null
Save "$dir/control/control.json" @{stage='source';phaseDeadline=0}
Save "$dir/source-before.json" $reviewed
Save "$dir/preflight-code.json" @{python=SHA 'labs/tiktok/photo-source-preflight/preflight.py';runner=SHA $PSCommandPath;reviewedSourceSHA=SHA "$ev/reviewed-source.json";sourceCodeFiles=283;sourcePathInvoked=$false;claimCreated=$false}
$image='sha256:31742091e95df2cc62669a6c6a9e0892dc09a34341eaeefc16959dcd4dfa417e';$run=[Guid]::NewGuid().ToString('N');$id=$null;$rc=1
function Native($step,[string[]]$argv,[switch]$AllowFailure){
 $begin=[DateTime]::UtcNow;$output=& docker @argv 2>&1|Out-String;$code=$LASTEXITCODE
 @{step=$step;actualExit=$code;utcStart=$begin.ToString('o');utcEnd=[DateTime]::UtcNow.ToString('o');stdout=$output}|ConvertTo-Json -Compress|Add-Content "$dir/native.jsonl"
 if($code -and -not $AllowFailure){throw "DOCKER_$step"};return @{text=$output.Trim();exit=$code}
}
try{
 if((Native 'image' @('image','inspect',$image,'--format','{{.Id}}')).text -cne $image){throw 'IMAGE_PIN'}
 $main=(Native 'main-image' @('image','inspect','wed-snap-app:local','--format','{{.Id}}')).text
 $mounts=@();foreach($item in @(@('labs/tiktok/wholephoto-registry-closure','/integration'),@('labs/tiktok/wholephoto-registry-closure','/poc'),@('labs/tiktok/connect-poc/vendor','/vendor'),@('labs/tiktok/photo','/app/apps/media/src/tiktok/photo_lab'),@('labs/tiktok/setup-trace','/trace_lab'),@('apps/egress/src','/stock'),@('labs/tiktok/photo-source-preflight','/preflight'))){$mounts+=@('--mount',"type=bind,source=$((Resolve-Path $item[0]).Path),target=$($item[1]),readonly")}
 $id=(Native 'create' (@('create','--label','com.wed-snap.lab=tiktok-photo-source-preflight','--label',"com.wed-snap.run=$run",'--network','none','--read-only','--user','65534:65534','--cap-drop','ALL','--security-opt','no-new-privileges:true','--memory','512m','--memory-swap','512m','--cpus','0.75','--pids-limit','96','--ipc','private','--tmpfs','/tmp:size=32m,uid=65534,gid=65534,noexec,nosuid','--mount',"type=bind,source=$((Resolve-Path $dir).Path),target=/out",'--mount',"type=bind,source=$((Resolve-Path "$dir/control").Path),target=/control",'-e','WHOLEPHOTO_STAGE=source','-e','PYTHONPATH=/integration:/vendor:/stock:/app/apps/media/src','-e','PYTHONDONTWRITEBYTECODE=1','-e','PYTHONWARNINGS=ignore')+$mounts+@($image,'/usr/bin/timeout','--signal=KILL','30s','python3','/preflight/preflight.py'))).text
 $g=@((Native 'guard' @('inspect',$id)).text|ConvertFrom-Json)[0];$h=$g.HostConfig
 if($g.Config.User -cne '65534:65534' -or $h.NetworkMode -cne 'none' -or $h.Memory -ne 512MB -or $h.MemorySwap -ne 512MB -or $h.NanoCpus -ne 750000000 -or $h.PidsLimit -ne 96 -or $h.IpcMode -cne 'private' -or -not $h.ReadonlyRootfs -or $h.Privileged -or $h.CapAdd -or 'ALL' -notin $h.CapDrop -or 'no-new-privileges:true' -notin $h.SecurityOpt -or $g.Config.Labels.'com.wed-snap.run' -cne $run){throw 'PREFLIGHT_GUARDS'}
 Save "$dir/guard.json" $g
 $out=Native 'test' @('start','-a',$id) -AllowFailure;$rc=$out.exit;Write-Output $out.text
 $state=@((Native 'state' @('inspect',$id)).text|ConvertFrom-Json)[0].State;Save "$dir/state.json" $state
 if($state.Running -or $state.OOMKilled -or $state.ExitCode -ne $rc){throw 'PREFLIGHT_STATE'}
}finally{
 if($id){$g=@((Native 'owner' @('inspect',$id)).text|ConvertFrom-Json)[0];if($g.Config.Labels.'com.wed-snap.run' -cne $run){throw 'CLEANUP_OWNER'};Native 'remove' @('rm','-f',$id)|Out-Null}
 Save "$dir/completion.json" @{actualExit=$rc;sourceCalls=0;claimCreated=$false;claimConsumed=$false;ownResourcesLeft=0;mainImage=$main;image=$image;utc=[DateTime]::UtcNow.ToString('o');vn=[DateTimeOffset]::UtcNow.ToOffset([TimeSpan]::FromHours(7)).ToString('o')}
}
foreach($f in $reviewed){if((SHA $f.path) -cne $f.sha256){throw 'REVIEWED_SOURCE_CHANGED'}}
Save "$dir/source-after.json" $reviewed
exit $rc
