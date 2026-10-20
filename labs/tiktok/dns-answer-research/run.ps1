$ErrorActionPreference='Stop';Set-Location 'D:\WED SNAP'
$ev='docs/evidence/tiktok-dns-answer-research-20261012';$dir="$ev/offline-1"
if(Test-Path $dir){throw 'REFUSE_EVIDENCE_REUSE'}
$pre=Get-Content "$ev/preparation.json" -Raw|ConvertFrom-Json
if($pre.actualExit -ne 0 -or $pre.sourceCalls -ne 0){throw 'PREPARATION'}
New-Item -ItemType Directory $dir|Out-Null
$image='sha256:31742091e95df2cc62669a6c6a9e0892dc09a34341eaeefc16959dcd4dfa417e'
$run=[Guid]::NewGuid().ToString('N');$id=$null;$rc=20
function Save($p,$row){if(Test-Path $p){throw 'REFUSE_OVERWRITE'};ConvertTo-Json -InputObject $row -Depth 30|Set-Content -LiteralPath $p}
function Native($step,[string[]]$argv,[switch]$AllowFailure){
 $start=[DateTime]::UtcNow;$output=& docker @argv 2>&1|Out-String;$code=$LASTEXITCODE
 @{step=$step;actualExit=$code;stdout=$output;utcStart=$start.ToString('o');utcEnd=[DateTime]::UtcNow.ToString('o')}|ConvertTo-Json -Compress|Add-Content -LiteralPath "$dir/native.jsonl"
 if($code -and -not $AllowFailure){throw "DOCKER_$step"};return @{text=$output.Trim();exit=$code}
}
try{
 $cached=Native 'cached-image' @('image','inspect',$image,'--format','{{.Id}}');if($cached.text -cne $image){throw 'IMAGE_DRIFT'}
 $mounts=@()
 foreach($row in @(@('labs/tiktok/photo-dns-source-trial','/integration'),@('labs/tiktok/photo-dns-source-trial','/poc'),@('labs/tiktok/dns-answer-research','/research'),@('labs/tiktok/setup-trace','/trace_lab'),@('labs/tiktok/connect-poc/vendor','/vendor'))){$mounts+=@('--mount',"type=bind,source=$((Resolve-Path -LiteralPath $row[0]).Path),target=$($row[1]),readonly")}
 $id=(Native 'create' (@('create','--pull','never','--label',"com.wed-snap.dns-research=$run",'--network','none','--read-only','--user','65534:65534','--memory','96m','--memory-swap','96m','--cpus','0.25','--pids-limit','64','--ipc','private','--cap-drop','ALL','--security-opt','no-new-privileges:true','--tmpfs','/tmp:size=16m,uid=65534,gid=65534,noexec,nosuid','--mount',"type=bind,source=$((Resolve-Path $dir).Path),target=/out",'-e','PYTHONDONTWRITEBYTECODE=1','-e','PYTHONPATH=/research:/integration:/vendor')+$mounts+@($image,'/usr/bin/timeout','--signal=KILL','30s','python3','/research/probe.py'))).text
 $g=@((Native 'guard' @('inspect',$id)).text|ConvertFrom-Json)[0];$h=$g.HostConfig
 if($g.Image -cne $image -or $g.Config.User -cne '65534:65534' -or $h.NetworkMode -cne 'none' -or $h.Memory -ne 96MB -or $h.MemorySwap -ne 96MB -or $h.ReadonlyRootfs -ne $true -or $h.Privileged -or $h.CapAdd -or 'ALL' -notin $h.CapDrop -or 'no-new-privileges:true' -notin $h.SecurityOpt -or $h.IpcMode -cne 'private' -or $h.PidsLimit -ne 64 -or $h.NanoCpus -ne 250000000){throw 'RESEARCH_GUARD'}
 Save "$dir/guard.json" $g
 $test=Native 'test' @('start','-a',$id) -AllowFailure;$rc=$test.exit;Write-Output $test.text
 $state=@((Native 'state' @('inspect',$id)).text|ConvertFrom-Json)[0].State;Save "$dir/state.json" $state
 if($state.Running -or $state.OOMKilled -or $state.ExitCode -ne $rc){throw 'RESEARCH_STATE'}
}finally{
 if($id){$g=@((Native 'owner' @('inspect',$id)).text|ConvertFrom-Json)[0];if($g.Config.Labels.'com.wed-snap.dns-research' -cne $run){throw 'CLEANUP_OWNER'};Native 'remove' @('rm','-f',$id)|Out-Null}
 Save "$dir/completion.json" @{actualExit=$rc;sourceCalls=0;internetDNS=0;claimActions=0;containersCreated=[int][bool]$id;networksCreated=0;ownResourcesLeft=0;utc=[DateTime]::UtcNow.ToString('o');vn=[DateTimeOffset]::UtcNow.ToOffset([TimeSpan]::FromHours(7)).ToString('o')}
}
exit $rc
